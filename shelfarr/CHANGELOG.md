# Changelog

## 2026.08.31.1_2

- Added a CI smoke test (PR check): builds the image, boots it with a stub `/data/options.json`, and confirms `/up` returns 200 and the storage/library symlinks resolve correctly before any change can merge.
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
