# Mega Sprint 18 — Module 3 + PDF Dialog Hotfix

Version: `1.18.3+37`

## Critical runtime hotfix
- Reworked the PDF page-selection dialog so it no longer owns/disposes a temporary `TextEditingController` while the route dismissal animation is still completing.
- Empty page input now cancels safely instead of continuing into parsing.
- Tapping outside the dialog, Cancel, Back, or submitting an empty value returns cleanly without mutating the PDF.
- Added mounted/context guards around the browser copy snackbar and file-action navigation flows flagged by `use_build_context_synchronously`.

## Module 3 — PDF Page Organizer
- Add blank page: appends a blank page and saves a new PDF.
- Duplicate pages: duplicates selected page ranges into a new output PDF.
- Reorder pages: accepts a full custom order such as `1,3,2,4` and validates that every page appears exactly once.
- Text watermark: places centered watermark text on all pages and saves a new PDF.
- Existing rotate, extract/split, delete, merge, text extraction and Save As tools remain available.

## Safety
- The original PDF is never overwritten by page-manipulation tools.
- Invalid/empty page selections are rejected or cancelled safely.
- Reorder blocks duplicate, missing and out-of-range pages.

## Notes
- PDF processing continues to use `syncfusion_flutter_pdf`; review the applicable Syncfusion license before public distribution.
- Merge/extract/reorder/duplicate operations copy page appearance through page templates; some advanced interactive annotations/forms can be flattened.
