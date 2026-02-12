# DTS (Document Tracking System)

## Overview
Tracks hard-copy documents using QR stickers, custody transfers, and resident tracking.

## Collections
- `dts_documents/{docId}`
- `dts_documents/{docId}/timeline/{eventId}`
- `dts_counters/{year}`
- `dts_qr_index/{qrCode}`

## Storage
- `/dts/{docId}/cover/{timestamp}.jpg`
- `/dts/{docId}/attachments/{timestamp}-{filename}`

## Manual Test Steps
1) **Staff intake**
   - Open **Documents** tab (staff role).
   - Tap **Scan** and scan a new QR sticker.
   - Fill in the intake form and capture a cover photo.
   - Confirm you see a Tracking No + PIN.

2) **Transfer**
   - Open the created document.
   - Tap **Transfer**, pick an office, and submit.
   - On receiving office account, scan the QR and tap **Confirm receipt**.

3) **Resident tracking**
   - Open **Documents** tab (resident role).
   - Use **Track Document** with Tracking No + PIN.
   - Verify status + office info displays (office hidden when confidentiality = `confidential`).

4) **Timeline**
   - Confirm timeline entries appear for received, transfer, status updates, and notes.

## Notes
- QR reuse is blocked via `dts_qr_index`.
- Timeline is append-only (no update/delete).

## QR Generation
- Callable Cloud Function: `generateDtsQrCodes`
  - Input: `{ count: number, prefix?: string }`
  - Output: list of codes + storage paths under `dts_qr_codes/`.

## QR Management (Super Admin)
- Open **Documents** → tap **QR Management** (magnifier icon).
- Export ZIP button downloads a zip of the latest 10 QR PNGs for printing.
