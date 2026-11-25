FROM steamcmd/steamcmd:debian-trixie@sha256:17c589df6e146520ec28d1a323d4fbb7eb93faef8aef3573fdd040e0b28157f1

ENV HOME=/home/gmod \
    SERVER_ROOT=/srv/gmod/server \
    GTERM_MODULE_PORT=27514 \
    GTERM_MODULE_TRANSPORT=tcp

RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        lib32gcc-s1 \
        lib32stdc++6 \
        libgcc-s1 \
        libstdc++6 \
        procps \
        tini \
        util-linux \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 10001 gmod \
    && useradd --uid 10001 --gid gmod --create-home --home-dir /home/gmod --shell /usr/sbin/nologin gmod \
    && install -d -o 10001 -g 10001 \
        /srv/gmod \
        /srv/gmod/server \
        /home/gmod/.local/share/Steam/steamapps/downloading \
        /opt/agent_bridge/lua \
    && chown -R 10001:10001 /home/gmod/.local

COPY --chown=10001:10001 addon.json /opt/agent_bridge/addon.json
COPY --chown=10001:10001 lua/ /opt/agent_bridge/lua/
COPY --chown=10001:10001 server/config/server.cfg /opt/server.cfg
COPY --chown=10001:10001 server/bootstrap/agent_toolkit_gterm.lua /opt/agent_toolkit_gterm.lua
COPY --chown=10001:10001 server/scripts/server-entrypoint.sh /usr/local/bin/server-entrypoint
COPY --chown=10001:10001 server/scripts/update-server.sh /usr/local/bin/update-server

RUN chmod 0555 /usr/local/bin/server-entrypoint /usr/local/bin/update-server \
    && curl --fail --location --silent --show-error \
        https://raw.githubusercontent.com/LucasDash/GTerm-Codex/0dcc8f7af7620b3ad0c08b93c243d848e23975ad/prebuilt-bins/gmsv_gterm_linux64.dll \
        --output /opt/gmsv_gterm_linux64.dll \
    && echo 'F14877C93B3C85E540A2E1B6F22144B787366A6CBB1BF202266ACA37F11AF98E  /opt/gmsv_gterm_linux64.dll' | sha256sum --check --status \
    && chmod 0444 /opt/gmsv_gterm_linux64.dll

VOLUME ["/srv/gmod"]
USER 10001:10001
WORKDIR /srv/gmod/server
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/server-entrypoint"]
