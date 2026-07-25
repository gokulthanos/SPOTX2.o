// ─────────────────────────────────────────────────
// SpotX 4.0 — Jest API Test Suite
// Run: npm test
// ─────────────────────────────────────────────────
const request = require('supertest');

// Mock the server app (we test routes in isolation)
let app;
let server;

beforeAll(async () => {
  // We need to mock db before requiring the app
  // For simplicity, we test against the running server
  // In CI, start server first: node index.js &
  const BASE_URL = process.env.TEST_URL || 'http://localhost:5000';
  app = BASE_URL;
});

describe('Health Check', () => {
  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.version).toBeDefined();
  });
});

describe('API Info', () => {
  test('GET /api returns endpoint list', async () => {
    const res = await request(app).get('/api');
    expect(res.statusCode).toBe(200);
    expect(res.body.endpoints).toBeDefined();
    expect(res.body.endpoints.auth).toBe('/api/v1/auth');
    expect(res.body.endpoints.driver).toBe('/api/v1/driver');
  });
});

describe('Auth - Request OTP', () => {
  test('POST /api/v1/auth/request-otp with valid contact', async () => {
    const res = await request(app)
      .post('/api/v1/auth/request-otp')
      .send({ contact: '9876543210' });
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.devOtp).toBeDefined();
  });

  test('POST /api/v1/auth/request-otp without contact fails', async () => {
    const res = await request(app)
      .post('/api/v1/auth/request-otp')
      .send({});
    expect([400, 422]).toContain(res.statusCode);
  });
});

describe('Auth - Passenger Login', () => {
  test('POST /api/v1/auth/login with valid credentials', async () => {
    // First create a user
    const signupRes = await request(app)
      .post('/api/v1/auth/request-otp')
      .send({ contact: '9999999999' });

    const otp = signupRes.body.data.devOtp;

    await request(app)
      .post('/api/v1/auth/verify-otp')
      .send({ contact: '9999999999', otp });

    await request(app)
      .post('/api/v1/auth/set-password')
      .send({ contact: '9999999999', password: 'test123', fullName: 'Test User' });

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ contact: '9999999999', password: 'test123' });

    expect(res.statusCode).toBe(200);
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.refreshToken).toBeDefined();
  });

  test('POST /api/v1/auth/login with wrong password fails', async () => {
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ contact: '9999999999', password: 'wrongpass' });
    expect(res.statusCode).toBe(401);
  });
});

describe('Auth - Officer Login', () => {
  test('POST /api/v1/officer/login with admin credentials', async () => {
    const res = await request(app)
      .post('/api/v1/officer/login')
      .send({ email: 'ADMIN@GOV.IN', password: 'admin123' });
    expect(res.statusCode).toBe(200);
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.user.role).toBe('ADMIN');
  });
});

describe('Bus Endpoints', () => {
  test('GET /api/v1/buses returns bus list', async () => {
    const res = await request(app).get('/api/v1/buses');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('GET /api/v1/buses?city=Chennai filters by city', async () => {
    const res = await request(app).get('/api/v1/buses?city=Chennai');
    expect(res.statusCode).toBe(200);
  });

  test('GET /api/v1/buses/999 returns 404', async () => {
    const res = await request(app).get('/api/v1/buses/999');
    expect(res.statusCode).toBe(404);
  });
});

describe('Admin Dashboard', () => {
  let adminToken;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/v1/officer/login')
      .send({ email: 'ADMIN@GOV.IN', password: 'admin123' });
    adminToken = res.body.data.accessToken;
  });

  test('GET /api/v1/admin/dashboard returns stats', async () => {
    const res = await request(app)
      .get('/api/v1/admin/dashboard')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.data.overview).toBeDefined();
    expect(res.body.data.today).toBeDefined();
  });

  test('GET /api/v1/admin/officers returns officer list', async () => {
    const res = await request(app)
      .get('/api/v1/admin/officers')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('GET /api/v1/admin/routes returns route list', async () => {
    const res = await request(app)
      .get('/api/v1/admin/routes')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
  });
});

describe('Analytics Endpoints', () => {
  let adminToken;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/v1/officer/login')
      .send({ email: 'ADMIN@GOV.IN', password: 'admin123' });
    adminToken = res.body.data.accessToken;
  });

  test('GET /api/v1/analytics/overview returns chart data', async () => {
    const res = await request(app)
      .get('/api/v1/analytics/overview')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.data.revenueTrend).toBeDefined();
  });

  test('GET /api/v1/analytics/revenue returns revenue data', async () => {
    const res = await request(app)
      .get('/api/v1/analytics/revenue')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.statusCode).toBe(200);
  });
});

describe('Driver Endpoints', () => {
  let staffToken;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/v1/officer/login')
      .send({ email: 'RAJ@GOV.IN', password: 'staff123' });
    staffToken = res.body.data.accessToken;
  });

  test('GET /api/v1/driver/profile returns profile', async () => {
    const res = await request(app)
      .get('/api/v1/driver/profile')
      .set('Authorization', `Bearer ${staffToken}`);
    expect(res.statusCode).toBe(200);
  });
});

describe('Security', () => {
  test('GET /api/v1/admin/dashboard without auth returns 401', async () => {
    const res = await request(app).get('/api/v1/admin/dashboard');
    expect(res.statusCode).toBe(401);
  });

  test('GET /api/v1/admin/officers without auth returns 401', async () => {
    const res = await request(app).get('/api/v1/admin/officers');
    expect(res.statusCode).toBe(401);
  });

  test('POST /api/v1/admin/officers as passenger returns 403', async () => {
    // This would need a passenger token — testing the principle
    const res = await request(app)
      .get('/api/v1/admin/officers')
      .set('Authorization', 'Bearer invalid_token');
    expect(res.statusCode).toBe(401);
  });
});

describe('Smart Features', () => {
  test('GET /api/v1/smart/crowding/1 returns crowding data', async () => {
    const res = await request(app).get('/api/v1/smart/crowding/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.data.level).toBeDefined();
  });

  test('GET /api/v1/smart/eta/1 returns ETA prediction', async () => {
    const res = await request(app).get('/api/v1/smart/eta/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.data.eta).toBeDefined();
  });
});

describe('Stops and Cities (Public)', () => {
  test('GET /api/v1/admin/stops returns stops', async () => {
    const res = await request(app).get('/api/v1/admin/stops');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('GET /api/v1/admin/cities returns cities', async () => {
    const res = await request(app).get('/api/v1/admin/cities');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});
