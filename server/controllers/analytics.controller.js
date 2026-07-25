// server/controllers/analytics.controller.js
// ─────────────────────────────────────────────────
// Dashboard Analytics Controller
// Advanced charts, metrics, and reporting
// ─────────────────────────────────────────────────
const { getOne, getAll } = require('../db');
const { sendSuccess } = require('../utils/response');

/**
 * GET /api/v1/analytics/overview
 * Comprehensive dashboard overview with chart data.
 */
const getOverview = async (req, res, next) => {
  try {
    const { days = 7 } = req.query;

    // Revenue trend (daily)
    const revenueTrend = await getAll(
      `SELECT DATE(created_at) as date,
              COUNT(*) as tickets,
              COALESCE(SUM(total_fare), 0) as revenue
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY DATE(created_at)
       ORDER BY date ASC`,
      [days]
    );

    // Bus utilization
    const busUtilization = await getAll(
      `SELECT bus_type,
              COUNT(*) as count,
              AVG(CASE WHEN capacity > 0 THEN ROUND(CAST(current_occupancy AS FLOAT) / capacity * 100, 0) ELSE 0 END) as avg_occupancy
       FROM buses
       GROUP BY bus_type`
    );

    // Popular routes
    const popularRoutes = await getAll(
      `SELECT from_stop, to_stop, COUNT(*) as ticket_count, SUM(total_fare) as total_revenue
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
         AND from_stop != '' AND to_stop != ''
       GROUP BY from_stop, to_stop
       ORDER BY ticket_count DESC
       LIMIT 10`,
      [days]
    );

    // Hourly distribution
    const hourlyDistribution = await getAll(
      `SELECT HOUR(created_at) as hour,
              COUNT(*) as count
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY hour
       ORDER BY hour ASC`,
      [days]
    );

    // Payment method distribution
    const paymentMethods = await getAll(
      `SELECT payment_method, COUNT(*) as count, SUM(total_fare) as total
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY payment_method`,
      [days]
    );

    // Bus status breakdown
    const busStatus = await getAll(
      `SELECT travel_status, COUNT(*) as count FROM buses GROUP BY travel_status`
    );

    // Top delayed buses
    const delayedBuses = await getAll(
      `SELECT bus_number, delay_minutes, travel_status
       FROM buses WHERE delay_minutes > 0
       ORDER BY delay_minutes DESC LIMIT 10`
    );

    // Crowding heatmap data
    const crowdingData = await getAll(
      `SELECT b.bus_number, b.from_stop, b.to_stop,
              b.capacity, b.current_occupancy,
              CASE
                WHEN b.capacity > 0 AND CAST(b.current_occupancy AS FLOAT) / b.capacity >= 0.8 THEN 'high'
                WHEN b.capacity > 0 AND CAST(b.current_occupancy AS FLOAT) / b.capacity >= 0.5 THEN 'medium'
                ELSE 'low'
              END as crowding_level
       FROM buses b
       WHERE b.travel_status = 'Running'`
    );

    return sendSuccess(res, 'Analytics overview', {
      revenueTrend,
      busUtilization,
      popularRoutes,
      hourlyDistribution,
      paymentMethods,
      busStatus,
      delayedBuses,
      crowdingData,
      period: `${days} days`,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/analytics/revenue
 * Detailed revenue analytics.
 */
const getRevenueAnalytics = async (req, res, next) => {
  try {
    const { days = 30, groupBy = 'day' } = req.query;

    let dateFormat;
    switch (groupBy) {
      case 'month':
        dateFormat = '%Y-%m';
        break;
      case 'week':
        dateFormat = '%x-W%v';
        break;
      default:
        dateFormat = '%Y-%m-%d';
    }

    const revenue = await getAll(
      `SELECT DATE_FORMAT(created_at, '${dateFormat}') as period,
              COUNT(*) as tickets,
              COALESCE(SUM(total_fare), 0) as revenue,
              COALESCE(AVG(total_fare), 0) as avg_fare
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY period
       ORDER BY period ASC`,
      [days]
    );

    const totalRevenue = await getOne(
      `SELECT COALESCE(SUM(total_fare), 0) as total, COUNT(*) as tickets
       FROM tickets WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)`,
      [days]
    );

    const walletVsRazorpay = await getAll(
      `SELECT payment_method,
              COUNT(*) as count,
              SUM(total_fare) as amount
       FROM tickets
       WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
       GROUP BY payment_method`,
      [days]
    );

    return sendSuccess(res, 'Revenue analytics', {
      trend: revenue,
      summary: totalRevenue,
      breakdown: walletVsRazorpay,
      period: `${days} days`,
      groupBy,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/analytics/routes
 * Route performance analytics.
 */
const getRouteAnalytics = async (req, res, next) => {
  try {
    const routePerformance = await getAll(
      `SELECT r.route_number, r.name as route_name, r.distance_km, r.base_fare,
              COUNT(t.id) as total_tickets,
              COALESCE(SUM(t.total_fare), 0) as total_revenue,
              (SELECT COUNT(*) FROM buses WHERE route_id = r.id) as active_buses
       FROM routes r
       LEFT JOIN tickets t ON t.bus_id IN (SELECT id FROM buses WHERE route_id = r.id)
       GROUP BY r.id
       ORDER BY total_revenue DESC`
    );

    const stopTraffic = await getAll(
      `SELECT from_stop as stop_name, COUNT(*) as departures
       FROM tickets WHERE from_stop != ''
       GROUP BY from_stop
       ORDER BY departures DESC
       LIMIT 20`
    );

    return sendSuccess(res, 'Route analytics', {
      routePerformance,
      stopTraffic,
    });
  } catch (err) {
    next(err);
  }
};

/**
 * GET /api/v1/analytics/occupancy
 * Bus occupancy analytics.
 */
const getOccupancyAnalytics = async (req, res, next) => {
  try {
    const currentOccupancy = await getAll(
      `SELECT bus_number, bus_type, capacity, current_occupancy,
              CASE WHEN capacity > 0 THEN ROUND(CAST(current_occupancy AS FLOAT) / capacity * 100, 0) ELSE 0 END as percent,
              travel_status
       FROM buses
       WHERE travel_status IN ('Running', 'Delayed')
       ORDER BY percent DESC`
    );

    const avgByType = await getAll(
      `SELECT bus_type,
              AVG(CASE WHEN capacity > 0 THEN ROUND(CAST(current_occupancy AS FLOAT) / capacity * 100, 0) ELSE 0 END) as avg_occupancy,
              COUNT(*) as bus_count
       FROM buses
       GROUP BY bus_type`
    );

    const peakHours = await getAll(
      `SELECT HOUR(bl.recorded_at) as hour,
              AVG(CAST(b.current_occupancy AS FLOAT) / b.capacity * 100) as avg_occupancy
       FROM bus_locations bl
       JOIN buses b ON bl.bus_id = b.id
       WHERE bl.recorded_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
         AND b.capacity > 0
       GROUP BY hour
       ORDER BY hour ASC`
    );

    return sendSuccess(res, 'Occupancy analytics', {
      current: currentOccupancy,
      byType: avgByType,
      peakHours,
    });
  } catch (err) {
    next(err);
  }
};

module.exports = {
  getOverview,
  getRevenueAnalytics,
  getRouteAnalytics,
  getOccupancyAnalytics,
};
