# syntax=docker/dockerfile:1.7
#
# Consolidated build for the three Node.js services that live in the
# raksha-portal pnpm workspace: @raksha/backend, @raksha/portal, @raksha/admin.
#
# Structure:
#   deps         → `pnpm install` ONCE for the whole workspace (cached).
#   *-build      → extend deps, run `pnpm --filter @raksha/X build`.
#   *            → slim runtime image per service.
#
# Why consolidated: three separate Dockerfiles each ran `pnpm install` in a
# fresh container, downloading 520+ packages × 3 = Docker Desktop OOM when
# built in parallel. BuildKit deduplicates shared stages across parallel
# targets, so the install now happens once no matter how many services build.
#
# The pnpm-store cache mount keeps the download warm across rebuilds.
#
# Build context expected at the raksha-labs/ workspace root so both
# raksha-portal and raksha-contracts are visible.

# ───────────────────────── shared dep-install stage ─────────────────────────

FROM node:20-bookworm-slim AS deps

ARG NPM_REGISTRY=https://registry.npmjs.org
WORKDIR /build
RUN npm install -g pnpm@9.0.0 --registry ${NPM_REGISTRY}

# Contracts are consumed by @raksha/backend at build time (ContractsModule
# resolves OpenAPI YAMLs) and by @raksha/contracts codegen. Copying both
# trees here means downstream stages don't re-do it.
COPY raksha-portal ./raksha-portal
COPY raksha-contracts ./raksha-contracts

WORKDIR /build/raksha-portal
RUN --mount=type=cache,id=pnpm-store,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile=false --registry ${NPM_REGISTRY}

# Compile @raksha/contracts once in the shared deps stage. The package now
# publishes dist/*.js via package.json `exports`, so every downstream app
# (backend at runtime, Next.js during build) resolves through it.
RUN pnpm --filter @raksha/contracts build

# ───────────────────────────── backend (NestJS) ─────────────────────────────

FROM deps AS backend-build
RUN pnpm --filter @raksha/backend build

FROM node:20-bookworm-slim AS backend

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Preserve the pnpm workspace layout so hoisted/symlinked deps resolve.
COPY --from=backend-build /build/raksha-portal /app/raksha-portal
COPY --from=backend-build /build/raksha-contracts/openapi /app/raksha-contracts/openapi

EXPOSE 3001

ENV CONTRACTS_DIR=/app/raksha-contracts

WORKDIR /app/raksha-portal/apps/backend
# tsc auto-computes rootDir to the workspace root because the backend
# imports @raksha/contracts via path alias, so the emit lands nested under
# dist/apps/backend/src/ rather than dist/.
CMD ["node", "dist/apps/backend/src/main.js"]

# ──────────────────────────── portal (Next.js) ──────────────────────────────

FROM deps AS portal-build
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:3001
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}
RUN pnpm --filter @raksha/portal build

FROM node:20-bookworm-slim AS portal

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=portal-build /build/raksha-portal /app/raksha-portal

EXPOSE 3000
ENV PORT=3000
WORKDIR /app/raksha-portal/apps/portal
CMD ["sh", "-c", "cd /app/raksha-portal/apps/portal && npx next start -p 3000"]

# ────────────────────────────── admin (Next.js) ─────────────────────────────

FROM deps AS admin-build
ARG NEXT_PUBLIC_API_BASE_URL=http://localhost:3001
ENV NEXT_PUBLIC_API_BASE_URL=${NEXT_PUBLIC_API_BASE_URL}
RUN pnpm --filter @raksha/admin build

FROM node:20-bookworm-slim AS admin

WORKDIR /app
ENV NODE_ENV=production

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=admin-build /build/raksha-portal /app/raksha-portal

EXPOSE 3002
ENV PORT=3002
WORKDIR /app/raksha-portal/apps/admin
CMD ["sh", "-c", "cd /app/raksha-portal/apps/admin && npx next start -p 3002"]
