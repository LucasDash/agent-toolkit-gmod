#!/bin/sh
set -eu

DATA_ROOT=/srv/gmod
SERVER_ROOT=${SERVER_ROOT:-/srv/gmod/server}
SERVER_BRANCH=${SERVER_BRANCH:-x86-64}
BRANCH_MARKER="$DATA_ROOT/.server-branch"

case "$SERVER_BRANCH" in
    x86-64|public) ;;
    *) echo "Unsupported SERVER_BRANCH '$SERVER_BRANCH'; use x86-64 or public." >&2; exit 2 ;;
esac

exec 9>"$DATA_ROOT/.operations.lock"
if ! flock -n 9; then
    echo "The server is running or another maintenance operation is active; stop it first." >&2
    exit 1
fi

if [ ! -f "$BRANCH_MARKER" ]; then
    echo "The server has not been initialized. Start it once before running an update." >&2
    exit 1
fi
if [ "$(cat "$BRANCH_MARKER")" != "$SERVER_BRANCH" ]; then
    echo "Data volume branch $(cat "$BRANCH_MARKER") does not match $SERVER_BRANCH." >&2
    echo "Do not switch branches in place; follow the documented branch migration procedure." >&2
    exit 1
fi

mkdir -p "$SERVER_ROOT"
steamcmd \
    +force_install_dir "$SERVER_ROOT" \
    +login anonymous \
    +app_update 4020 -beta "$SERVER_BRANCH" validate \
    +quit

if [ "$SERVER_BRANCH" = "x86-64" ]; then
    SERVER_LAUNCHER=srcds_run_x64
    SERVER_BINARY=bin/linux64/srcds
elif [ -x "$SERVER_ROOT/srcds_run_x64" ] && [ -x "$SERVER_ROOT/bin/linux64/srcds" ]; then
    SERVER_LAUNCHER=srcds_run_x64
    SERVER_BINARY=bin/linux64/srcds
else
    SERVER_LAUNCHER=srcds_run
    SERVER_BINARY=bin/linux32/srcds
fi

if [ ! -x "$SERVER_ROOT/$SERVER_LAUNCHER" ] || [ ! -x "$SERVER_ROOT/$SERVER_BINARY" ] || [ ! -d "$SERVER_ROOT/garrysmod" ]; then
    echo "SteamCMD returned without a complete GMod server install." >&2
    exit 1
fi

echo "GMod server update completed for branch $SERVER_BRANCH."
