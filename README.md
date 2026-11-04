# Profile Measure for SketchUp

A free SketchUp extension for measuring grouped profiles and creating a clear cut-list style report. List each group or component with its length, width and height, calculate total profile length by section, color-code section groups in the model, and save the report as a PDF.

**Persian:** [راهنمای فارسی](README-fa.md)

![SketchUp profile measurement example](docs/profile-measure-demo.png)

## Download

Install the latest release directly in SketchUp:

- [Download ProfileMeasure-0.1.3.rbz](releases/ProfileMeasure-0.1.3.rbz)
- [View a sample PDF report](docs/sample-profile-report-fa.pdf)

In SketchUp, open **Extension Manager → Install Extension** and select the downloaded RBZ file.

## Features

- Report dimensions for visible SketchUp groups and components.
- Show length, width, height, object name and hierarchy path.
- Group profiles by cross-section (width × height) and show the total length for each group.
- Select profiles in the model from the report and apply a distinct color to each section group.
- Save a paginated PDF report directly from the extension; printing is also available separately.
- Add dimension labels to selected profiles and calculate the total length of the selection.
- Use the extension from the Extensions menu, toolbar icon, or context menu.

The report includes visible groups and components in the model. Parent assemblies appear in the object list; only leaf profiles are counted in section length totals to avoid double counting.

## Measurement notes

- Length is the largest local dimension; width and height are the remaining dimensions.
- Component and group scaling is included in the measurements.
- The model's SketchUp unit format is used.
- Section grouping uses width × height.
- The PDF report is rendered as page images to preserve Persian text layout; its text is not searchable or selectable.

## Compatibility

Built for desktop SketchUp using the SketchUp Ruby API. Install from the Extension Manager using the RBZ package above.

## Source

The extension is written in Ruby and uses SketchUp's Ruby API and HtmlDialog. No external gems are required for report PDF generation.

---
افزونهٔ رایگان اسکچاپ برای اندازه‌گیری پروفیل‌ها: نمایش طول، عرض و ارتفاع گروه‌ها و کامپوننت‌ها، دسته‌بندی بر اساس ابعاد مقطع، محاسبهٔ جمع طول هر دسته، رنگ‌بندی گروه‌ها و ذخیرهٔ گزارش PDF.
