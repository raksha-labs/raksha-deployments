# Build context expected at the raksha-labs/ root.

FROM rust:1.91-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY raksha-message-contracts ./raksha-message-contracts
COPY raksha-event-gateway     ./raksha-event-gateway

WORKDIR /build/raksha-event-gateway
RUN cargo build --release --bin raksha-event-gateway

FROM debian:bookworm-slim AS runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/raksha-event-gateway/target/release/raksha-event-gateway /usr/local/bin/raksha-event-gateway

WORKDIR /app
EXPOSE 8080 9090

ENTRYPOINT ["raksha-event-gateway"]
CMD ["/app/config.toml"]
