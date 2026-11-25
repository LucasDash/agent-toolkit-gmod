# Agent Toolkit for Garry's Mod

Agent Toolkit is the game-side and server-side foundation for operating
controlled Garry's Mod sessions through
[GTerm-Codex](https://github.com/LucasDash/GTerm-Codex). It combines the
**Agent Bridge** addon with a reproducible Docker deployment for a dedicated
development server.

Agent Bridge exposes bounded, read-only observations to an explicitly approved
GTerm package. It is not a general-purpose game-control API and does not
execute arbitrary Lua or player commands.

## What is included

| Component | Purpose |
| --- | --- |
| **Agent Bridge addon** | Server and client observations for session status, chat and player activity, entities, fire, map metadata, aim traces, scene inspection, and image capture. Optional providers are checked when requested; they are not hard dependencies. |
| **Docker server deployment** | Compose setup for a Linux Garry's Mod dedicated server and a separate GTerm relay, with persistent game data and SteamCMD-based installation. Prebuilt [server](https://github.com/LucasDash/agent-toolkit-gmod/pkgs/container/agent-toolkit-gmod-server) and [relay](https://github.com/LucasDash/agent-toolkit-gmod/pkgs/container/agent-toolkit-gmod-gterm-relay) images are published to GHCR. |
| **GTerm-Codex integration** | Supplies the operator console, native module, and MCP interface. It is a separate project; its package approval is independent from installing this addon. |

## Observation tools

The `agent_bridge` package exposes separate server and client tools:

- **Server:** `status`, `inspect_server_capabilities`, `read_chat`,
  `read_player_activity`, `inspect_entity`, `inspect_fire`,
  `inspect_map_metadata`, `inspect_dash_entity`, and `inspect_player_aim`.
- **Client:** `inspect_scene`, `inspect_gwater`, `capture_view`,
  `capture_status`, and `capture_stop`.

See the [tool reference](docs/tool-reference.md) for inputs, output limits,
optional-provider behavior, and known caveats.

## Install the addon

Clone the repository into the Garry's Mod `garrysmod/addons` directory, using
`agent_bridge` as the directory name:

```powershell
git clone https://github.com/LucasDash/agent-toolkit-gmod.git C:\path\to\GarrysMod\garrysmod\addons\agent_bridge
```

Restart or refresh the game as appropriate. In GTerm's package prompt, review
and enable `agent_bridge` for the target realm. This repository is distributed
through Git; it does not currently have a Workshop release.

The `agent_bridge_lab_policy` ConVar defaults to disabled in the addon. The
included Docker server configuration enables it for the lab session. When
enabled, it restricts selected Sandbox spawning, tools, and properties, blocks
entering noclip while allowing exit, and can assign a limited loadout. It is a
session policy, not a security boundary against arbitrary third-party addons.

## Run the Docker server

The Compose deployment pulls the published server and relay images by default.
Run these commands from the repository's `server` directory:

```powershell
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
.\Start-Server.ps1
.\Get-ServerStatus.ps1
```

On a Linux host, use Docker Compose directly:

```sh
test -e .env || cp .env.example .env
docker compose --env-file .env pull
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

The example configuration binds the game port to loopback. Set
`SERVER_BIND_ADDRESS` in `.env` for LAN play, and configure the host firewall
separately. The GTerm relay should remain loopback-only. To reproduce an exact
image build, set `AGENT_TOOLKIT_VERSION` to an immutable `sha-<commit>` tag
instead of the moving `main` tag.

To run the optional Agent Suite Workshop collection while retaining the
standard server settings, follow the
[collection playtest instructions](server/README.md#optional-workshop-collection-playtest).

See the [server operations guide](server/README.md) for local source builds,
update and backup procedures, port and host configuration, and deployment
limits. The server image installs the Garry's Mod dedicated-server files into
a persistent Docker volume on first start.

## Trust and current limits

- GTerm package approval controls which declared tools the operator can call.
  Install Agent Bridge only on a server whose observations you are authorized
  to access.
- Chat and player-inspection tools return bounded snapshots, but may include
  player identifiers or aim information. Treat their output as player data.
- Optional integrations such as NikNaks, vFire, gWater2, and Dash Reality are
  guarded providers; their absence does not prevent the base addon from working.
- The published server images target Linux `amd64`. The current deployment is
  a development baseline; remote-host operation, multi-client behavior, and
  recovery on a different host still need validation.
- Docker makes the server setup repeatable; uptime depends on the host,
  persistent-volume backups, and network configuration.

The [status record](STATUS.md) describes checks performed and their remaining
validation boundaries. Agent Bridge is available under the
[MIT License](LICENSE). GTerm-Codex is licensed and maintained separately.
