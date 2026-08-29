FROM debian:12-slim AS build
ARG PACKETVER=20180620
# Lower this (e.g. 4) if g++ gets OOM-killed on map.cpp / skill.cpp / status.cpp.
ARG BUILD_JOBS=

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make gcc g++ build-essential zlib1g-dev libpcre3-dev \
      libmariadb-dev libmariadb-dev-compat ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/rathena/rathena.git
WORKDIR /opt/rathena

# PACKETVER must be a YYYYMMDD date. If it arrives empty (a common Coolify
# mistake — the variable must be marked as a BUILD variable, not runtime only)
# the sed below would write a bare "#define PACKETVER" and every
# "#if PACKETVER >= ..." in the codebase becomes a preprocessor error, ~10
# minutes into the build. Fail in two seconds instead.
RUN set -eux; \
    case "${PACKETVER}" in \
      20[0-9][0-9][0-1][0-9][0-3][0-9]) ;; \
      *) echo "FATAL: PACKETVER='${PACKETVER}' is not a YYYYMMDD date." >&2; \
         echo "In Coolify, edit the PACKETVER env var and enable 'Build Variable'." >&2; \
         exit 1 ;; \
    esac; \
    sed -i "s|^[[:space:]]*#define PACKETVER .*|#define PACKETVER ${PACKETVER}|" \
      src/config/packets.hpp; \
    grep -qx "#define PACKETVER ${PACKETVER}" src/config/packets.hpp; \
    ./configure --enable-packetver="${PACKETVER}"; \
    make server -j"${BUILD_JOBS:-$(nproc)}"

# ---------------------------------------------------------------------------

FROM debian:12-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      libmariadb3 libpcre3 zlib1g default-mysql-client ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1001 rathena

COPY --from=build --chown=rathena:rathena /opt/rathena /opt/rathena

WORKDIR /opt/rathena
USER rathena

EXPOSE 6900 6121 5121

# restart-fg keeps the servers in the foreground so Docker does not exit.
CMD ["./athena-start", "restart-fg"]
