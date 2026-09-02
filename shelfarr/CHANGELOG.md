# Changelog

## 2026.08.31.1_1

- Surfaced the remaining documented Shelfarr environment variables as options: `rails_relative_url_root` (sub-path reverse proxy support), `allow_nonatomic_nfs_directory_publication`, and `tz`.

## 2026.08.31.1

- First Home Assistant add-on packaging for Shelfarr.
- Wraps `ghcr.io/pedro-revez-silva/shelfarr` with persistent data under the add-on's own `/data` storage.
- Configurable audiobooks/ebooks/downloads paths backed by `/share` or `/media`, with startup path safety checks.
- Non-root runtime defaults (`puid`/`pgid`) and startup ownership handling, delegated to upstream's own entrypoint.
- Surfaced `rails_max_threads`, `job_concurrency`, `auth_disabled`, and `trust_nfs_uid_squash` as options.
- Libation (Audible backup) companion container not included.
