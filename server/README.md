# Agent Toolkit GMod server

This Compose deployment runs a Linux Garry's Mod dedicated server with Agent
Bridge. It uses its own Docker volume and does not import an existing GMod
installation. The current setup is a development baseline: one local human
client has connected through the host's LAN address; remote hosting,
multi-client play and recovery on a different host remain unverified.

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

On a Linux Docker host, from the same directory, use Compose directly:

```sh
test -e .env || cp .env.example .env
# Edit .env for this host before starting.
docker compose --env-file .env up -d --build
docker compose --env-file .env ps
docker compose --env-file .env logs --tail 80 gmod
```

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

Clone this repository on a separate Docker host and manage it over SSH. Compose
builds from that host's checkout; the named volume and SteamCMD staging path
are on that host. Keep GTerm loopback-only. An SSH local forward such as
`ssh -L 27516:127.0.0.1:27516 <server-host>` can provide a console transport,
subject to the filesystem limitation above. Linux-host deployment and this
remote connection have not been validated end to end.

Internet players need a reachable UDP game port and suitable host and network
firewall settings. A Steam Game Server Login Token and a safe way to supply it
must also be arranged for public-server operation. Those settings, off-host
backups and recovery have not been implemented by this local baseline. Never
assume a LAN connection proves that the internet path works.
