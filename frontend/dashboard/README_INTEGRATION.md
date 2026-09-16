# MeterVision Dashboard - Backend Integration

This frontend is aligned to the supplied `backend-pspcl` FastAPI implementation.

## Run

1. Ensure the FastAPI backend is running, normally at `http://127.0.0.1:8000`.
2. Copy `.env.example` to `.env` and set `VITE_API_BASE_URL`.
3. Run `npm install`.
4. Run `npm run dev`.

## Implemented backend modules

- `/auth`
- `/dashboard`
- `/readings`
- `/images`
- `/anomalies`
- `/lcr`
- `/consumers`
- `/users`
- `/notifications`
- `/sync`

The unmounted `/ocr` router is intentionally not called directly by the frontend. OCR data is displayed when returned by `/readings/{reading_id}/details`.

No fake analytics or audit-log API was added because those endpoints are not mounted in the supplied backend.
