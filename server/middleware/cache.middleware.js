// server/middleware/cache.middleware.js
// ─────────────────────────────────────────────────
// Performance: HTTP caching headers + in-memory cache
// ─────────────────────────────────────────────────
const logger = require('../utils/logger');

// In-memory response cache (LRU-style with TTL)
const cache = new Map();
const DEFAULT_TTL = 60 * 1000; // 60 seconds
const MAX_ENTRIES = 500;

function getCacheKey(req) {
  return `${req.method}:${req.originalUrl}`;
}

function getCached(key) {
  const entry = cache.get(key);
  if (!entry) return null;
  if (Date.now() > entry.expiry) {
    cache.delete(key);
    return null;
  }
  return entry.data;
}

function setCache(key, data, ttl = DEFAULT_TTL) {
  if (cache.size >= MAX_ENTRIES) {
    // Evict oldest entry
    const oldestKey = cache.keys().next().value;
    cache.delete(oldestKey);
  }
  cache.set(key, { data, expiry: Date.now() + ttl });
}

function clearCache(pattern) {
  if (!pattern) {
    cache.clear();
    return;
  }
  for (const key of cache.keys()) {
    if (key.includes(pattern)) cache.delete(key);
  }
}

// ── Middleware: Set cache-control headers ─────────
function cacheControl(ttl = 60) {
  return (req, res, next) => {
    // Don't cache authenticated or mutating requests
    if (req.method !== 'GET' || req.headers.authorization) {
      res.setHeader('Cache-Control', 'no-store');
      return next();
    }
    res.setHeader('Cache-Control', `public, max-age=${ttl}`);
    res.setHeader('X-Cache', 'MISS');
    next();
  };
}

// ── Middleware: Full response cache (in-memory) ───
function responseCache(ttl = DEFAULT_TTL) {
  return (req, res, next) => {
    // Only cache GET requests without auth
    if (req.method !== 'GET' || req.headers.authorization) {
      return next();
    }

    const key = getCacheKey(req);
    const cached = getCached(key);

    if (cached) {
      res.setHeader('X-Cache', 'HIT');
      return res.status(200).json(cached);
    }

    // Intercept res.json to cache the response
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      if (res.statusCode === 200) {
        setCache(key, body, ttl);
      }
      res.setHeader('X-Cache', 'MISS');
      return originalJson(body);
    };

    next();
  };
}

// ── ETag support ─────────────────────────────────
function etagSupport() {
  return (req, res, next) => {
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      const data = JSON.stringify(body);
      // Simple hash for ETag
      let hash = 0;
      for (let i = 0; i < data.length; i++) {
        hash = ((hash << 5) - hash + data.charCodeAt(i)) | 0;
      }
      const etag = `"${Math.abs(hash).toString(36)}"`;
      res.setHeader('ETag', etag);

      if (req.headers['if-none-match'] === etag) {
        return res.status(304).end();
      }
      return originalJson(body);
    };
    next();
  };
}

module.exports = {
  cacheControl,
  responseCache,
  etagSupport,
  clearCache,
  cache,
};
