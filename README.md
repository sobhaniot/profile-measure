# Profile Measure for SketchUp

A free SketchUp extension for measuring grouped profiles and creating a cut-list style report. List each group or component with its length, width and height, group profiles by cross-section, calculate total profile length and estimate both combined-length stock-bar counts and cut-aware 6 m bar layouts with leftover waste by section.

**Persian:** [راهنمای فارسی](README-fa.md)

![SketchUp profile measurement example](docs/profile-measure-demo.png)

## Download

Install the latest release directly in SketchUp:

- [Download ProfileMeasure-0.1.7.rbz](releases/ProfileMeasure-0.1.7.rbz)
- [View a sample PDF report](docs/sample-profile-report-fa.pdf)

In SketchUp, open **Extension Manager → Install Extension** and select the downloaded RBZ file.

## Features

- Report dimensions for visible SketchUp groups and components.
- Show length, width, height, object name and hierarchy path.
- Group profiles by cross-section (width × height) and show each section's item count and total length.
- Show the equivalent stock-bar consumption beside the rounded simple count, a cut-aware bar estimate, and unusable leftover waste for a clearer section summary.
- Color-code section groups in the model and toggle each section color from its row in the report.
- Save a paginated PDF report directly from the extension; printing is available separately.
- Add dimension labels to selected profiles and calculate the total length of the selection.
- Use the extension from the Extensions menu, toolbar icon, or context menu.

The report includes visible groups and components in the model. Parent assemblies appear in the object list; only leaf profiles are counted in section totals to avoid double counting. The simple estimate divides each section's combined length by 6 m. The cut-aware estimate packs member lengths from largest to smallest within 6 m stock bars, reusing a remnant only when another complete member of the same section fits. Saw kerf and cutting tolerance are not included.

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
