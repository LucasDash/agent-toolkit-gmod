#!/bin/sh
set -eu

DATA_ROOT=/srv/gmod
SERVER_ROOT=${SERVER_ROOT:-/srv/gmod/server}
SERVER_BRANCH=${SERVER_BRANCH:-x86-64}
SERVER_PORT=${SERVER_PORT:-28115}
SERVER_MAP=${SERVER_MAP:-gm_construct}
SERVER_GAMEMODE=${SERVER_GAMEMODE:-sandbox}
SERVER_MAXPLAYERS=${SERVER_MAXPLAYERS:-8}
BRANCH_MARKER="$DATA_ROOT/.server-branch"

case "$SERVER_BRANCH" in
    x86-64|public) ;;
    *) echo "Unsupported SERVER_BRANCH '$SERVER_BRANCH'; use x86-64 or public." >&2; exit 2 ;;
esac

case "$SERVER_BRANCH" in
    x86-64)
        SERVER_LAUNCHER=srcds_run_x64
        SERVER_BINARY=bin/linux64/srcds
        ;;
    public)
        if [ -x "$SERVER_ROOT/srcds_run_x64" ] && [ -x "$SERVER_ROOT/bin/linux64/srcds" ]; then
            SERVER_LAUNCHER=srcds_run_x64
            SERVER_BINARY=bin/linux64/srcds
        else
            SERVER_LAUNCHER=srcds_run
            SERVER_BINARY=bin/linux32/srcds
        fi
        ;;
esac

exec 9>"$DATA_ROOT/.operations.lock"
if ! flock -n 9; then
    echo "Another server or maintenance operation is using the data volume." >&2
    exit 1
fi

if [ -f "$BRANCH_MARKER" ] && [ "$(cat "$BRANCH_MARKER")" != "$SERVER_BRANCH" ]; then
    echo "The data volume is marked for branch $(cat "$BRANCH_MARKER"), not $SERVER_BRANCH." >&2
    echo "Do not switch branches in place; follow the documented branch migration procedure." >&2
    exit 1
fi

if [ ! -f "$BRANCH_MARKER" ]; then
    echo "Installing Garry's Mod Dedicated Server app 4020 ($SERVER_BRANCH) into the persistent Docker volume."
    # SteamCMD requires force_install_dir to exist before it is selected.
    mkdir -p "$SERVER_ROOT"
    steamcmd \
        +force_install_dir "$SERVER_ROOT" \
        +login anonymous \
        +app_update 4020 -beta "$SERVER_BRANCH" validate \
        +quit

    if [ ! -x "$SERVER_ROOT/$SERVER_LAUNCHER" ] || [ ! -x "$SERVER_ROOT/$SERVER_BINARY" ] || [ ! -d "$SERVER_ROOT/garrysmod" ]; then
        echo "SteamCMD returned without a complete GMod server install." >&2
        exit 1
    fi

    printf '%s\n' "$SERVER_BRANCH" > "$BRANCH_MARKER.tmp"
    mv "$BRANCH_MARKER.tmp" "$BRANCH_MARKER"
fi

if [ ! -x "$SERVER_ROOT/$SERVER_LAUNCHER" ] || [ ! -x "$SERVER_ROOT/$SERVER_BINARY" ]; then
    echo "GMod server files are missing from $SERVER_ROOT. Run the explicit update workflow." >&2
    exit 1
fi

ADDON_ROOT="$SERVER_ROOT/garrysmod/addons"
ADDON_DEST="$ADDON_ROOT/agent_bridge"
ADDON_BACKUP_ROOT="$DATA_ROOT/addon-backups"
mkdir -p "$ADDON_ROOT"
mkdir -p "$ADDON_BACKUP_ROOT"

# Older entrypoint revisions kept backups inside the active addon scan path.
# Preserve them, but move them out before GMod discovers addons.
for LEGACY_BACKUP in "$ADDON_ROOT"/agent_bridge.previous.*; do
    [ -d "$LEGACY_BACKUP" ] || continue
    LEGACY_NAME=${LEGACY_BACKUP##*/}
    LEGACY_DEST="$ADDON_BACKUP_ROOT/$LEGACY_NAME"
    while [ -e "$LEGACY_DEST" ]; do
        LEGACY_DEST="$ADDON_BACKUP_ROOT/$LEGACY_NAME.$$"
    done
    mv "$LEGACY_BACKUP" "$LEGACY_DEST"
done

ADDON_STAGE=$(mktemp -d "$ADDON_ROOT/.agent_bridge.next.XXXXXX")
cp -a /opt/agent_bridge/. "$ADDON_STAGE/"

ADDON_BACKUP=
if [ -d "$ADDON_DEST" ]; then
    ADDON_BACKUP="$ADDON_BACKUP_ROOT/agent_bridge-$(date -u +%Y%m%dT%H%M%SZ)"
    while [ -e "$ADDON_BACKUP" ]; do
        ADDON_BACKUP="$ADDON_BACKUP_ROOT/agent_bridge-$(date -u +%Y%m%dT%H%M%SZ).$$"
    done
    mv "$ADDON_DEST" "$ADDON_BACKUP"
fi
if ! mv "$ADDON_STAGE" "$ADDON_DEST"; then
    if [ -n "$ADDON_BACKUP" ] && [ -d "$ADDON_BACKUP" ] && [ ! -e "$ADDON_DEST" ]; then
        mv "$ADDON_BACKUP" "$ADDON_DEST"
    fi
    exit 1
fi

install -d "$SERVER_ROOT/garrysmod/lua/bin" "$SERVER_ROOT/garrysmod/lua/autorun/server"
install -m 0444 /opt/gmsv_gterm_linux64.dll "$SERVER_ROOT/garrysmod/lua/bin/gmsv_gterm_linux64.dll"
install -m 0644 /opt/agent_toolkit_gterm.lua "$SERVER_ROOT/garrysmod/lua/autorun/server/agent_toolkit_gterm.lua"
install -m 0644 /opt/server.cfg "$SERVER_ROOT/garrysmod/cfg/server.cfg"

echo "Starting GMod branch=$SERVER_BRANCH launcher=$SERVER_LAUNCHER binary=$SERVER_BINARY map=$SERVER_MAP gamemode=$SERVER_GAMEMODE port=$SERVER_PORT slots=$SERVER_MAXPLAYERS."
cd "$SERVER_ROOT"
exec "./$SERVER_LAUNCHER" \
    -game garrysmod \
    -console \
    -port "$SERVER_PORT" \
    "$@"
