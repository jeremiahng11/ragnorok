FROM debian:12-slim AS build
ARG PACKETVER=20180620

RUN apt-get update && apt-get install -y --no-install-recommends \
      git make gcc g++ build-essential zlib1g-dev libpcre3-dev \
      libmariadb-dev libmariadb-dev-compat ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git clone --depth 1 https://github.com/rathena/rathena.git
WORKDIR /opt/rathena

RUN sed -i "s|^[[:space:]]*#define PACKETVER .*|#define PACKETVER ${PACKETVER}|" \
      src/config/packets.hpp \
 && ./configure --enable-packetver=${PACKETVER} \
 && make server -j"$(nproc)"

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
