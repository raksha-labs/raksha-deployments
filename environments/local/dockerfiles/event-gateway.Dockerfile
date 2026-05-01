# syntax=docker/dockerfile:1.7
# Build context expected at the raksha-labs/ root.

FROM rust:1.91-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY raksha-contracts ./raksha-contracts
COPY raksha-ingestion-gateway     ./raksha-ingestion-gateway

WORKDIR /build/raksha-ingestion-gateway
RUN --mount=type=cache,id=raksha-ingestion-gateway-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=raksha-ingestion-gateway-cargo-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=raksha-ingestion-gateway-target,target=/build/raksha-ingestion-gateway/target \
    cargo build --release --bin raksha-ingestion-gateway && \
    mkdir -p /out && \
    cp target/release/raksha-ingestion-gateway /out/raksha-ingestion-gateway

FROM debian:bookworm-slim AS gateway
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/raksha-ingestion-gateway /usr/local/bin/raksha-ingestion-gateway

WORKDIR /app
EXPOSE 8080 9090

ENTRYPOINT ["raksha-ingestion-gateway"]
