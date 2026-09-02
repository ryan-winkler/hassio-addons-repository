# Changelog

## 2026.08.31.1_7

- **TEMPORARY DIAGNOSTIC (extends 1_6) — will be reverted.** The URL is confirmed correct now, but syncing still produces zero new items with zero errors. Extends the boot-time diagnostic to print the configured scan-library-id settings, every library Audiobookshelf reports (id/name/media_type/`audiobook_library?`), and the actual result (or exception) of running a real sync — to see directly why zero libraries are being picked up instead of continuing to guess.

## 2026.08.31.1_6

- **TEMPORARY DIAGNOSTIC — will be reverted.** Adds a boot-time check that reads the raw `audiobookshelf_url` setting directly via `bin/rails runner`, logs it, and corrects it if it doesn't match the expected value. This is instance-specific troubleshooting scaffolding for a live investigation into why the setting appears to revert to a different port than what's saved in the UI, and is not meant to ship long-term. No-ops cleanly on any instance without existing secret/encryption key files (fresh installs, CI).

## 2026.08.31.1_5

- **Fixed: "Audiobook path not writable; Ebook path not writable"** in Shelfarr's own System Health check. `run.sh` created the mapped output directories as root but never chowned them to PUID:PGID, unlike upstream's own `/rails/storage` handling — confirmed live (`root:root`, mode `755`). Now applies the same `chown_on_start` policy (auto/always/never) to `audiobooks_path`, `ebooks_path`, and `downloads_path` that already covered storage. CI smoke test now checks all three are writable as uid 1000 (default PUID), so this can't silently regress again.

## 2026.08.31.1_4

- **Fixed: add-on wouldn't start** ("Invalid configuration — expected int"). `rails_max_threads: ""` as the options default was invalid against its `int?` schema type (empty string isn't a valid int, unlike the `str?` fields). Removed the default entirely — the option is still available, just not pre-populated, matching every other optional non-string field's convention.

## 2026.08.31.1_3

- **Fixed a production crash**, found via live testing on a real HA instance: the default `rails_max_threads: 3` forced BOTH the Puma thread pool and the SQLite connection pool down to 3 (they share one env var), but Solid Queue — which always runs embedded in Puma here (`SOLID_QUEUE_IN_PUMA=1`) — needs a pool of at least 5. The pool doesn't exhaust at boot; ours ran for ~32 minutes before Solid Queue killed Puma, leaving Thruster (the add-on's own internal proxy) 502ing every request until manually restarted — and the CI smoke test's ~15s boot check never runs long enough to catch this class of bug.
- `rails_max_threads` is now blank/optional by default, restoring upstream's own mismatched-but-working fallback (Puma defaults to 3 threads via `config/puma.rb`, the DB pool independently defaults to 5 via `config/database.yml`). If you do set it, the add-on now refuses to start below 5 with a clear error instead of silently crashing later.

## 2026.08.31.1_2

- Added a CI smoke test (PR check): builds the image, boots it with a stub `/data/options.json`, and confirms `/up` returns 200 and the storage/library symlinks resolve correctly before any change can merge. This caught a real bug (see below) that the earlier build-only CI missed.
- **Fixed:** `run.sh`'s option reader returned the literal string `"null"` for any option key not present in `options.json` (jq's `-e`/`.[$k]` prints `null` before failing), which bash's `${VAR:-default}` doesn't treat as empty — so every option silently fell through to a broken value like `audiobooks_path=/rails/null` instead of its documented default. Now compares against `null` inside `jq` and returns a genuinely empty string.
- Fixed addon-linter failures: removed `webui` (invalid once Ingress is enabled) and replaced the deprecated `watchdog` config field with a native Docker `HEALTHCHECK` against `/up`.
- Documented reverse proxy / custom domain behavior, verified against Shelfarr's actual Rails config: no Host header blocking, no forced-HTTPS redirect loop, and that ActionCable (`/cable`) needs WebSocket forwarding for live page updates (degrades gracefully to manual-refresh if not forwarded).

## 2026.08.31.1_1

- Surfaced the remaining documented Shelfarr environment variables as options: `rails_relative_url_root` (sub-path reverse proxy support), `allow_nonatomic_nfs_directory_publication`, and `tz`.
- Added Ingress + sidebar panel entry (convenience access only, no SSO — config-only change, no image rebuild). See README's "Ingress (sidebar access)" section for the known dynamic-path caveat.
- Added `watchdog` (checks `/up`, auto-restarts on hang) and `backup: cold` (stops the container during Supervisor backups so SQLite databases aren't snapshotted mid-write).

## 2026.08.31.1

- First Home Assistant add-on packaging for Shelfarr.
- Wraps `ghcr.io/pedro-revez-silva/shelfarr` with persistent data under the add-on's own `/data` storage.
- Configurable audiobooks/ebooks/downloads paths backed by `/share` or `/media`, with startup path safety checks.
- Non-root runtime defaults (`puid`/`pgid`) and startup ownership handling, delegated to upstream's own entrypoint.
- Surfaced `rails_max_threads`, `job_concurrency`, `auth_disabled`, and `trust_nfs_uid_squash` as options.
- Libation (Audible backup) companion container not included.
