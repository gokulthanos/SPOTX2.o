// server/routes/ticket.routes.js
const router = require('express').Router();
const ticketController = require('../controllers/ticket.controller');
const { authenticate, requireRole, optionalAuth } = require('../middleware/auth.middleware');
const { validateBookTicket, validateTicketNumber } = require('../middleware/validate.middleware');

// POST /api/v1/tickets — optionally authenticated (offline support)
router.post('/', optionalAuth, validateBookTicket, ticketController.bookTicket);

// GET /api/v1/tickets/passenger/me — authenticated passenger
router.get('/passenger/me', authenticate, ticketController.getMyTickets);

// GET /api/v1/tickets/officer/history — authenticated officer
router.get('/officer/history', authenticate, requireRole('STAFF', 'ADMIN'), ticketController.getOfficerVerifications);

// GET /api/v1/tickets/:ticketNumber — public (for QR verification)
router.get('/:ticketNumber', validateTicketNumber, ticketController.getTicket);

// PATCH /api/v1/tickets/:ticketNumber/verify — officer only
router.patch('/:ticketNumber/verify', authenticate, requireRole('STAFF', 'ADMIN'), ticketController.verifyTicket);

module.exports = router;
