# Build context expected at the raksha-labs/ root so message-contracts is accessible.

FROM node:20-bookworm-slim AS builder

WORKDIR /build

RUN npm install -g pnpm@9.0.0

COPY raksha-control-plane ./raksha-control-plane
COPY raksha-contracts ./raksha-contracts

WORKDIR /build/raksha-control-plane
RUN pnpm install --frozen-lockfile=false
RUN pnpm --filter @raksha/backend build

FROM node:20-bookworm-slim AS runtime

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy the whole workspace so pnpm's `.pnpm` store + symlinks resolve.
# The backend runs from its own app dir; preserving the workspace layout
# is the simplest way to keep hoisted/symlinked deps intact.
COPY --from=builder /build/raksha-control-plane /app/raksha-control-plane
COPY --from=builder /build/raksha-contracts/protos /proto

EXPOSE 3001 50051

ENV CONFIG_WATCH_PROTO_PATH=/proto/raksha/control/v1/config_watch.proto

WORKDIR /app/raksha-control-plane/apps/backend

CMD ["node", "dist/main.js"]
