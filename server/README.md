# Agent Toolkit GMod server

This Compose deployment runs a Linux Garry's Mod dedicated server with Agent
Bridge. It uses its own Docker volume and does not import an existing GMod
installation. The current setup is a development baseline: one local human
client has connected through the host's LAN address; remote hosting,
multi-client play and recovery on a different host remain unverified.

The default Compose file pulls the published server and GTerm relay images from
GHCR. To use the source checkout instead, pass `-BuildLocal` to the PowerShell
launcher or add `--file compose.dev.yaml` to Linux Compose commands.

## Start and inspect

Install Git and Docker Engine with Compose on an x86-64 host. Docker Desktop on
Windows needs its supported virtualization backend. The first installation
needs internet access and several gigabytes of free storage; allow additional
space for addons and backups. The server container installs app 4020 through
anonymous SteamCMD, so a Steam client is needed only on machines used to play.

Clone this repository, open PowerShell in its `server` directory, and run:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# Set SERVER_BIND_ADDRESS in .env when needed, as described below.
.\Start-Server.ps1
.\Get-ServerStatus.ps1
```

The example `.env` selects the mutable `main` image tag. For a repeatable host,
set `AGENT_TOOLKIT_VERSION` to a published version tag such as `v0.1.0`, or to
an immutable `sha-<commit>` tag. The images are published after commits reach
`main` and when a `v*` tag is pushed. Public pulls work without login once the
GHCR packages are public; otherwise authenticate to GHCR first.

On a Linux Docker host, from the same directory, use Compose directly:

```sh
test -e .env || cp .env.example .env
# Edit .env for this host before starting.
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose --env-file .env ps
docker compose --env-file .env logs --tail 80 gmod
```

For a local source build, use both Compose files so the development overlay is
merged into the base server configuration:

```sh
docker compose --file compose.yaml --file compose.dev.yaml --env-file .env up -d --build
```

The server image contains Agent Bridge and the pinned GTerm module, but not the
dedicated-server installation: SteamCMD downloads app 4020 on first start into
the persistent Docker volume.

The first start downloads app 4020 through anonymous SteamCMD. It can take a
while and needs several gigabytes of free space. Installed server data,
configuration copies and addons live in the named Docker volume
`agent_toolkit_gmod_data`; SteamCMD's temporary depot staging is placed in
`server/.steamcmd-cache` in this checkout by default. That cache is ignored
by Git and can be removed after installation completes.

The default game endpoint is UDP `127.0.0.1:28115`. On this Windows Docker
Desktop host, loopback-only publishing answered server queries but did not
complete a GMod client connection. For local playtesting, set
`SERVER_BIND_ADDRESS` in the ignored `server/.env` to the host's LAN IPv4 and
connect with `connect <host-LAN-IPv4>:28115`. The local `.env` on the development
host should use its current LAN address; update it if DHCP changes that address.
This binds the game port to that LAN interface, making it reachable to devices
on the local network. It does not configure internet access or router forwarding.

The GTerm bridge remains TCP `127.0.0.1:27516`; configure GTerm's `ModulePort`
to `27516` when connecting to this Docker server. Keep the bridge loopback-only.
The server starts with normal Steam authentication (`sv_lan 0`). Cheats and
client Lua are disabled, and the existing Agent Bridge lab policy is enabled.
It starts `gm_construct` in Sandbox with eight slots. No Workshop collection,
GWater, vFire, ULX or other optional addon is mounted.

### Optional Workshop collection playtest

The default server remains collection-free. To launch the Agent Suite
collection with the same map, gamemode, slot count and Steam authentication,
run this from the `server` directory:

```powershell
docker compose --file compose.yaml --file compose.collection.yaml --env-file .env up --detach --force-recreate gmod gterm-relay
```

`SERVER_WORKSHOP_COLLECTION` defaults to `3829225986`. This overlay pins the
server and relay image digests used for the check, caps the server at 4 GB
memory, 6 GB memory-plus-swap and 2 CPUs, and mounts a small local playtest
integration addon and a generated local operator file read-only. Before starting,
copy `.env.example` to `.env` if needed, set
`AGENT_SUITE_OPERATOR_STEAMID64` to the local operator's 17-digit SteamID64
(or `0` for no configured operator), then run
`./Prepare-Collection-Playtest.ps1`. It writes the ignored
`.state/collection/operator_steamid64.txt`; the SteamID is not printed or tracked.
The addon reads it from the server's `DATA` filesystem, avoiding the managed
base `server.cfg`. The
collection contains Dash Reality (3829248229),
ULib (557962238), ULX (557962280), and Veejay NPC Prototype (3845592300). The
2026-11-25 Unlisted-item check fetched and mounted all four. ULX loaded after
ULib as expected; Agent Bridge's optional Dash Reality adapter is server-side.
The overlay bind-mounts [`config/ulx-motd.txt`](config/ulx-motd.txt) and
[`config/ulx-adverts.txt`](config/ulx-adverts.txt) read-only as ULX's MOTD and
advertisement settings. Edit those tracked files and recreate the GMod service
to apply changes; XGUI edits to the mounted files are intentionally unavailable.
The MOTD uses ULX's supported text, list and installed-addon sections. The
advertisement file uses one low-frequency center-screen tip and one slower chat
reminder.

The server collection mounts Veejay's files for the server, but clients also
need the Workshop item. The local integration addon calls
`resource.AddWorkshop("3845592300")` for joining clients. ULib and ULX are
server-content packages and are not sent to clients. The integration also
grants ULX superadmin to the one local operator identified by the generated
local data file after `Player:IsFullyAuthenticated()` succeeds. It listens to
initial spawn and authentication events, with ULib's `UCLAuthed` event as a
second path. It uses the existing UCL user record when available and lets
`ucl.addUser` persist and probe the grant. The protected CVar used by the lab
policy is synchronized from the same file. The addon also checks an
already-connected operator on hot reload.
It does not read host environment variables from GMod Lua. ULib persists grants
in its user database, so when changing or disabling the operator, remove the
old entry with `ulx removeuserid <SteamID>` as well. Use the ULib registered
SteamID (usually `STEAM_0:X:Y`), not the configured SteamID64.
The lab policy keeps its restrictions for other players and permits configured
operators and ULX admins to use Sandbox tools. The local playtest addon
rebinds Agent Bridge's policy hooks after addons load, preserving its
restrictions for other players while honoring ULX admins and the configured
operator. This keeps the collection test compatible with the installed Agent
Bridge revision without changing its Workshop content.

The collection visibility may be Public or Unlisted; Hidden items cannot be
fetched by the anonymous dedicated server. Collection membership and Workshop
item updates are checked on server restart. A successful mount is not proof of
client asset delivery; confirm it with a real client join and model spawn. The
overlay sets `host_workshop_autoupdate 1`, so installed Workshop content is
checked for updates on each server start.

For this local setup, the owner reconnected to `192.168.1.101:28115` after the
post-auth policy correction and confirmed Veejay spawned from the NPC menu on
2026-11-25. This is owner-observed evidence of one client spawn; it does not
verify rendering on other clients, multi-client behavior or other gameplay
systems.

The server image uses the pinned Debian Trixie SteamCMD image so its glibc is
new enough for the pinned GTerm-Codex Linux module. The module is fetched from
the pinned GTerm-Codex commit in the Dockerfile and checked against its SHA-256
before the image builds. Previous Agent Bridge addon revisions are retained
under the data volume's `addon-backups/` directory, outside Garry's Mod's
active addon scan. A small
sidecar relays host port 27516 to the module's container loopback listener on
27514. The separate host port avoids colliding with a local GMod client's
default GTerm module port. GTerm's TCP transport is unauthenticated; never
publish this bridge on a public interface. The relay also listens within the
server's Docker network, so access to that network is part of the trust
boundary. An SSH tunnel can carry the console connection from a remote host;
it does not provide access to files used by GTerm MCP relays. Full remote MCP
operation with a matching game filesystem remains to be designed and tested.
For remote Docker management, use a Docker context over SSH rather than
exposing the Docker API on TCP.

Compose's current health check confirms that the server process exists; it
does not establish that a map is ready or that a player can connect. Verify
the game endpoint and join separately. If the `gmod` container is restarted
alone, recreate the relay afterward so it joins the current network namespace:

```sh
docker compose --env-file .env up -d --force-recreate --no-deps gterm-relay
```

## Stop, update, and back up

```powershell
.\Stop-Server.ps1
.\Update-Server.ps1
.\Backup-Server.ps1
.\Start-Server.ps1
```

`Update-Server.ps1` refuses to update while the game process is running.
SteamCMD updates are explicit; restarting the server does not silently replace
the game build. Updates use `validate`. Backups are written under `backups/`
and require the server to be stopped so the archive is consistent.

The image installs its `server/config/server.cfg` into the volume on **every
server start**. Make persistent non-secret configuration changes in that
source file and rebuild the image; do not rely on edits made inside the volume.
This baseline does not yet provide a secret injection procedure for a Steam
game-server login token. Do not put a token in the tracked config or commits.

`docker compose down` preserves the named volume. **Do not use `docker compose
down --volumes` or `docker volume rm agent_toolkit_gmod_data`** unless you
intend to erase the Docker server's persistent data. The scripts never remove
the volume. Restore is a manual recovery operation; retain a backup before
changing server branches or major configuration.

The default `x86-64` branch matches the previous development server and is
listed by Facepunch as an experimental branch that may not be stable. Docker
makes the deployment repeatable; it cannot make that game branch or arbitrary
addons guaranteed stable. The startup script records the installed branch and
refuses an in-place branch switch. Treat branch changes as a separate
backup-and-migration operation. The image currently installs only the Linux
64-bit GTerm module; the `public` branch and its module architecture have not
been validated in this deployment.

## Remote host workflow

Install Docker Engine and Compose on a separate Linux host, copy this directory
or clone the repository, and set that host's values in `.env`. Compose pulls
the selected GHCR images; the named volume and SteamCMD staging path are on that
host. Keep GTerm loopback-only. An SSH local forward such as
`ssh -L 27516:127.0.0.1:27516 <server-host>` can provide a console transport,
subject to the filesystem limitation above. Linux-host deployment and this
remote connection have not been validated end to end.

Internet players need a reachable UDP game port and suitable host and network
firewall settings. A Steam Game Server Login Token and a safe way to supply it
must also be arranged for public-server operation. Those settings, off-host
backups and recovery have not been implemented by this local baseline. Never
assume a LAN connection proves that the internet path works.
