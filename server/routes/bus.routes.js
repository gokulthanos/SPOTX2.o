// server/routes/bus.routes.js
// ─────────────────────────────────────────────────
const { Router } = require('express');
const {
  searchNearbyStops,
  getAllStops,
  searchBuses,
  getBusDetail,
} = require('../controllers/bus.controller');

const router = Router();

router.get('/nearby', searchNearbyStops);
router.get('/stops', getAllStops);
router.get('/search', searchBuses);
router.get('/:id', getBusDetail);

module.exports = router;
