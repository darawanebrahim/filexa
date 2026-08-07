# Mega Sprint 18 — Module 2

Version: `1.18.2+35`

## Browser search stability
- Mobile browsing now uses Android WebView's native user agent instead of a stale synthetic Chrome UA.
- Returning from Desktop Mode restores the native mobile user agent.
- Default typed searches use Bing Search to reduce repeated image/CAPTCHA challenges commonly triggered by embedded WebView traffic.
- Existing tabs, cookies, history, bookmarks, desktop mode, and download interception remain intact.
- This does not bypass CAPTCHA or anti-bot protections. Websites can still request verification when their own risk systems decide it is necessary.

## Download pause UI
- Pause now changes a running task to `Paused` immediately, before Dio finishes cancelling the active stream.
- Download speed is reset to zero immediately on pause.
- Paused downloads no longer show an indeterminate/continuously animated progress bar when total size is unknown.
- Speed pill shows `Paused`, and ETA is hidden while paused.
- Resume continues to use the existing partial `.part` file flow.

## PDF Tools Core
A real local PDF processing service was added using `syncfusion_flutter_pdf`.

Working tools in PDF Studio:
- PDF page count and document metadata inspection.
- Extract searchable text from a PDF.
- Save As Copy without overwriting the original.
- Rotate selected page ranges 90° clockwise and save a new PDF.
- Delete selected pages while keeping the original PDF untouched.
- Extract/split selected page ranges into a new PDF.
- Merge the current PDF with one or more PDFs discovered by Filexa.
- Page selector accepts ranges such as `1-3,5,8-10`.
- Generated PDFs receive duplicate-safe output names.
- Generated files refresh Filexa's file provider and can be opened directly from the completion snackbar.

### PDF merge/extract implementation note
For merge/extract, pages are copied visually through PDF page templates. This preserves page appearance and dimensions, but advanced interactive structures such as some form fields or annotations may be flattened/not carried over. The original files are never modified.

## Dependency
Added:
- `syncfusion_flutter_pdf: ^34.1.32`

Syncfusion's PDF package requires an applicable Syncfusion commercial or Community license. Review the package licensing terms before distributing Filexa publicly.

## Safety
- PDF destructive operations create a new output file; originals stay untouched.
- Deleting every page is blocked.
- Invalid page ranges are rejected with a user-facing message.
