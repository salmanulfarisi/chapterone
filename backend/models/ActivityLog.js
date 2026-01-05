const mongoose = require('mongoose');

const activityLogSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null, // null for system actions
    index: true,
  },
  action: {
    type: String,
    required: true,
    enum: [
      'manga_created',
      'manga_updated',
      'manga_deleted',
      'chapter_added',
      'chapter_updated',
      'chapter_deleted',
      'user_created',
      'user_updated',
      'user_deleted',
      'user_banned',
      'scraper_job_created',
      'scraper_job_completed',
      'scraper_job_failed',
      'notification_sent',
      'admin_login',
      'admin_action',
      'system_error',
      'api_error',
    ],
    index: true,
  },
  entityType: {
    type: String,
    enum: ['manga', 'chapter', 'user', 'job', 'system', 'notification'],
  },
  entityId: {
    type: String,
    index: true,
  },
  details: {
    type: mongoose.Schema.Types.Mixed,
    default: {},
  },
  ipAddress: {
    type: String,
  },
  userAgent: {
    type: String,
  },
  severity: {
    type: String,
    enum: ['info', 'warning', 'error', 'critical'],
    default: 'info',
    index: true,
  },
}, {
  timestamps: true,
});

// Indexes for efficient querying
activityLogSchema.index({ createdAt: -1 });
activityLogSchema.index({ action: 1, createdAt: -1 });
activityLogSchema.index({ userId: 1, createdAt: -1 });
activityLogSchema.index({ severity: 1, createdAt: -1 });

module.exports = mongoose.model('ActivityLog', activityLogSchema);
