# Profile Measure for SketchUp

Free SketchUp extension for listing profile dimensions, grouping equal sections, summing lengths, estimating six-metre stock bars and cutting waste, arranging pieces by section, and exporting a selectable report to PDF.

## Download

- Latest version: **0.1.12**
- Installer: [`ProfileMeasure-0.1.12.rbz`](releases/ProfileMeasure-0.1.12.rbz)
- Persian download page content: [DOWNLOAD-PAGE-fa.md](DOWNLOAD-PAGE-fa.md)
- Persian usage guide: [README-fa.md](README-fa.md)

Install the RBZ from **Window → Extension Manager → Install Extension** in SketchUp Desktop. Use the toolbar button or **Extensions → Profile Measure → گزارش کامل ابعاد پروفیل‌ها** to open the report.

## Features

- Lists Groups and Components with length, width, height, name, and hierarchy path.
- Groups members by section and totals piece count and length.
- Shows simple six-metre stock-bar equivalents and rounded-up counts, plus a best-fit cutting estimate and leftover waste.
- Arranges profile lengths by section for review before cutting.
- Hides or shows model members of a section with its eye control; section colors are applied separately.
- One **Print / Save PDF** action opens report section choices. Save a 288 DPI PDF image or use vector printing for scalable text and tables.
- Adds dimension labels to selected profiles and reports their total length.
- Available from the toolbar, Extensions menu, and context menu.

## Calculation notes

The longest measured dimension is treated as profile length. Component scaling and model units are respected. Parent assemblies appear in the list but are excluded from section totals when their children are counted, preventing double-counting. Cutting layout uses six-metre stock and reuses an offcut only when another complete member of the same section fits. Saw kerf and cutting tolerances are not included.

## Compatibility

This package targets SketchUp Desktop on Windows. Other SketchUp versions and macOS have not been separately verified. The extension uses the SketchUp Ruby API and has no external Gem dependency.

## License

Free to download and use. See repository history for source and release changes.
