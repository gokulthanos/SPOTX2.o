# SpotX 4.0 — Smart Transit & Digital Ticketing Platform

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green?logo=node.js)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-4.x-black?logo=express)](https://expressjs.com)
[![SQLite](https://img.shields.io/badge/SQLite-Production%20Ready-blue?logo=sqlite)](https://sqlite.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **SpotX 4.0** is a production-ready Smart Transit Platform for Tamil Nadu state bus operations. It digitizes the full passenger journey: OTP login → bus discovery → seat booking → QR ticket → live GPS tracking → government officer verification — all in one unified system.

---

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Quick Start](#-quick-start)
  - [Backend Setup](#backend-setup)
  - [Flutter Setup](#flutter-setup)
  - [Firebase Setup](#firebase-setup-push-notifications)
- [Environment Variables](#-environment-variables)
- [API Reference](#-api-reference)
- [Security](#-security)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [Contributing](#-contributing)

---

## ✨ Features

### Passenger App
| Feature | Description |
|---|---|
| 🔐 OTP Login | Mobile number + OTP authentication with SMS delivery |
| 📍 GPS City Detection | Auto-detect user city via device GPS |
| 🔍 Bus Search | Stop-to-stop search with recent & favourite routes |
| 🎟️ QR Ticket Booking | Multi-passenger booking with dynamic fare calculation |
| 💰 Digital Wallet | Top-up via Razorpay (UPI, Cards, NetBanking) |
| 🗺️ Live Bus Tracking | Real-time GPS map + stop timeline |
| 🔔 Push Notifications | FCM alerts for delays, boarding reminders |
| 📄 PDF Tickets | Print-ready ticket generation |
| 📶 Offline Support | Tickets cached locally via Hive for offline access |

### Government Officer App
| Feature | Description |
|---|---|
| 🏛️ Officer Dashboard | Stats, live scans, fine management |
| 📷 QR Verification | Scan passenger QR to validate tickets |
| ⚠️ Fine Module | Issue and track passenger fines |
| 👥 Admin Panel | Manage staff accounts |
| 📊 Analytics | Revenue, occupancy, and route analytics |

### Bus Driver App
| Feature | Description |
|---|---|
| 📡 GPS Location Updates | Real-time bus position broadcasting |
| 🛑 Stop Check-In | Confirm arrival/departure at each stop |
| 📋 Passenger Manifest | View booked passengers for the journey |

---

## 🏗️ Architecture

```
SpotX 4.0
├── lib/                          ← Flutter Frontend (Clean Architecture)
│   ├── core/                     ← App config, theme tokens
│   ├── models/                   ← Data models
│   ├── providers/                ← State management (Provider)
│   ├── screens/                  ← UI screens by role
│   │   ├── auth/                 ← Landing (3-tab), OTP, login flows
│   │   ├── passenger/            ← Bus search, booking, wallet, tracking
│   │   ├── officer/              ← Dashboard, QR scanner, fines
│   │   ├── driver/               ← Driver dashboard, trip controls
│   │   ├── admin/                ← Admin panel, analytics dashboard
│   │   └── kiosk/                ← Kiosk mode
│   ├── services/                 ← API, storage, notifications, realtime
│   │   ├── api_service.dart      ← 30+ API methods
│   │   ├── realtime_service.dart ← Socket.IO client
│   │   ├── offline_sync_service.dart ← Offline queue + sync
│   │   ├── ticket_printer_service.dart ← PDF thermal tickets
│   │   └── storage_service.dart  ← Hive + SecureStorage
│   └── firebase_options.dart     ← Firebase configuration
│
└── server/                       ← Node.js Backend (MVC)
    ├── config/                   ← env.js (centralized config)
    ├── controllers/              ← HTTP handlers (auth, bus, ticket, payment, admin, driver, analytics)
    ├── middleware/               ← Auth, security, validation, cache, rate-limiter
    ├── routes/                   ← Express routes (8 routers)
    ├── services/                 ← Business logic (auth, payment, FCM, SMS, realtime)
    ├── __tests__/                ← Jest API test suite (23 tests)
    ├── utils/                    ← Logger, response helpers
    ├── db.js                     ← SQLite database (14 tables)
    ├── seed-demo.js              ← Demo data seeder (110 buses, 550 tickets)
    └── database/                 ← PostgreSQL schemas (future migration)
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.x, Dart |
| **State Management** | Provider |
| **Local Storage** | Hive + FlutterSecureStorage |
| **Maps** | Google Maps Flutter |
| **Payments** | Razorpay SDK |
| **Push Notifications** | Firebase Cloud Messaging (FCM) |
| **Real-time** | Socket.IO (WebSockets) |
| **Backend** | Node.js 18+, Express.js 4 |
| **Database** | SQLite (sql.js for in-memory) |
| **Auth** | JWT (access) + Refresh Token rotation |
| **Security** | Helmet, CORS, Rate Limiting, Bcrypt, Input Sanitization |
| **SMS** | MSG91 / Fast2SMS / Twilio (configurable) |

---

## 🚀 Quick Start

### Prerequisites

- [Node.js 18+](https://nodejs.org/en/download/)
- [Flutter 3.x](https://docs.flutter.dev/get-started/install)
- [Android Studio](https://developer.android.com/studio) (for Android development)
- Git

---

### Backend Setup

```bash
# 1. Navigate to server directory
cd server

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your actual values (see Environment Variables section)

# 4. Start in development mode
npm run dev

# 5. (Optional) Seed with demo data
npm run demo
```

The server will start at `http://localhost:5000`

**Health Check:** `GET http://localhost:5000/health`

**Default Credentials:**
| Role | Email | Password |
|---|---|---|
| Admin | ADMIN@GOV.IN | admin123 |
| Staff | RAJ@GOV.IN | staff123 |

---

### Flutter Setup

```bash
# 1. Get dependencies
flutter pub get

# 2. Generate Hive adapters (if needed)
flutter pub run build_runner build --delete-conflicting-outputs

# 3. Run on emulator/device
# Development (default: connects to 10.0.2.2:5000)
flutter run

# Custom backend URL
flutter run --dart-define=API_URL=http://YOUR_IP:5000/api/v1 \
            --dart-define=WS_URL=ws://YOUR_IP:5000
```

---

### Firebase Setup (Push Notifications)

> **Skip this step** if you don't need push notifications. The app works fully without Firebase.

#### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create project → **"SpotX"**
3. Add Android app → Package name: `com.example.spotx_ride_app`
4. Download `google-services.json` → place at `android/app/google-services.json`

#### Step 2: Configure Flutter
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Auto-generate firebase_options.dart
flutterfire configure
```

This auto-populates `lib/firebase_options.dart` with your real credentials.

#### Step 3: Configure Backend FCM
```bash
# In Firebase Console → Project Settings → Service Accounts
# Click "Generate new private key" → download JSON

# In server/.env:
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"...","private_key":"..."}
```

---

## 🔑 Environment Variables

All server secrets live in `server/.env`. **Never commit this file.**

```env
# ── Server ──────────────────────────────────────────────
NODE_ENV=production          # 'development' | 'production'
PORT=5000                    # HTTP server port

# ── JWT Authentication ──────────────────────────────────
JWT_SECRET=min-32-char-secret-here
JWT_REFRESH_SECRET=another-min-32-char-secret
JWT_EXPIRES_IN=15m           # Access token lifetime
JWT_REFRESH_EXPIRES_IN=7d    # Refresh token lifetime

# ── CORS ────────────────────────────────────────────────
CORS_ORIGIN=http://localhost:3000,http://your-app-domain.com

# ── Razorpay Payments ───────────────────────────────────
# Test:  RAZORPAY_KEY_ID=rzp_test_xxxxx  (no real money)
# Live:  RAZORPAY_KEY_ID=rzp_live_xxxxx  (real transactions)
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxx

# ── SMS Provider ────────────────────────────────────────
# Options: CONSOLE (dev), MSG91, FAST2SMS, TWILIO
SMS_PROVIDER=CONSOLE
MSG91_AUTH_KEY=
MSG91_TEMPLATE_ID=
FAST2SMS_API_KEY=
TWILIO_SID=
TWILIO_AUTH=
TWILIO_FROM=

# ── Firebase Cloud Messaging ────────────────────────────
# Paste your google service account JSON as a single-line string:
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"..."}

# ── Rate Limiting ────────────────────────────────────────
OTP_MAX_REQUESTS=3           # Max OTP requests per window
OTP_WINDOW_MINUTES=10        # Rate limit window

# ── Database ─────────────────────────────────────────────
DB_PATH=./spotx.db           # SQLite database file path
```

### Flutter dart-define Variables

Configure these at build/run time:

```bash
flutter run \
  --dart-define=API_URL=http://your-backend.com/api/v1 \
  --dart-define=WS_URL=ws://your-backend.com
```

---

## 📡 API Reference

**Base URL:** `http://localhost:5000/api/v1`

### Authentication

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/auth/request-otp` | None | Request OTP (sent via SMS) |
| POST | `/auth/verify-otp` | None | Verify OTP |
| POST | `/auth/set-password` | None | Set password after OTP |
| POST | `/auth/login` | None | Passenger login |
| POST | `/auth/refresh` | None | Refresh access token |
| POST | `/auth/logout` | Bearer | Logout (revokes refresh token) |
| POST | `/auth/officer/login` | None | Officer login (email + password) |
| POST | `/auth/officer/register` | Bearer+ADMIN | Register new staff |

### Buses

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/buses` | None | List all buses (with filters: city, from, to) |
| GET | `/buses/:id` | None | Get bus by ID |
| GET | `/buses/search` | None | Stop-to-stop bus search |
| GET | `/buses/:id/tracking` | None | Live tracking data |

### Tickets

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/tickets` | Bearer | Book a ticket |
| GET | `/tickets/:ticketNumber` | None | Get ticket by number |
| POST | `/tickets/verify` | Bearer+STAFF | Officer verifies ticket QR |

### Payments

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/payments/initiate` | Bearer | Create Razorpay order |
| POST | `/payments/verify` | Bearer | Verify payment signature |
| GET | `/payments/wallet` | Bearer | Get wallet balance + history |
| GET | `/payments/history` | Bearer | Get payment history |

### Driver (NEW in 4.0)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/driver/login` | None | Driver login (employeeId + password) |
| GET | `/driver/profile` | Bearer+STAFF | Get driver profile |
| GET | `/driver/my-bus` | Bearer+STAFF | Get assigned bus info |
| PUT | `/driver/trip/start` | Bearer+STAFF | Start trip |
| PUT | `/driver/trip/pause` | Bearer+STAFF | Pause trip |
| PUT | `/driver/trip/resume` | Bearer+STAFF | Resume trip |
| PUT | `/driver/trip/end` | Bearer+STAFF | End trip |
| PUT | `/driver/location` | Bearer+STAFF | Share GPS location |
| PUT | `/driver/delay` | Bearer+STAFF | Report delay |
| POST | `/driver/emergency` | Bearer+STAFF | Trigger emergency alert |
| GET | `/driver/stats` | Bearer+STAFF | Get driver statistics |

### Analytics (NEW in 4.0)

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/analytics/overview` | Bearer+ADMIN | Revenue trend, top routes, chart data |
| GET | `/analytics/revenue` | Bearer+ADMIN | Revenue breakdown |
| GET | `/analytics/occupancy` | Bearer+ADMIN | Occupancy heatmap data |

### Smart Features

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/smart/crowding/:busId` | None | Real-time crowding level (low/medium/high/full) |
| GET | `/smart/eta/:busId` | None | ETA prediction per stop |
| GET | `/smart/alerts` | None | Active service alerts |
| GET | `/smart/recommendations/:city` | None | Personalized route recommendations |

### Admin

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| GET | `/admin/dashboard` | Bearer+ADMIN | Full dashboard stats |
| GET | `/admin/officers` | Bearer+ADMIN | List all officers |
| GET | `/admin/passengers` | Bearer+ADMIN | List all passengers |
| GET | `/admin/audit-log` | Bearer+ADMIN | View audit trail |
| POST | `/admin/officers` | Bearer+ADMIN | Register new officer |
| POST | `/admin/fines` | Bearer+STAFF | Issue a fine |
| GET | `/admin/stops` | None | List all stops (public) |
| GET | `/admin/cities` | None | List all cities (public) |
| GET | `/admin/routes` | Bearer+ADMIN | List all routes |
| POST | `/admin/complaints` | Bearer | Submit complaint |

### WebSocket Events (NEW in 4.0)

| Event | Direction | Description |
|---|---|---|
| `bus:join` | Client→Server | Join bus tracking room |
| `bus:leave` | Client→Server | Leave bus tracking room |
| `bus:update-location` | Driver→Server | Broadcast GPS position |
| `bus:update-status` | Driver→Server | Update trip status |
| `driver:register` | Driver→Server | Register driver connection |
| `bus:location-update` | Server→Clients | Real-time location broadcast |

---

## 🔒 Security

SpotX 4.0 implements defense-in-depth security:

| Layer | Mechanism |
|---|---|
| **Authentication** | JWT access tokens (15m) + refresh token rotation (7d) |
| **Password Storage** | bcrypt (cost factor 12) |
| **Transport** | HTTPS enforced in production, HSTS headers |
| **Input Validation** | express-validator on all endpoints |
| **SQL Injection** | Parameterized queries + pattern detection |
| **XSS Prevention** | Input sanitization + helmet CSP |
| **Rate Limiting** | OTP (3/10min), Login (5/15min) per IP |
| **Brute Force** | Auto-block after 10 failed attempts (15min) |
| **Audit Trail** | All write operations logged to `audit_log` table |
| **CORS** | Allowlist-only, credentials mode |
| **Payload Size** | 1MB request limit enforced |

### Security Checklist for Production

- [ ] Change all default JWT secrets in `.env`
- [ ] Set `NODE_ENV=production`
- [ ] Use HTTPS/TLS termination (Nginx, Railway, Render)
- [ ] Set `CORS_ORIGIN` to your actual domain
- [ ] Switch Razorpay to live keys: `rzp_live_*`
- [ ] Configure real SMS provider (MSG91 recommended for India)
- [ ] Set up Firebase for push notifications
- [ ] Enable database backups
- [ ] Set up monitoring (Uptime Robot, Sentry)

---

## 🚢 Deployment

### Railway (Recommended)

```bash
# Install Railway CLI
npm install -g @railway/cli
railway login

# From project root
railway init
railway up
```

Set environment variables in Railway dashboard.

### Render

1. Connect your GitHub repository
2. Set **Build Command:** `cd server && npm install`
3. Set **Start Command:** `cd server && node index.js`
4. Add all environment variables from the table above

### Docker

```bash
# Build
docker build -t spotx-server ./server

# Run
docker run -p 5000:5000 \
  -e NODE_ENV=production \
  -e JWT_SECRET=your-secret \
  -e RAZORPAY_KEY_ID=rzp_live_xxx \
  spotx-server
```

### Android App Release

```bash
# Build release APK
flutter build apk --release \
  --dart-define=API_URL=https://your-backend.com/api/v1 \
  --dart-define=WS_URL=wss://your-backend.com

# Or build App Bundle for Play Store
flutter build appbundle --release \
  --dart-define=API_URL=https://your-backend.com/api/v1
```

---

## 🧪 Testing

### Backend Tests

```bash
cd server

# Run all tests
npm test

# Run with coverage report
npm run test:coverage
```

### Flutter Tests

```bash
# Unit + widget tests
flutter test

# Run specific test file
flutter test test/widget_test.dart
```

### Manual API Testing

Use the provided Postman collection or test with curl:

```bash
# Health check
curl http://localhost:5000/health

# Request OTP (dev mode returns devOtp)
curl -X POST http://localhost:5000/api/v1/auth/request-otp \
  -H "Content-Type: application/json" \
  -d '{"contact": "9999999999"}'

# Officer login
curl -X POST http://localhost:5000/api/v1/auth/officer/login \
  -H "Content-Type: application/json" \
  -d '{"email": "ADMIN@GOV.IN", "password": "admin123"}'
```

---

## 📁 Project Structure

```
SPOTX2.o/
├── lib/                          # Flutter app source
│   ├── core/
│   │   ├── app_config.dart       # API URL, WS URL config
│   │   └── app_theme.dart        # Material 3 theme
│   ├── firebase_options.dart     # Firebase credentials (configure this!)
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   ├── providers/
│   │   ├── auth_provider.dart    # Auth state + FCM sync
│   │   └── wallet_provider.dart  # Wallet state
│   ├── screens/
│   │   ├── auth/                 # Login, OTP, 3-tab landing
│   │   ├── passenger/            # Booking, wallet, tracking
│   │   ├── officer/              # Dashboard, QR scanner, fines
│   │   ├── driver/               # Driver dashboard (trip controls)
│   │   ├── admin/                # Admin panel, analytics dashboard
│   │   └── kiosk/                # Kiosk mode
│   └── services/
│       ├── api_service.dart      # HTTP + JWT refresh (30+ methods)
│       ├── notification_service.dart  # FCM push notifications
│       ├── realtime_service.dart # Socket.IO real-time tracking
│       ├── offline_sync_service.dart  # Offline queue + sync
│       ├── ticket_printer_service.dart # PDF thermal ticket generation
│       └── storage_service.dart  # Hive + SecureStorage
│
├── server/                       # Node.js backend
│   ├── config/env.js             # Centralized env config
│   ├── controllers/              # HTTP handlers
│   │   ├── auth.controller.js    # OTP, JWT, passenger/officer auth
│   │   ├── bus.controller.js     # Bus CRUD + search
│   │   ├── ticket.controller.js  # Booking + verification
│   │   ├── payment.controller.js # Razorpay + wallet
│   │   ├── admin.controller.js   # Dashboard, officers, fines
│   │   ├── driver.controller.js  # Driver app endpoints
│   │   └── analytics.controller.js # Chart/analytics data
│   ├── middleware/               # Security & validation
│   │   ├── auth.middleware.js     # JWT verify + role check
│   │   ├── validate.middleware.js # express-validator chains
│   │   ├── rateLimiter.js        # OTP & login rate limits
│   │   ├── security.middleware.js # SQL injection, audit, brute force
│   │   ├── cache.middleware.js    # HTTP cache + ETag support
│   │   └── error.middleware.js   # Global error handler
│   ├── routes/                   # Express routes
│   │   ├── auth.routes.js        # Passenger + Officer auth
│   │   ├── bus.routes.js         # Bus endpoints
│   │   ├── ticket.routes.js      # Ticket endpoints
│   │   ├── payment.routes.js     # Payment endpoints
│   │   ├── admin.routes.js       # Admin endpoints
│   │   ├── driver.routes.js      # Driver endpoints
│   │   ├── analytics.routes.js   # Analytics endpoints
│   │   └── smart.routes.js       # Smart features (crowding, ETA)
│   ├── services/
│   │   ├── auth.service.js       # OTP, JWT, bcrypt
│   │   ├── payment.service.js    # Razorpay orders + verification
│   │   ├── realtime.service.js   # Socket.IO real-time tracking
│   │   ├── sms.service.js        # Multi-provider SMS
│   │   └── fcm.service.js        # Firebase Admin push
│   ├── __tests__/
│   │   └── api.test.js           # Jest API test suite (23 tests)
│   ├── utils/
│   │   ├── logger.js             # Winston logger
│   │   └── response.js           # Standardized API responses
│   ├── db.js                     # SQLite schema + queries (14 tables)
│   ├── index.js                  # Server entry point
│   ├── seed-demo.js              # Demo data seeder (110 buses)
│   ├── .env.example              # Environment template
│   └── package.json
│
├── database/                     # Production DB schemas
│   ├── postgresql-schema.sql     # Full PostgreSQL schema
│   └── schema.prisma             # Prisma ORM schema
│
├── Dockerfile                    # Multi-stage Docker build
├── .dockerignore                 # Docker ignore rules
├── railway.toml                  # Railway deployment config
├── render.yaml                   # Render deployment config
├── android/                      # Android platform files
├── ios/                          # iOS platform files
├── assets/                       # Images, fonts
├── pubspec.yaml                  # Flutter dependencies (v4.0)
└── README.md                     # This file
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Follow the existing code style and patterns
4. Add tests for new functionality
5. Commit your changes: `git commit -m 'feat: add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

Built with ❤️ for Tamil Nadu public transport digitization.

- [Flutter](https://flutter.dev) — Beautiful multi-platform apps
- [Firebase](https://firebase.google.com) — Real-time infrastructure
- [Razorpay](https://razorpay.com) — Payment gateway
- [Socket.IO](https://socket.io) — Real-time WebSockets
