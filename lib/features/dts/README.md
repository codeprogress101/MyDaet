# DTS (Document Tracking System)

## Overview
Tracks hard-copy documents using QR stickers, custody transfers, and resident tracking.

## Collections
- `dts_documents/{docId}`
- `dts_documents/{docId}/timeline/{eventId}`
- `dts_counters/{year}`
- `dts_qr_index/{qrCode}`
- `dts_qr_codes/{qrCode}`

## Storage
- `/dts/{docId}/cover/{timestamp}.jpg`
- `/dts/{docId}/attachments/{timestamp}-{filename}`
- `/dts_qr_codes/{qrCode}.png`
- `/dts_qr_exports/{batch}.zip`

## Security Notes
- QR reuse is blocked with `dts_qr_index` and `dts_qr_codes.status`.
- Timeline is append-only.
- Staff state transitions are server-enforced via callables:
  - `dtsInitiateTransfer`
  - `dtsCancelTransfer`
  - `dtsRejectTransfer`
  - `dtsConfirmReceipt`
  - `dtsUpdateStatus`
  - `dtsAddNote`
- Tracking PIN checks include brute-force lockout (`resource-exhausted` on repeated failures).

## Manual Test Steps
1) Staff intake:
   - Open **Documents** tab (staff role).
   - Tap **Scan** and scan a new QR sticker.
   - Fill the intake form and capture a cover photo.
   - Confirm Tracking No + PIN are shown.
2) Transfer:
   - Open the document.
   - Tap **Transfer**, pick destination office, submit.
   - Log in as receiving office and scan QR.
   - Tap **Confirm receipt**.
3) Reject flow:
   - In receiving office, tap **Reject**, add note + optional attachment.
   - Confirm document is returned and timeline event is appended.
4) Resident tracking:
   - Open **Documents** tab (resident role).
   - Use **Track Document** with Tracking No + PIN.
   - Confirm safe fields and Manila time formatting.
5) Save to account:
   - From tracking result, tap **Save to My Documents**.
   - Confirm document appears in resident **My Documents**.

## QR Management (Super Admin)
- Open **Documents** -> **QR Management**.
- Generate 10 QR stickers.
- Export ZIP (visible / unused / used scope) for printing.
