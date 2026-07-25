// server/routes/admin.routes.js
const router = require('express').Router();
const adminController = require('../controllers/admin.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { validateComplaint } = require('../middleware/validate.middleware');

// ── Government Dashboard (ADMIN + GOV + STAFF read) ──
router.get('/dashboard', authenticate, requireRole('ADMIN', 'GOV'), adminController.getDashboard);
router.get('/reports/revenue', authenticate, requireRole('ADMIN', 'GOV'), adminController.getRevenueReport);

// ── Officer Management (ADMIN only) ──────────────────
router.get('/officers', authenticate, requireRole('ADMIN'), adminController.getOfficers);
router.patch('/officers/:id', authenticate, requireRole('ADMIN'), adminController.updateOfficer);

// ── Route Management ──────────────────────────────────
router.get('/routes', authenticate, adminController.getRoutes);
router.post('/routes', authenticate, requireRole('ADMIN'), adminController.addRoute);
router.put('/routes/:id/fare', authenticate, requireRole('ADMIN'), adminController.updateFare);

// ── Stop Management ───────────────────────────────────
router.get('/stops', adminController.getStops); // public for autocomplete
router.post('/stops', authenticate, requireRole('ADMIN'), adminController.addStop);

// ── City Management ───────────────────────────────────
router.get('/cities', adminController.getCities); // public
router.post('/cities', authenticate, requireRole('ADMIN'), adminController.addCity);

// ── Fines ─────────────────────────────────────────────
router.post('/fines', authenticate, requireRole('STAFF', 'ADMIN'), adminController.issueFine);
router.get('/fines', authenticate, requireRole('STAFF', 'ADMIN'), adminController.getFines);

// ── Complaints ────────────────────────────────────────
// GET: passenger sees own, admin sees all
router.get('/complaints', authenticate, adminController.getComplaints);
// POST: passenger submits
router.post('/complaints', authenticate, validateComplaint, adminController.submitComplaint);
// PATCH: admin updates status
router.patch('/complaints/:id', authenticate, requireRole('ADMIN'), adminController.updateComplaintStatus);

module.exports = router;
