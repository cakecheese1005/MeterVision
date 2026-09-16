# MeterVision Admin Dashboard

A React + TypeScript admin dashboard for the PSPCL / MeterVision FastAPI backend
(`backend_for_claude.zip`). Built directly against the backend's real, mounted
endpoints — no mock data, no invented APIs, no invented fields.

## Stack

- React 18 + TypeScript
- Vite
- Tailwind CSS
- React Router
- Axios

## Backend URL

The app talks to your FastAPI backend via `VITE_API_BASE_URL`, defaulting to
`http://127.0.0.1:8000`.

```bash
cp .env.example .env
# edit .env if your backend runs somewhere else
```

## Install & run

```bash
npm install
npm run dev
```

Then start the backend separately (from the `backend_for_claude` folder):

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Make sure the backend's `.env` has `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`,
`SUPABASE_ANON_KEY`, and `JWT_SECRET` set, and that
`app/core/config.py`'s `CORS_ORIGINS` includes `http://localhost:5173`
(it does, by default).

## Implemented modules (real backend calls)

| Page | Backend endpoint(s) | Notes |
|---|---|---|
| Login | `POST /auth/login` | Stores `access_token` / `refresh_token`, then calls `/auth/me` |
| Overview | `GET /readings/` | KPIs are calculated client-side from the readings list — there is no dashboard-summary endpoint mounted |
| Readings | `GET /readings/`, `POST /readings/create` | Table shows real, raw `meter_readings` columns; create form matches `ReadingCreate` exactly |
| Meter Images | `POST /images/upload` | multipart upload; no gallery/list endpoint exists, so only the just-uploaded image is shown |
| Sync Queue | `GET /sync/sync/pending`, `POST /sync/sync/mark-synced/{id}` | Both endpoints have backend bugs — see below. The UI calls them as they actually exist and surfaces the real response/error |
| Profile | `GET /auth/me`, `PUT /auth/profile`, `PUT /auth/password` | |

## Not implemented (no working backend API)

Anomalies, LCR Cases, Notifications, Analytics, Consumers, Officers. Each
shows a "Backend functionality not currently available" empty state.
`app/routers/dashboard.py`, `anomalies.py`, and `lcr.py` all exist in the zip
but **are not included in `app/main.py`**, so none of their routes actually
run. `anomalies.py` also imports `app.models.schemas.AnomalyCreate`, a module
that doesn't exist in the zip at all — it would fail on import even if
mounted. `dashboard.py` additionally queries a table named `"readings"`,
which doesn't exist (the real table is `meter_readings`).

## Known backend limitations (not fixed here, by design)

1. **Sync routes are double-prefixed.** `app/routers/sync.py` sets
   `prefix="/sync"` on its own router, and `app/main.py` adds another
   `prefix="/sync"` when mounting it, so the live paths are
   `/sync/sync/pending` and `/sync/sync/mark-synced/{id}`, not `/sync/pending`.
2. **`GET /sync/sync/pending` will always return an empty list.** It filters
   `sync_status == "PENDING"` (uppercase), but
   `database/migrations/010_sync_queue.sql` only allows lowercase values
   (`pending` / `success` / `failed`) — so no row can ever match.
3. **`POST /sync/sync/mark-synced/{id}` will likely fail.** It writes
   `sync_status = "SYNCED"`, which the same CHECK constraint rejects.
4. **`readings` and `images` routers have no authentication check** — no
   `get_current_user` dependency — even though the JWT infrastructure exists
   and is used by `/auth/*`. The frontend still attaches the bearer token to
   every request in case this changes.
5. **`POST /readings/create` hardcodes `officer_id`** to a fixed UUID
   server-side. It ignores whoever is logged in, and the request schema
   doesn't even accept an officer field — so the Create Reading form doesn't
   offer one.
6. **`GET /readings/` returns raw table rows**, not the richer
   `ReadingResponse` model defined in `app/models/reading.py` (that model is
   unused). There is no join to `consumers` or `users` anywhere in the
   backend, so readings only ever expose `consumer_id` / `officer_id` as raw
   UUIDs — never a name.

None of the above were changed in the backend; the frontend was built to
call the real, current behavior and surface these issues honestly (empty
states, error banners) instead of hiding them.

## Project structure

```
src/
  api/        typed request functions per resource (auth, readings, images, sync)
  components/ shared UI (sidebar, topbar, tables, badges, modal, forms, icons)
  context/    AuthContext (session/token), ToastContext (notifications)
  hooks/      useAuth
  layouts/    DashboardLayout (sidebar + topbar + routed content)
  pages/      one file per route
  types/      TypeScript types matching the backend's actual request/response shapes
  utils/      formatting helpers
```

## Manual test checklist

1. Start the backend, confirm `GET /health` responds.
2. `npm run dev`, open the app, confirm it redirects to `/login`.
3. Log in with a real user from the `users` table (password checked via
   bcrypt against `password_hash`).
4. Confirm the topbar shows the real name/role from `/auth/me`.
5. Overview: confirm KPI numbers match what you'd get from
   `GET /readings/` manually.
6. Readings: create a reading with a real `consumer_id` UUID, confirm it
   appears in the table after the toast.
7. Meter Images: upload an image against that reading's ID, confirm the
   returned URL renders.
8. Sync Queue: confirm it loads (likely empty per known issue #2) and that
   clicking "Mark synced" surfaces a real error if the backend rejects it.
9. Log out, confirm you're redirected to `/login` and protected routes are
   no longer reachable.
