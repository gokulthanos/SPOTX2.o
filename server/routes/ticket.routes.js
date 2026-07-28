// server/routes/ticket.routes.js
// ─────────────────────────────────────────────────
const { Router } = require('express');
const { authenticate } = require('../middleware/auth.middleware');
const {
  bookTicket,
  getMyTickets,
  getTicketDetail,
} = require('../controllers/ticket.controller');

const router = Router();

router.post('/book', authenticate, bookTicket);
router.get('/my-tickets', authenticate, getMyTickets);
router.get('/:id', authenticate, getTicketDetail);

module.exports = router;
