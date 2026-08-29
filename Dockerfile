FROM debian:12-slim AS build

# RO_PACKETVER is the authoritative default. Coolify never touches this name,
# so it cannot be clobbered to empty. PACKETVER is an optional override for
# plain `docker build --build-arg PACKETVER=...`.
ARG RO_PACKETVER=20180620
ARG PACKETVER=
# Lower this (e.g. 4) if g++ gets OOM-killed on map.cpp / skill.cpp / status.cpp.
ARG BUILD_JOBS=

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make gcc g++ build-essential zlib1g-dev libpcre3-dev \
      libmariadb-dev libmariadb-dev-compat ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/rathena/rathena.git
WORKDIR /opt/rathena

# Coolify passes build args by name only (--build-arg 'PACKETVER'), which
# resolves from the process environment and overrides the compose args: entry
# with an empty string when it finds nothing. So never trust the arg directly —
# fall back to the ARG default above if it arrives empty.
RUN set -eux; \
    PV="${PACKETVER:-}"; \
    [ -n "$PV" ] || PV="${RO_PACKETVER}"; \
    case "$PV" in \
      20[0-9][0-9][0-1][0-9][0-3][0-9]) ;; \
      *) echo "FATAL: PACKETVER='$PV' is not a YYYYMMDD date." >&2; exit 1 ;; \
    esac; \
    echo "Building with PACKETVER=$PV"; \
    sed -i "s|^[[:space:]]*#define PACKETVER .*|#define PACKETVER $PV|" \
      src/config/packets.hpp; \
    grep -qx "#define PACKETVER $PV" src/config/packets.hpp; \
    ./configure --enable-packetver="$PV"; \
    make server -j"${BUILD_JOBS:-$(nproc)}"

# ---------------------------------------------------------------------------

FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      libmariadb3 libpcre3 zlib1g default-mysql-client ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1001 rathena

COPY --from=build --chown=rathena:rathena /opt/rathena /opt/rathena

COPY --chown=rathena:rathena docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /opt/rathena
USER rathena

EXPOSE 6900 6121 5121

# NOT athena-start: it backgrounds every server and returns immediately, so the
# container exits. It also has no foreground mode — the subcommands are
# start|stop|restart|status|watch|help|val_runonce|valchk.
CMD ["/usr/local/bin/docker-entrypoint.sh"]
