# Changelog

## 2026.08.31.1

- First Home Assistant add-on packaging for Shelfarr.
- Wraps `ghcr.io/pedro-revez-silva/shelfarr` with persistent data under the add-on's own `/data` storage.
- Configurable audiobooks/ebooks/downloads paths backed by `/share` or `/media`, with startup path safety checks.
- Non-root runtime defaults (`puid`/`pgid`) and startup ownership handling, delegated to upstream's own entrypoint.
- Surfaced `rails_max_threads`, `job_concurrency`, `auth_disabled`, and `trust_nfs_uid_squash` as options.
- Libation (Audible backup) companion container not included.
