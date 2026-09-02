# Shelfarr Home Assistant Add-on

This add-on wraps `ghcr.io/pedro-revez-silva/shelfarr` for Home Assistant OS with persistent storage and configurable host-backed audiobook/ebook/download paths.

Documentation: [github.com/Pedro-Revez-Silva/shelfarr](https://github.com/Pedro-Revez-Silva/shelfarr)

## Features

- Runs Shelfarr on port `80` internally, exposed on host port `5056`.
- Persists the SQLite databases, Active Storage files, and auto-generated secrets in the add-on's own storage (`/data`) — no separate config mapping needed.
- Uses configurable audiobook/ebook/downloads paths backed by Home Assistant `/share` or `/media`.
- Refuses startup if configured paths resolve outside `/share` or `/media`.
- No external database required (SQLite + Solid Queue, single container).
- Supports `amd64` and `aarch64`.
- Includes a baseline AppArmor profile.

## Not included

The optional **Libation companion** (Audible backup, beta) from upstream's `docker-compose.yml` is not part of this add-on — it's a second .NET container with its own control/token volumes. Shelfarr runs fine without it; the Audible backup feature in Settings will simply stay disconnected.

## Default paths

- Audiobooks: `/media/shelfarr/audiobooks`
- Ebooks: `/media/shelfarr/ebooks`
- Downloads (post-processing input): `/share/shelfarr/downloads`

## Installation

1. Add this repository to your Home Assistant instance:
   [![Open your Home Assistant instance and show the add add-on repository dialog with a specific repository URL pre-filled.](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fryan-winkler%2Fhassio-addons-repository)
2. Refresh the Add-on Store and install **Shelfarr**.
3. Configure options (defaults are safe for first run) — see [Options](#options) below.
4. Start the add-on.
5. Open `http://<HA_IP>:5056`.

Before first start, you may want to create your library folders on the Home Assistant host (for example via the Terminal & SSH add-on) — the add-on creates them automatically if missing, but pre-creating lets you set specific ownership first:

```bash
mkdir -p /share/shelfarr/downloads /media/shelfarr/audiobooks /media/shelfarr/ebooks
```

## Options

| Option | Default | Description |
| --- | --- | --- |
| `puid` / `pgid` | `1000` / `1000` | Ownership applied to writable mapped directories. |
| `chown_on_start` | `auto` | `auto`, `always`, or `never` — controls startup ownership fix-up. |
| `audiobooks_path` | `/media/shelfarr/audiobooks` | Where Shelfarr places completed audiobooks. |
| `ebooks_path` | `/media/shelfarr/ebooks` | Where Shelfarr places completed ebooks. |
| `downloads_path` | `/share/shelfarr/downloads` | Folder Shelfarr watches for completed downloads to post-process. |
| `rails_master_key` | *(blank)* | Leave blank to auto-generate and persist a secret key. |
| `rails_relative_url_root` | *(blank)* | Set only when reverse-proxying at a sub-path, e.g. `/shelfarr`, so generated links/assets resolve correctly. Leave blank for direct access or a dedicated subdomain (e.g. `shelfarr.example.com`, `shelfarr.internal`). |
| `rails_max_threads` | `3` | Puma thread count and SQLite connection pool size. |
| `job_concurrency` | `1` | Solid Queue background worker processes (downloads, imports, scans). |
| `auth_disabled` | `false` | Skip password login (username-only). Only enable on trusted networks. |
| `trust_nfs_uid_squash` | `false` | Enable if your library paths are on an NFS mount that squashes UIDs. |
| `allow_nonatomic_nfs_directory_publication` | `false` | Allows directory imports when NFS rejects atomic no-replace renames. Single-writer NFS exports only. |
| `tz` | *(blank)* | IANA time zone for displayed timestamps, e.g. `America/New_York`. Blank uses the container default (UTC). |

The external port (`5056` by default) can be changed anytime from the add-on's **Configuration → Network** tab — no option or env var needed for that.

## Next steps in the Shelfarr UI

The add-on only wires up storage, ports, and ownership. Everything else is configured from Shelfarr's own web UI after first login:

- **Admin → Settings → Search → Direct Downloads** — enable Anna's Archive, Z-Library, and/or LibriVox to fetch books without an indexer/download client. No extra containers needed; see [shelfarr.org/getting-started](https://shelfarr.org/getting-started.html#guide-direct).
- **Admin → Settings → Indexers / Download Clients** — if you use Prowlarr/SABnzbd-style acquisition instead of (or alongside) direct downloads.
- **Admin → Settings → Audiobookshelf** — optional library sync.

## Fix root warning / permission errors (PUID/PGID)

Set `puid` and `pgid` in the add-on Configuration tab to a non-root UID/GID that owns your media folders on the host.

How to find the correct values in Home Assistant:

1. Open the **Terminal & SSH** add-on (or SSH into the HA host).
2. Check the owner of your media folder:

```bash
stat -c '%u %g' /media/shelfarr/audiobooks
```

Set `puid`/`pgid` to those numbers, save Configuration, and restart the add-on.

## Update procedure

This add-on wraps the pre-built `shelfarr` image from GitHub Container Registry.

1. In HA, go to **Settings → Add-ons → Add-on Store**.
2. Click the **⋮ menu** (top right) → **Check for updates** (or **Reload**).
3. Open the **Shelfarr** add-on page.
4. Click **Update** to pull the latest image and restart.

## Validation behavior

- Startup fails if `audiobooks_path`, `ebooks_path`, or `downloads_path` resolve outside `/share` or `/media`.
- Database, Active Storage, and secrets persist in the add-on's private storage across restarts and updates.

## Notes

- This baseline avoids Home Assistant ingress and keeps direct port access.
- If `puid`/`pgid` change, restart the add-on to re-apply ownership to mapped directories.
