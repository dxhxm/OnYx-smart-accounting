# =============================================================================
# Stage 1: Dependencies (deps)
# Installs only production and build dependencies needed for compilation
# =============================================================================
FROM node:26-alpine AS deps
WORKDIR /app

# Add libc6-compat and openssl for Prisma native engine support on Alpine Linux
RUN apk add --no-cache libc6-compat openssl

COPY package.json package-lock.json ./
COPY prisma ./prisma/

RUN npm ci

# =============================================================================
# Stage 2: Builder
# Compiles Next.js application into the minimal standalone bundle
# =============================================================================
FROM node:26-alpine AS builder
WORKDIR /app

RUN apk add --no-cache libc6-compat openssl

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Generate Prisma client for linux-musl architecture
RUN npx prisma generate

# Build Next.js standalone output
RUN npm run build

# =============================================================================
# Stage 3: Runner (Production runtime)
# Clean, minimal image containing ONLY runtime assets and no build tools
# =============================================================================
FROM node:26-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Install curl for HEALTHCHECK and openssl for Prisma; strip npm/npx to reduce attack surface
RUN apk add --no-cache curl openssl && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx

# Security: Create and run as an unprivileged, non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy static assets and standalone bundle from builder stage
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

# Built-in container health check querying our Phase 1 health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]

