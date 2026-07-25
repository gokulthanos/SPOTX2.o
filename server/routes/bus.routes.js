// server/routes/bus.routes.js
const router = require('express').Router();
const busController = require('../controllers/bus.controller');
const { authenticate, requireRole } = require('../middleware/auth.middleware');
const { validateBusQuery, validateAddBus } = require('../middleware/validate.middleware');

// GET /api/v1/buses — public (passengers can browse)
router.get('/', validateBusQuery, busController.getBuses);

// GET /api/v1/buses/:id
router.get('/:id', busController.getBusById);

// GET /api/v1/buses/:id/eta
router.get('/:id/eta', busController.getBusEta);

// PUT /api/v1/buses/:id/location — staff/driver update
router.put('/:id/location', authenticate, busController.updateBusLocation);

// POST /api/v1/buses — admin only
router.post('/', authenticate, requireRole('ADMIN'), validateAddBus, busController.addBus);

// PUT /api/v1/buses/:id — admin only
router.put('/:id', authenticate, requireRole('ADMIN'), busController.updateBus);

// DELETE /api/v1/buses/:id — admin only
router.delete('/:id', authenticate, requireRole('ADMIN'), busController.deleteBus);

module.exports = router;
