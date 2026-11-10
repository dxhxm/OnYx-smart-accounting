# Phase 0 — Application Baseline

**Date:** 2026-11-06  
**Branch:** `main` at `7487cfb`  
**Node:** v26.5.0 | **npm:** 11.17.0

## Build Results

| Step | Command | Result | Notes |
|---|---|---|---|
| Install | `npm ci` | ✅ Pass | `package-lock.json` present, clean install |
| Prisma generate | `npx prisma generate` | ✅ Pass | Client generated at `node_modules/.prisma/client` |
| Production build | `npm run build` | ✅ Pass | Next.js 16.1.6 + Turbopack, Build ID: `h-ow4RO4dleH9InHjCWRr` |
| Lint | `npm run lint` | ⏭️ Not tested | ESLint configured but not run in baseline |

## Routes Compiled

All routes compiled successfully during `npm run build`:

| Route | Type |
|---|---|
| `/` | Landing page (static) |
| `/dashboard` | Dashboard (static shell) |
| `/ledger` | General ledger |
| `/scan` | Document OCR scanning |
| `/transactions` | Transaction management |
| `/governance` | Financial governance |
| `/upload` | Document upload |
| `/bank-reconciliation` | Bank reconciliation |
| `/api/ocr` | Nanonets OCR endpoint |
| `/api/documents` | Document CRUD |
| `/api/dashboard` | Dashboard metrics |
| `/api/dashboard/metrics` | Dashboard metrics detail |
| `/api/governance/*` | Governance endpoints |
| `/api/reconciliation/match` | Bank reconciliation |
| `/api/debug/db` | DB debug endpoint |

## Environment Variables

See `.env.example` for the complete list. Only `DATABASE_URL` is required for the app to start and show the landing page.

## Database

- **ORM:** Prisma 6.19.2 with `@prisma/adapter-pg`
- **Provider:** Neon Serverless PostgreSQL
- **Migrations:** 2 existing migrations (init + governance module)
- **Seed:** Creates demo company "Onyx Smart Accounting Demo"

## Known Issues / Pre-existing Conditions

1. **Dual Prisma clients:** `src/lib/prisma.ts` (simple) and `src/lib/db.ts` (with pg adapter) both exist. Services use `db.ts`.
2. **`src/lib/db.ts` has extensive commented-out code** showing iteration on connection setup — not a blocker.
3. **No existing tests:** No test framework, no test files. Will be addressed in Phase 1.
4. **No health endpoint:** No `/api/health` route exists. Will be added in Phase 1.
5. **Express server (`server.ts`):** Standalone Express API on port 4000 for governance routes. Not critical for landing page / core Next.js functionality.
6. **`next.config.ts` is empty:** No custom configuration (standalone output, etc.). Will need `output: "standalone"` for Docker in Phase 2.
7. **No `.nvmrc` or `engines` field existed** — added in this phase.

## Deliverables Created

- [x] `docs/baseline.md` — this file
- [x] `.env.example` — placeholder environment variables
- [x] `.nvmrc` — pins Node 26
- [x] `package.json` `engines` field — `node >=26.0.0`, `npm >=11.0.0`

## Exit Gate

✅ Repeatable local install (`npm ci`) and production build (`npm run build`) succeed.  
✅ Environment variable requirements documented.  
⏭️ App smoke test (landing page load) — to be confirmed by developer.

