# The Guthries — Family Site

A single-file, static web app (`index.html`) for a private family photo/story feed. It loads the Supabase JS SDK from a CDN and talks directly to a hosted Supabase project (auth, Postgres, storage). There is no build step, no package manager, and no local backend.

- `index.html` — the entire application (HTML, CSS, and JS inline). Supabase URL + anon key are hardcoded near the top of the `<script>` block.
- `supabase-setup.sql` — schema/RLS/storage setup, intended to be run once in the hosted Supabase SQL editor (not needed for local dev).
- `SETUP-INSTRUCTIONS.md` — end-user deployment guide (Supabase + Cloudflare Pages).

## Cursor Cloud specific instructions

- This is a static site with no dependencies to install. There is nothing to build/compile.
- Run it by serving the repo root over HTTP, then open `index.html`:
  - `python3 -m http.server 8000` (from `/workspace`), then visit `http://localhost:8000/index.html`.
  - Do NOT open via `file://` — the Supabase SDK and auth flows expect an http(s) origin.
- Backend is a live hosted Supabase project (credentials are committed in `index.html`). Local dev hits that real backend; account signups and posts are real writes against it. Use throwaway emails (e.g. `something@example.com`) when testing.
- Email confirmation is disabled on the project, so `signup` returns a session immediately and the app auto-signs-in via the `onAuthStateChange` handler (no separate sign-in step is actually required after creating an account).
- No lint or automated test tooling exists in this repo. "Testing" means manually exercising the UI (sign up / sign in / post / react / comment) in the browser.
