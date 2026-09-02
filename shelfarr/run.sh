#!/bin/bash
set -Eeuo pipefail

OPTIONS_JSON="/data/options.json"
DEFAULT_AUDIOBOOKS_PATH="/media/shelfarr/audiobooks"
DEFAULT_EBOOKS_PATH="/media/shelfarr/ebooks"
DEFAULT_DOWNLOADS_PATH="/share/shelfarr/downloads"

log() {
    echo "[shelfarr-addon] $*"
}

die() {
    echo "[shelfarr-addon] ERROR: $*" >&2
    exit 1
}

read_opt() {
    local key="$1"
    local val
    # `// empty` would also swallow a real `false` (jq treats it as falsy);
    # compare to null explicitly so booleans round-trip correctly.
    val="$(jq -r --arg k "$key" 'if .[$k] == null then "" else (.[$k] | tostring) end' "$OPTIONS_JSON" 2> /dev/null)" || true
    printf '%s' "$val"
}

require_mapped_path() {
    local label="$1"
    local raw="$2"
    local resolved
    resolved="$(realpath -m "$raw")"
    case "$resolved" in
        /share | /share/* | /media | /media/*) ;;
        *) die "${label} '${raw}' resolves to '${resolved}', which is outside /share and /media" ;;
    esac
    printf '%s\n' "$resolved"
}

[[ -f "$OPTIONS_JSON" ]] || die "Missing options file at ${OPTIONS_JSON}"

PUID="$(read_opt puid)"; PUID="${PUID:-1000}"
PGID="$(read_opt pgid)"; PGID="${PGID:-1000}"
CHOWN_ON_START="$(read_opt chown_on_start)"; CHOWN_ON_START="${CHOWN_ON_START:-auto}"
RAILS_MASTER_KEY_OPT="$(read_opt rails_master_key)"
RAILS_RELATIVE_URL_ROOT_OPT="$(read_opt rails_relative_url_root)"
RAILS_MAX_THREADS_OPT="$(read_opt rails_max_threads)"
JOB_CONCURRENCY="$(read_opt job_concurrency)"; JOB_CONCURRENCY="${JOB_CONCURRENCY:-1}"
AUTH_DISABLED="$(read_opt auth_disabled)"; AUTH_DISABLED="${AUTH_DISABLED:-false}"
TRUST_NFS_UID_SQUASH_OPT="$(read_opt trust_nfs_uid_squash)"; TRUST_NFS_UID_SQUASH_OPT="${TRUST_NFS_UID_SQUASH_OPT:-false}"
ALLOW_NONATOMIC_NFS_OPT="$(read_opt allow_nonatomic_nfs_directory_publication)"; ALLOW_NONATOMIC_NFS_OPT="${ALLOW_NONATOMIC_NFS_OPT:-false}"
TZ_OPT="$(read_opt tz)"

AUDIOBOOKS_PATH_RAW="$(read_opt audiobooks_path)"; AUDIOBOOKS_PATH_RAW="${AUDIOBOOKS_PATH_RAW:-$DEFAULT_AUDIOBOOKS_PATH}"
EBOOKS_PATH_RAW="$(read_opt ebooks_path)"; EBOOKS_PATH_RAW="${EBOOKS_PATH_RAW:-$DEFAULT_EBOOKS_PATH}"
DOWNLOADS_PATH_RAW="$(read_opt downloads_path)"; DOWNLOADS_PATH_RAW="${DOWNLOADS_PATH_RAW:-$DEFAULT_DOWNLOADS_PATH}"

AUDIOBOOKS_PATH="$(require_mapped_path "audiobooks_path" "$AUDIOBOOKS_PATH_RAW")"
EBOOKS_PATH="$(require_mapped_path "ebooks_path" "$EBOOKS_PATH_RAW")"
DOWNLOADS_PATH="$(require_mapped_path "downloads_path" "$DOWNLOADS_PATH_RAW")"

mkdir -p "$AUDIOBOOKS_PATH" "$EBOOKS_PATH" "$DOWNLOADS_PATH"

# Shelfarr expects its library/download folders at fixed container paths;
# point those at whatever HA-mapped folders the user configured.
for pair in "/audiobooks:${AUDIOBOOKS_PATH}" "/ebooks:${EBOOKS_PATH}" "/downloads:${DOWNLOADS_PATH}"; do
    dst="${pair%%:*}"
    src="${pair##*:}"
    [[ -L "$dst" ]] && rm -f "$dst"
    [[ -d "$dst" && ! -L "$dst" ]] && rmdir "$dst" 2> /dev/null || true
    ln -sfn "$src" "$dst"
done

# /data is the add-on's always-persistent storage; move Shelfarr's sqlite
# databases, Active Storage files, and auto-generated secrets there so they
# survive add-on updates without needing a separate config mapping.
if [[ ! -L /rails/storage ]]; then
    mkdir -p /data
    if [[ -d /rails/storage ]]; then
        cp -an /rails/storage/. /data/ 2> /dev/null || true
        rm -rf /rails/storage
    fi
    ln -sfn /data /rails/storage
fi

export PUID PGID CHOWN_ON_START
export SOLID_QUEUE_IN_PUMA=1
export JOB_CONCURRENCY
export DISABLE_AUTH="$AUTH_DISABLED"
export TRUST_NFS_UID_SQUASH="$TRUST_NFS_UID_SQUASH_OPT"
export SHELFARR_SETTING_ALLOW_NONATOMIC_NFS_DIRECTORY_PUBLICATION="$ALLOW_NONATOMIC_NFS_OPT"

# RAILS_MAX_THREADS sizes BOTH the Puma thread pool (config/puma.rb) and the
# database connection pool (config/database.yml), but Solid Queue's own
# supervisor -- always running embedded in Puma here via SOLID_QUEUE_IN_PUMA
# -- needs a pool of at least 5 regardless of that setting. Below 5, the
# pool silently exhausts under load (not at boot -- ours ran ~32 minutes
# before Solid Queue killed Puma) and every request 502s from Thruster
# until the add-on is restarted. Leaving this unset lets Puma default to 3
# threads (config/puma.rb) while the DB pool independently defaults to 5
# (config/database.yml) -- that mismatch-by-design is what upstream ships
# and relies on, so only export it when the user opts into a higher value.
if [[ -n "$RAILS_MAX_THREADS_OPT" ]]; then
    [[ "$RAILS_MAX_THREADS_OPT" =~ ^[0-9]+$ && "$RAILS_MAX_THREADS_OPT" -ge 5 ]] \
        || die "rails_max_threads must be >= 5 (Solid Queue needs that many DB connections when embedded in Puma) or left blank for the safe default"
    export RAILS_MAX_THREADS="$RAILS_MAX_THREADS_OPT"
fi

if [[ -n "$RAILS_MASTER_KEY_OPT" ]]; then
    export RAILS_MASTER_KEY="$RAILS_MASTER_KEY_OPT"
fi
if [[ -n "$RAILS_RELATIVE_URL_ROOT_OPT" ]]; then
    export RAILS_RELATIVE_URL_ROOT="$RAILS_RELATIVE_URL_ROOT_OPT"
fi
if [[ -n "$TZ_OPT" ]]; then
    export TZ="$TZ_OPT"
fi

log "Configuration summary:"
log "  puid:pgid=${PUID}:${PGID} chown_on_start=${CHOWN_ON_START}"
log "  audiobooks_path=${AUDIOBOOKS_PATH}"
log "  ebooks_path=${EBOOKS_PATH}"
log "  downloads_path=${DOWNLOADS_PATH}"
log "  rails_max_threads=${RAILS_MAX_THREADS_OPT:-<default: puma=3, db pool=5>} job_concurrency=${JOB_CONCURRENCY}"
log "  rails_relative_url_root=${RAILS_RELATIVE_URL_ROOT_OPT:-<none>}"
log "  auth_disabled=${AUTH_DISABLED} trust_nfs_uid_squash=${TRUST_NFS_UID_SQUASH_OPT} allow_nonatomic_nfs_directory_publication=${ALLOW_NONATOMIC_NFS_OPT}"
log "  tz=${TZ_OPT:-<container default>}"

cd /rails
exec /rails/bin/docker-entrypoint ./bin/thrust ./bin/rails server
