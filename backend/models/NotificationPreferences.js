const mongoose = require('mongoose');

const NotificationPreferencesSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    enabled: {
      type: Boolean,
      default: true,
    },
    activeHours: {
      type: [Number],
      default: [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21],
    },
    digestEnabled: {
      type: Boolean,
      default: true,
    },
    digestFrequency: {
      type: String,
      enum: ['daily', 'weekly'],
      default: 'daily',
    },
    digestTime: {
      type: Number,
      default: 18, // 6 PM
      min: 0,
      max: 23,
    },
    newChaptersEnabled: {
      type: Boolean,
      default: true,
    },
    engagementEnabled: {
      type: Boolean,
      default: true,
    },
    recommendationsEnabled: {
      type: Boolean,
      default: true,
    },
    mangaSettings: {
      type: Map,
      of: {
        enabled: { type: Boolean, default: true },
        immediate: { type: Boolean, default: true },
        onlyNewChapters: { type: Boolean, default: true },
      },
      default: {},
    },
  },
  { timestamps: true }
);

// Note: userId already has unique: true which creates an index automatically
// No need for explicit index definition

module.exports = mongoose.model('NotificationPreferences', NotificationPreferencesSchema);

