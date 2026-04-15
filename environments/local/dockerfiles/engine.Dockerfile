# Build context expected at the raksha-labs/ root so the Cargo
# `path = "../raksha-contracts"` dependency resolves.

FROM rust:1.91-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates protobuf-compiler && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy everything needed to compile — workspace-local deps + this crate.
COPY raksha-contracts ./raksha-contracts
COPY raksha-engine           ./raksha-engine

WORKDIR /build/raksha-engine
RUN cargo build --release --bin raksha-engine

FROM debian:bookworm-slim AS runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates libssl3 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/raksha-engine/target/release/raksha-engine /usr/local/bin/raksha-engine

WORKDIR /app
EXPOSE 9090

ENTRYPOINT ["raksha-engine"]
CMD ["/app/config.toml"]
