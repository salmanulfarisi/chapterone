const ActivityLog = require('../models/ActivityLog');

/**
 * Log an activity/action
 */
async function logActivity(data) {
  try {
    const log = new ActivityLog({
      userId: data.userId || null,
      action: data.action,
      entityType: data.entityType,
      entityId: data.entityId,
      details: data.details || {},
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      severity: data.severity || 'info',
    });

    await log.save();
    return log;
  } catch (error) {
    console.error('Failed to log activity:', error);
    // Don't throw - logging should never break the app
    return null;
  }
}

/**
 * Get activity logs with filters
 */
async function getActivityLogs(filters = {}, options = {}) {
  try {
    const {
      userId,
      action,
      entityType,
      entityId,
      severity,
      startDate,
      endDate,
      limit = 100,
      skip = 0,
    } = filters;

    const query = {};

    if (userId) query.userId = userId;
    if (action) query.action = action;
    if (entityType) query.entityType = entityType;
    if (entityId) query.entityId = entityId;
    if (severity) query.severity = severity;

    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }

    const logs = await ActivityLog.find(query)
      .populate('userId', 'username email')
      .sort({ createdAt: -1 })
      .limit(limit)
      .skip(skip)
      .lean();

    const total = await ActivityLog.countDocuments(query);

    return {
      logs,
      total,
      limit,
      skip,
    };
  } catch (error) {
    console.error('Failed to get activity logs:', error);
    throw error;
  }
}

/**
 * Get system health stats from logs
 */
async function getSystemHealthStats(days = 7) {
  try {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const [
      totalLogs,
      errorLogs,
      criticalLogs,
      recentErrors,
    ] = await Promise.all([
      ActivityLog.countDocuments({
        createdAt: { $gte: startDate },
      }),
      ActivityLog.countDocuments({
        createdAt: { $gte: startDate },
        severity: 'error',
      }),
      ActivityLog.countDocuments({
        createdAt: { $gte: startDate },
        severity: 'critical',
      }),
      ActivityLog.find({
        createdAt: { $gte: startDate },
        severity: { $in: ['error', 'critical'] },
      })
        .sort({ createdAt: -1 })
        .limit(10)
        .lean(),
    ]);

    return {
      totalLogs,
      errorLogs,
      criticalLogs,
      errorRate: totalLogs > 0 ? (errorLogs / totalLogs) * 100 : 0,
      recentErrors,
    };
  } catch (error) {
    console.error('Failed to get system health stats:', error);
    throw error;
  }
}

module.exports = {
  logActivity,
  getActivityLogs,
  getSystemHealthStats,
};
