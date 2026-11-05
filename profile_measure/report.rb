# frozen_string_literal: true

require 'cgi'
require 'base64'
require 'json'

module CodexProfileMeasure
  module Report
    extend self

    DICTIONARY = 'CodexProfileMeasure'.freeze
    COLORIZED_KEY = 'report_colorized'.freeze
    PREVIOUS_MATERIAL_KEY = 'report_previous_material'.freeze
    CATEGORY_KEY = 'report_category'.freeze
    PDF_PAGE_WIDTH = 1684
    PDF_PAGE_HEIGHT = 1191
    STOCK_BAR_LENGTH = 6.m

    PALETTE = [
      [48, 112, 190], [220, 128, 45], [42, 146, 111], [172, 91, 162],
      [194, 75, 74], [57, 143, 176], [150, 125, 55], [91, 112, 156],
      [124, 151, 66], [202, 105, 139]
    ].freeze

    def supported?(entity)
      entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
    end

    def visible?(entity)
      entity.visible? && entity.layer.visible?
    rescue StandardError
      false
    end

    def name_for(entity)
      instance_name = entity.name.to_s.strip
      definition_name = entity.definition.name.to_s.strip
      name = instance_name.empty? ? definition_name : instance_name
      name.empty? ? "#{entity.typename} ##{entity.persistent_id}" : name
    end

    def dimensions(bounds, transform)
      [
        bounds.width * transform.xaxis.length,
        bounds.height * transform.yaxis.length,
        bounds.depth * transform.zaxis.length
      ].map(&:to_f).sort.reverse
    end

    def formatted(value)
      Sketchup.format_length(value)
    end

    def stock_bar_usage(length)
      exact = length.to_f / STOCK_BAR_LENGTH
      consumed = format('%.1f', exact).sub(/\.0$/, '')
      required = [(exact - 1e-9).ceil, 0].max
      "#{consumed} / #{required}"
    end

    def visible_children(entity)
      entity.definition.entities.select { |child| supported?(child) && visible?(child) }
    end

    def scan_entities(entities, parent_transform, parent_names, rows, definition_stack)
      entities.each do |entity|
        next unless supported?(entity) && visible?(entity)

        transform = parent_transform * entity.transformation
        children = visible_children(entity)
        length, width, height = dimensions(entity.definition.bounds, transform)
        names = parent_names + [name_for(entity)]
        width, height = [width, height].sort.reverse
        row = {
          entity: entity,
          name: name_for(entity),
          path: names.join(' / '),
          length: length,
          width: width,
          height: height,
          assembly: !children.empty?,
          category: category_key(width, height),
          category_label: "#{formatted(width)} × #{formatted(height)}"
        }
        rows << row

        definition_id = entity.definition.object_id
        next if children.empty? || definition_stack.include?(definition_id)

        scan_entities(
          entity.definition.entities,
          transform,
          names,
          rows,
          definition_stack + [definition_id]
        )
      end
    end

    def scan_model(model = Sketchup.active_model)
      rows = []
      scan_entities(model.entities, Geom::Transformation.new, [], rows, [])
      rows
    end

    def category_key(width, height)
      [width.to_f.round(3), height.to_f.round(3)].sort.reverse.join('x')
    end

    def profiles(rows)
      rows.reject { |row| row[:assembly] }
    end

    def category_colors(rows)
      keys = profiles(rows).map { |row| row[:category] }.uniq.sort
      keys.each_with_index.to_h { |key, index| [key, PALETTE[index % PALETTE.length]] }
    end

    def color_hex(color)
      '#%02x%02x%02x' % color
    end

    def esc(value)
      CGI.escapeHTML(value.to_s)
    end

    def grouped_profiles(rows)
      profiles(rows).group_by { |row| row[:category] }.sort_by { |key, _| key }
    end

    def report_html(model, rows)
      profile_rows = profiles(rows)
      total_length = profile_rows.sum { |row| row[:length] }
      colors = category_colors(rows)
      groups = grouped_profiles(rows)
      title = model.title.to_s.strip
      title = 'گزارش ابعاد پروفیل‌ها' if title.empty?
      generated_at = Time.now.strftime('%Y-%m-%d %H:%M')

      category_rows = groups.map do |key, group_rows|
        sample = group_rows.first
        sum = group_rows.sum { |row| row[:length] }
        color = color_hex(colors.fetch(key))
        <<~HTML
          <tr>
            <td><span class="swatch" style="--swatch:#{color}"></span>#{esc(sample[:category_label])}</td>
            <td>#{group_rows.length}</td>
            <td>#{esc(formatted(sum))}</td>
            <td>#{esc(stock_bar_usage(sum))}</td>
          </tr>
        HTML
      end.join

      object_rows = rows.map do |row|
        color = row[:assembly] ? '#8a94a6' : color_hex(colors.fetch(row[:category]))
        kind = row[:assembly] ? 'مجموعه' : 'پروفیل'
        search_text = [row[:path], row[:category_label], kind].join(' ').downcase
        <<~HTML
          <tr class="object-row" data-search="#{esc(search_text)}">
            <td><span class="swatch" style="--swatch:#{color}"></span>#{esc(row[:path])}</td>
            <td>#{esc(kind)}</td>
            <td>#{esc(formatted(row[:length]))}</td>
            <td>#{esc(formatted(row[:width]))}</td>
            <td>#{esc(formatted(row[:height]))}</td>
            <td>#{esc(row[:assembly] ? '—' : row[:category_label])}</td>
          </tr>
        HTML
      end.join

      pdf_data = {
        title: title,
        generated_at: generated_at,
        object_count: rows.length,
        profile_count: profile_rows.length,
        total_length: formatted(total_length),
        categories: groups.map do |key, group_rows|
          sample = group_rows.first
          {
            label: sample[:category_label],
            count: group_rows.length,
            total_length: formatted(group_rows.sum { |row| row[:length] }),
            stock_bars: stock_bar_usage(group_rows.sum { |row| row[:length] }),
            color: color_hex(colors.fetch(key))
          }
        end,
        rows: rows.map do |row|
          {
            path: row[:path],
            kind: row[:assembly] ? 'مجموعه' : 'پروفیل',
            length: formatted(row[:length]),
            width: formatted(row[:width]),
            height: formatted(row[:height]),
            category: row[:assembly] ? '—' : row[:category_label],
            color: row[:assembly] ? '#8a94a6' : color_hex(colors.fetch(row[:category]))
          }
        end
      }
      pdf_json = JSON.generate(pdf_data).gsub('<', '\\u003c').gsub('>', '\\u003e').gsub('&', '\\u0026')

      <<~HTML
        <!doctype html>
        <html lang="fa" dir="rtl">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{esc(title)}</title>
          <style>
            :root { color-scheme: light; --ink:#172b4d; --muted:#64748b; --line:#dce4ee; --paper:#fff; --canvas:#f3f6fa; --blue:#1769aa; }
            * { box-sizing:border-box; }
            body { margin:0; background:var(--canvas); color:var(--ink); font:14px/1.6 "Segoe UI",Tahoma,Arial,sans-serif; }
            .wrap { max-width:1100px; margin:0 auto; padding:22px; }
            header { display:flex; align-items:flex-start; justify-content:space-between; gap:16px; margin-bottom:18px; }
            h1 { margin:0; font-size:21px; font-weight:700; }
            .sub { color:var(--muted); margin-top:3px; font-size:12px; }
            .actions { display:flex; gap:8px; flex-wrap:wrap; }
            button { border:1px solid #c8d3e0; border-radius:8px; background:#fff; color:var(--ink); padding:8px 12px; min-height:38px; font:inherit; cursor:pointer; }
            button.primary { background:var(--blue); color:#fff; border-color:var(--blue); }
            button:hover { filter:brightness(.97); }
            .cards { display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-bottom:16px; }
            .card { background:var(--paper); border:1px solid var(--line); border-radius:10px; padding:12px 14px; }
            .card span { display:block; color:var(--muted); font-size:12px; }
            .card strong { display:block; font-size:19px; margin-top:2px; }
            section { background:var(--paper); border:1px solid var(--line); border-radius:10px; margin:12px 0; overflow:hidden; }
            h2 { margin:0; padding:11px 14px; font-size:15px; border-bottom:1px solid var(--line); }
            .table-wrap { overflow:auto; max-height:390px; }
            table { width:100%; border-collapse:collapse; min-width:720px; }
            th,td { padding:8px 10px; text-align:right; border-bottom:1px solid #edf1f5; white-space:nowrap; }
            th { position:sticky; top:0; background:#f8fafc; color:#4b5d74; font-weight:600; z-index:1; }
            tbody tr:hover { background:#f7faff; }
            .swatch { display:inline-block; width:10px; height:10px; background:var(--swatch); border-radius:3px; margin-left:7px; vertical-align:middle; }
            .toolbar { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:10px 14px; border-bottom:1px solid var(--line); }
            input { width:min(360px,100%); min-height:36px; border:1px solid #c8d3e0; border-radius:8px; padding:7px 10px; font:inherit; }
            .note { padding:10px 14px; color:var(--muted); font-size:12px; }
            #status { color:#16724d; font-size:12px; min-height:20px; }
            @media (max-width:700px) { .wrap{padding:12px}.cards{grid-template-columns:1fr}.actions{width:100%}header{flex-direction:column} }
            @media print {
              body { background:#fff; font-size:10pt; -webkit-print-color-adjust:exact; print-color-adjust:exact; }
              .wrap { max-width:none; padding:0; }
              header { margin-bottom:10px; }
              .actions,.toolbar { display:none !important; }
              .cards { gap:6px; margin-bottom:8px; }
              .card,section { border-color:#aeb8c5; break-inside:avoid; overflow:visible; }
              .table-wrap { max-height:none; overflow:visible; }
              table { min-width:0; font-size:9pt; }
              th { position:static; }
              tr { break-inside:avoid; }
              .note { padding:7px 0; }
            }
          </style>
        </head>
        <body>
          <main class="wrap">
            <header>
              <div><h1>#{esc(title)} — فهرست پروفیل‌ها</h1><div class="sub">#{esc(generated_at)}</div></div>
              <div class="actions">
                <button onclick="window.print()">چاپ</button>
                <button class="primary" onclick="sketchup.savePdf()">ذخیره PDF</button>
                <button onclick="sketchup.colorize()">رنگ‌بندی گروه‌ها در مدل</button>
                <button onclick="sketchup.restoreColors()">بازگردانی رنگ‌ها</button>
                <button onclick="sketchup.refresh()">به‌روزرسانی</button>
              </div>
            </header>
            <div class="cards">
              <div class="card"><span>تعداد کل اشیای فهرست</span><strong>#{rows.length}</strong></div>
              <div class="card"><span>تعداد پروفیل‌های نهایی</span><strong>#{profile_rows.length}</strong></div>
              <div class="card"><span>جمع طول پروفیل‌ها</span><strong>#{esc(formatted(total_length))}</strong></div>
              <div class="card"><span>تعداد دسته‌های مقطع</span><strong>#{groups.length}</strong></div>
            </div>
            <section>
              <h2>جمع بر اساس مقطع عرض × ارتفاع</h2>
              <div class="table-wrap"><table><thead><tr><th>مقطع</th><th>تعداد پروفیل</th><th>جمع طول</th><th>شاخهٔ ۶ متری (مصرف / خرید)</th></tr></thead>
                <tbody>#{category_rows.empty? ? '<tr><td colspan="4">پروفیلی پیدا نشد.</td></tr>' : category_rows}</tbody>
              </table></div>
            </section>
            <section>
              <h2>فهرست اشیای مدل</h2>
              <div class="toolbar"><input id="filter" type="search" placeholder="جست‌وجو در نام یا مقطع…" aria-label="جست‌وجو"><span id="status"></span></div>
              <div class="table-wrap"><table><thead><tr><th>نام / مسیر</th><th>نوع</th><th>طول</th><th>عرض</th><th>ارتفاع</th><th>دستهٔ مقطع</th></tr></thead>
                <tbody id="objects">#{object_rows.empty? ? '<tr><td colspan="6">در مدل شیء گروهی یا کامپوننتی پیدا نشد.</td></tr>' : object_rows}</tbody>
              </table></div>
              <div class="note">در ستون شاخهٔ ۶ متری، عدد اول معادل مصرف شاخه بر پایهٔ جمع طول است و عدد دوم تعداد شاخهٔ کامل موردنیاز با گردکردن رو به بالا. مجموع فقط از پروفیل‌های نهایی محاسبه می‌شود؛ مجموعه‌های والد برای جلوگیری از دوباره‌شماری در فهرست هستند ولی وارد جمع نمی‌شوند.</div>
            </section>
          </main>
          <script>
            const reportPdfData = #{pdf_json};
            document.getElementById('filter').addEventListener('input', function() {
              const query = this.value.trim().toLowerCase();
              document.querySelectorAll('.object-row').forEach(function(row) {
                row.hidden = query && !row.dataset.search.includes(query);
              });
            });
            window.profileMeasureStatus = function(text) { document.getElementById('status').textContent = text; };
            window.createPdfPages = function() {
              const W = #{PDF_PAGE_WIDTH}, H = #{PDF_PAGE_HEIGHT}, margin = 58, bottom = H - 72, rowH = 40;
              const pages = [];
              let canvas, ctx, y;
              function drawText(value, x, baseline, size, weight, color, maxWidth) {
                ctx.font = weight + ' ' + size + 'px Tahoma, Arial, sans-serif';
                ctx.fillStyle = color || '#172b4d'; ctx.direction = 'rtl'; ctx.textAlign = 'right';
                ctx.fillText(String(value == null ? '' : value), x, baseline, maxWidth || W);
              }
              function newPage(first) {
                canvas = document.createElement('canvas'); canvas.width = W; canvas.height = H;
                pages.push(canvas); ctx = canvas.getContext('2d');
                ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H);
                drawText(reportPdfData.title + ' — گزارش ابعاد پروفیل‌ها', W - margin, 66, 32, '700');
                drawText('تاریخ: ' + reportPdfData.generated_at, W - margin, 102, 18, '400', '#64748b');
                y = 140;
                if (first) {
                  const cards = [['تعداد کل اشیا', reportPdfData.object_count], ['پروفیل‌های نهایی', reportPdfData.profile_count], ['جمع طول کل', reportPdfData.total_length], ['دسته‌های مقطع', reportPdfData.categories.length]];
                  const gap = 14, cardW = (W - margin * 2 - gap * 3) / 4, cardH = 86;
                  cards.forEach(function(card, i) {
                    const x = margin + i * (cardW + gap);
                    ctx.fillStyle = '#f3f6fa'; ctx.strokeStyle = '#dce4ee'; ctx.lineWidth = 2;
                    ctx.beginPath(); ctx.roundRect(x, y, cardW, cardH, 10); ctx.fill(); ctx.stroke();
                    drawText(card[0], x + cardW - 14, y + 31, 17, '400', '#64748b', cardW - 28);
                    drawText(card[1], x + cardW - 14, y + 66, 24, '700', '#172b4d', cardW - 28);
                  });
                  y += cardH + 24;
                }
              }
              function heading(label) {
                ctx.fillStyle = '#eaf0f7'; ctx.fillRect(margin, y, W - margin * 2, 36);
                drawText(label, W - margin - 12, y + 25, 18, '700'); y += 46;
              }
              function categoryRow(item, index) {
                if (index % 2) { ctx.fillStyle = '#f8fafc'; ctx.fillRect(margin, y, W - margin * 2, rowH); }
                ctx.fillStyle = item.color; ctx.fillRect(W - margin - 23, y + 13, 14, 14);
                drawText(item.label, W - margin - 34, y + 27, 17, '400', '#172b4d', 430);
                drawText(item.count, W - margin - 590, y + 27, 17, '400', '#172b4d', 120);
                drawText(item.total_length, W - margin - 900, y + 27, 17, '600', '#172b4d', 220);
                drawText(item.stock_bars, margin + 290, y + 27, 17, '600', '#172b4d', 240);
                ctx.strokeStyle = '#e6ebf1'; ctx.beginPath(); ctx.moveTo(margin, y + rowH); ctx.lineTo(W - margin, y + rowH); ctx.stroke(); y += rowH;
              }
              function categoryHeader() {
                ctx.fillStyle = '#f0f4f8'; ctx.fillRect(margin, y, W - margin * 2, 42);
                drawText('مقطع', W - margin - 10, y + 28, 16, '700', '#4b5d74', 430);
                drawText('تعداد پروفیل', W - margin - 590, y + 28, 16, '700', '#4b5d74', 150);
                drawText('جمع طول', W - margin - 900, y + 28, 16, '700', '#4b5d74', 200);
                drawText('شاخهٔ ۶ متری (مصرف / خرید)', margin + 290, y + 28, 16, '700', '#4b5d74', 270);
                y += 42;
              }
              function tableHeader() {
                ctx.fillStyle = '#f0f4f8'; ctx.fillRect(margin, y, W - margin * 2, 42);
                const r = W - margin;
                drawText('نام / مسیر', r - 10, y + 28, 16, '700', '#4b5d74', 520);
                drawText('نوع', r - 560, y + 28, 16, '700', '#4b5d74', 120);
                drawText('طول', r - 700, y + 28, 16, '700', '#4b5d74', 135);
                drawText('عرض', r - 850, y + 28, 16, '700', '#4b5d74', 135);
                drawText('ارتفاع', r - 1000, y + 28, 16, '700', '#4b5d74', 135);
                drawText('مقطع', r - 1150, y + 28, 16, '700', '#4b5d74', 300); y += 42;
              }
              function objectRow(row, index) {
                if (index % 2) { ctx.fillStyle = '#f8fafc'; ctx.fillRect(margin, y, W - margin * 2, rowH); }
                const r = W - margin;
                ctx.fillStyle = row.color; ctx.fillRect(r - 18, y + 13, 13, 13);
                drawText(row.path, r - 28, y + 26, 15, '400', '#172b4d', 500);
                drawText(row.kind, r - 560, y + 26, 15, '400', '#172b4d', 115);
                drawText(row.length, r - 700, y + 26, 15, '400', '#172b4d', 130);
                drawText(row.width, r - 850, y + 26, 15, '400', '#172b4d', 130);
                drawText(row.height, r - 1000, y + 26, 15, '400', '#172b4d', 130);
                drawText(row.category, r - 1150, y + 26, 15, '400', '#172b4d', 300);
                ctx.strokeStyle = '#e6ebf1'; ctx.beginPath(); ctx.moveTo(margin, y + rowH); ctx.lineTo(W - margin, y + rowH); ctx.stroke(); y += rowH;
              }
              newPage(true);
              heading('جمع بر اساس مقطع؛ شاخهٔ ۶ متری (مصرف / خرید)');
              categoryHeader();
              reportPdfData.categories.forEach(function(item, index) {
                if (y + rowH > bottom) { newPage(false); heading('ادامهٔ دسته‌بندی مقاطع'); categoryHeader(); }
                categoryRow(item, index);
              });
              if (y + 90 > bottom) newPage(false);
              heading('فهرست اشیای مدل'); tableHeader();
              const rows = reportPdfData.rows.length ? reportPdfData.rows : [{path:'شیء گروهی یا کامپوننتی پیدا نشد',kind:'',length:'',width:'',height:'',category:'',color:'#8a94a6'}];
              rows.forEach(function(row, index) {
                if (y + rowH > bottom) { newPage(false); heading('ادامهٔ فهرست اشیا'); tableHeader(); }
                objectRow(row, index);
              });
              pages.forEach(function(item, index) {
                ctx = item.getContext('2d'); ctx.strokeStyle = '#dce4ee'; ctx.beginPath(); ctx.moveTo(margin, H - 55); ctx.lineTo(W - margin, H - 55); ctx.stroke();
                drawText('صفحه ' + (index + 1) + ' از ' + pages.length, W - margin, H - 27, 14, '400', '#64748b');
              });
              window.pdfCanvases = pages; window.profileMeasureStatus('در حال ساخت PDF…'); window.sendPdfPage(0);
            };
            window.sendPdfPage = function(index) {
              if (!window.pdfCanvases || !window.pdfCanvases[index]) return;
              sketchup.pdfPage(window.pdfCanvases[index].toDataURL('image/jpeg', 0.84), index + 1, window.pdfCanvases.length);
            };
          </script>
        </body>
        </html>
      HTML
    end

    def show
      model = Sketchup.active_model
      rows = scan_model(model)
      @dialog ||= UI::HtmlDialog.new(
        dialog_title: 'گزارش ابعاد پروفیل‌ها',
        preferences_key: 'CodexProfileMeasure.Report',
        scrollable: true,
        resizable: true,
        width: 1000,
        height: 720,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      @dialog.set_html(report_html(model, rows))
      unless @callbacks_registered
        dialog = @dialog
        @dialog.add_action_callback('colorize') do |_context|
          count = apply_colors
          dialog.execute_script("window.profileMeasureStatus(#{JSON.generate("رنگ‌بندی #{count} پروفیل انجام شد؛ با Ctrl+Z قابل بازگشت است.")})")
        end
        @dialog.add_action_callback('restoreColors') do |_context|
          count = restore_colors
          dialog.execute_script("window.profileMeasureStatus(#{JSON.generate("رنگ قبلی #{count} پروفیل بازگردانده شد.")})")
        end
        @dialog.add_action_callback('refresh') { |_context| refresh }
        @dialog.add_action_callback('savePdf') do |_context|
          path = choose_pdf_path(model)
          if path
            @pdf_export = { path: path, pages: [] }
            dialog.execute_script('window.createPdfPages()')
          end
        end
        @dialog.add_action_callback('pdfPage') do |_context, data_url, page_number, page_count|
          next unless @pdf_export

          begin
            encoded = data_url.to_s.split(',', 2).last
            @pdf_export[:pages] << Base64.strict_decode64(encoded)
            if page_number.to_i < page_count.to_i
              dialog.execute_script("window.sendPdfPage(#{page_number.to_i})")
            else
              path = @pdf_export[:path]
              File.binwrite(path, build_pdf(@pdf_export[:pages]))
              @pdf_export = nil
              dialog.execute_script("window.profileMeasureStatus(#{JSON.generate('PDF ذخیره شد.')})")
              UI.messagebox("گزارش PDF ذخیره شد:\n#{path}")
            end
          rescue StandardError => error
            @pdf_export = nil
            dialog.execute_script("window.profileMeasureStatus(#{JSON.generate('ذخیره PDF ناموفق بود.')})")
            UI.messagebox("خطا هنگام ذخیرهٔ PDF:\n#{error.message}")
          end
        end
        @dialog.set_on_closed do
          if @dialog.equal?(dialog)
            @dialog = nil
            @callbacks_registered = false
            @pdf_export = nil
          end
        end
        @callbacks_registered = true
      end
      @dialog.show
    rescue StandardError => error
      UI.messagebox("خطا در ساخت گزارش:\n#{error.message}")
    end

    def refresh
      model = Sketchup.active_model
      return show unless @dialog

      @dialog.set_html(report_html(model, scan_model(model)))
    rescue StandardError => error
      UI.messagebox("خطا در به‌روزرسانی گزارش:\n#{error.message}")
    end

    def choose_pdf_path(model)
      directory = model.path.to_s.empty? ? Dir.home : File.dirname(model.path)
      filename = model.title.to_s.strip
      filename = 'profile-dimensions-report' if filename.empty?
      filename = filename.gsub(%r{[<>:"/\\|?*]}, '_') + '.pdf'
      path = UI.savepanel('ذخیره گزارش به صورت PDF', directory, filename)
      return nil unless path

      path.downcase.end_with?('.pdf') ? path : "#{path}.pdf"
    end

    def build_pdf(images)
      raise 'هیچ صفحه‌ای برای خروجی PDF ساخته نشد.' if images.empty?

      objects = []
      objects << '<< /Type /Catalog /Pages 2 0 R >>'
      page_ids = images.each_index.map { |index| 3 + index * 3 }
      kids = page_ids.map { |id| "#{id} 0 R" }.join(' ')
      objects << "<< /Type /Pages /Kids [#{kids}] /Count #{images.length} >>"

      images.each_with_index do |image, index|
        page_id = page_ids[index]
        content_id = page_id + 1
        image_id = page_id + 2
        content = 'q 842 0 0 595 0 0 cm /Im0 Do Q'
        objects << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 842 595] /Resources << /XObject << /Im0 #{image_id} 0 R >> >> /Contents #{content_id} 0 R >>"
        objects << "<< /Length #{content.bytesize} >>\nstream\n#{content}\nendstream"
        image_object = "<< /Type /XObject /Subtype /Image /Width #{PDF_PAGE_WIDTH} /Height #{PDF_PAGE_HEIGHT} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length #{image.bytesize} >>\nstream\n".b
        objects << image_object + image.b + "\nendstream".b
      end

      pdf = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b
      offsets = [0]
      objects.each_with_index do |object, index|
        offsets << pdf.bytesize
        pdf << "#{index + 1} 0 obj\n".b << object.to_s.b << "\nendobj\n".b
      end
      xref_offset = pdf.bytesize
      pdf << "xref\n0 #{objects.length + 1}\n0000000000 65535 f \n".b
      offsets.drop(1).each { |offset| pdf << format('%010d 00000 n ', offset).b << "\n".b }
      pdf << "trailer\n<< /Size #{objects.length + 1} /Root 1 0 R >>\nstartxref\n#{xref_offset}\n%%EOF\n".b
      pdf
    end

    def apply_colors
      model = Sketchup.active_model
      rows = profiles(scan_model(model))
      return 0 if rows.empty?

      colors = category_colors(rows)
      operation_started = false
      model.start_operation('Profile Measure - color profile groups', true)
      operation_started = true
      rows.each do |row|
        entity = row[:entity]
        unless entity.get_attribute(DICTIONARY, COLORIZED_KEY, false)
          previous = entity.material
          entity.set_attribute(DICTIONARY, PREVIOUS_MATERIAL_KEY, previous ? previous.name : '')
        end
        material_name = "PM Report #{row[:category]}"
        material = model.materials[material_name] || model.materials.add(material_name)
        material.color = Sketchup::Color.new(*colors.fetch(row[:category]))
        entity.material = material
        entity.set_attribute(DICTIONARY, COLORIZED_KEY, true)
        entity.set_attribute(DICTIONARY, CATEGORY_KEY, row[:category])
      end
      model.commit_operation
      operation_started = false
      model.active_view.invalidate
      rows.map { |row| row[:entity].persistent_id }.uniq.length
    rescue StandardError
      model.abort_operation if operation_started && model
      raise
    end

    def restore_colors
      model = Sketchup.active_model
      entities = colorized_instances(model.entities)
      return 0 if entities.empty?

      operation_started = false
      model.start_operation('Profile Measure - restore profile colors', true)
      operation_started = true
      entities.each do |entity|
        previous_name = entity.get_attribute(DICTIONARY, PREVIOUS_MATERIAL_KEY, '')
        entity.material = previous_name.empty? ? nil : model.materials[previous_name]
        entity.delete_attribute(DICTIONARY, COLORIZED_KEY)
        entity.delete_attribute(DICTIONARY, PREVIOUS_MATERIAL_KEY)
        entity.delete_attribute(DICTIONARY, CATEGORY_KEY)
      end
      model.commit_operation
      operation_started = false
      model.active_view.invalidate
      entities.length
    rescue StandardError
      model.abort_operation if operation_started && model
      raise
    end

    def colorized_instances(entities, result = [], definition_stack = [])
      entities.each do |entity|
        next unless supported?(entity)

        result << entity if entity.get_attribute(DICTIONARY, COLORIZED_KEY, false)
        definition_id = entity.definition.object_id
        next if definition_stack.include?(definition_id)

        colorized_instances(entity.definition.entities, result, definition_stack + [definition_id])
      end
      result.uniq
    end
  end
end
