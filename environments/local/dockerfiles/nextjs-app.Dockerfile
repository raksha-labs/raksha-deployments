# Shared Dockerfile for raksha-portal/apps/portal and apps/admin.
# The target app is selected at build time via the APP_NAME build arg.
#
# Both apps are Next.js 14 with pnpm workspace deps on @raksha/ui,
# @raksha/api-client, @raksha/domain-types — so we copy the whole
# control-plane workspace.
#
# NEXT_PUBLIC_API_BASE_URL is baked in at build time because Next.js
# substitutes it into the client bundle during `next build`. The default
# points at the host port mapping of the backend container.

FROM node:20-bookworm-slim AS builder

ARG APP_NAME=portal
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:3001

WORKDIR /build

RUN npm install -g pnpm@9.0.0

COPY raksha-portal ./raksha-portal

WORKDIR /build/raksha-portal
RUN pnpm install --frozen-lockfile=false

ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}
RUN pnpm --filter @raksha/${APP_NAME} build

FROM node:20-bookworm-slim AS runtime

ARG APP_NAME=portal
ARG APP_PORT=3000
ENV APP_NAME=${APP_NAME}
ENV APP_PORT=${APP_PORT}

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Same workspace-preservation strategy as the backend image — pnpm's
# symlinked store lives in the workspace root, so we keep the tree intact.
COPY --from=builder /build/raksha-portal /app/raksha-portal

EXPOSE ${APP_PORT}

WORKDIR /app/raksha-portal/apps/${APP_NAME}

# `next start -p ${PORT}` reads the PORT env at runtime.
ENV PORT=${APP_PORT}
CMD ["sh", "-c", "cd /app/raksha-portal/apps/${APP_NAME} && npx next start -p ${APP_PORT}"]
