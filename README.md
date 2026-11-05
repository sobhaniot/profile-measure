# Profile Measure for SketchUp

A free SketchUp extension for measuring grouped profiles and creating a cut-list style report. List each group or component with its length, width and height, group profiles by cross-section, calculate total profile length and estimate 6 m stock-bar consumption by section.

**Persian:** [راهنمای فارسی](README-fa.md)

![SketchUp profile measurement example](docs/profile-measure-demo.png)

## Download

Install the latest release directly in SketchUp:

- [Download ProfileMeasure-0.1.4.rbz](releases/ProfileMeasure-0.1.4.rbz)
- [View a sample PDF report](docs/sample-profile-report-fa.pdf)

In SketchUp, open **Extension Manager → Install Extension** and select the downloaded RBZ file.

## Features

- Report dimensions for visible SketchUp groups and components.
- Show length, width, height, object name and hierarchy path.
- Group profiles by cross-section (width × height) and show each section's item count and total length.
- Estimate 6 m stock-bar usage for every section: decimal consumption followed by the whole bar count rounded up, for example **6.5 / 7**.
- Color-code section groups in the model.
- Save a paginated PDF report directly from the extension; printing is available separately.
- Add dimension labels to selected profiles and calculate the total length of the selection.
- Use the extension from the Extensions menu, toolbar icon, or context menu.

The report includes visible groups and components in the model. Parent assemblies appear in the object list; only leaf profiles are counted in section totals to avoid double counting. Bar estimates are based on the combined length of each section divided by 6 m.

## Measurement notes

- Length is the largest local dimension; width and height are the remaining dimensions.
- Component and group scaling is included in the measurements.
- The model's SketchUp unit format is used.
- Section grouping uses width × height.
- PDF pages are rendered as images to preserve Persian text layout; PDF text is not searchable or selectable.

## Compatibility

Built for desktop SketchUp using the SketchUp Ruby API. Install from the Extension Manager using the RBZ package above.

## Source

The extension is written in Ruby and uses SketchUp's Ruby API and HtmlDialog. No external gems are required for report PDF generation.

---
افزونهٔ رایگان اسکچاپ برای اندازه‌گیری پروفیل‌ها: نمایش طول، عرض و ارتفاع، دسته‌بندی مقاطع، جمع طول هر دسته، برآورد شاخه‌های ۶ متری و ذخیرهٔ گزارش PDF.
