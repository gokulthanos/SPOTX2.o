# ─────────────────────────────────────────────────
# SpotX 4.0 — Dockerfile (Node.js Backend)
# Multi-stage build for production
# ─────────────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app
COPY server/package*.json ./
RUN npm ci --only=production
COPY server/ ./

FROM node:18-alpine

RUN apk add --no-cache dumb-init

WORKDIR /app
RUN addgroup -g 1001 -S spotx && \
    adduser -S spotx -u 1001 -G spotx

COPY --from=builder /app .

RUN mkdir -p /app/data && chown -R spotx:spotx /app

USER spotx

ENV NODE_ENV=production
ENV PORT=5000

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5000/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "index.js"]
