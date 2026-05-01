# syntax=docker/dockerfile:1.7
# Build context expected at the raksha-labs/ root.

FROM rust:1.91-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY raksha-notifier-gateway ./raksha-notifier-gateway

WORKDIR /build/raksha-notifier-gateway
RUN --mount=type=cache,id=raksha-notifier-gateway-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=raksha-notifier-gateway-cargo-git,target=/usr/local/cargo/git \
    --mount=type=cache,id=raksha-notifier-gateway-target,target=/build/raksha-notifier-gateway/target \
    cargo build --release --bin raksha-notifier-gateway && \
    mkdir -p /out && \
    cp target/release/raksha-notifier-gateway /out/raksha-notifier-gateway

FROM debian:bookworm-slim AS runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /out/raksha-notifier-gateway /usr/local/bin/raksha-notifier-gateway

WORKDIR /app
EXPOSE 8080

ENTRYPOINT ["raksha-notifier-gateway"]
