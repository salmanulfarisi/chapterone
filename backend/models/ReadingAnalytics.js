const mongoose = require('mongoose');

const readingAnalyticsSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  mangaId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Manga',
    required: true,
    index: true,
  },
  chapterId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Chapter',
    required: false, // Make optional since we might not always have a valid ObjectId
  },
  chapterNumber: {
    type: Number,
    required: true,
  },
  totalChapters: {
    type: Number,
    required: true,
  },
  // Reading session data
  sessionStart: {
    type: Date,
    required: true,
    index: true,
  },
  sessionEnd: {
    type: Date,
  },
  timeSpent: {
    type: Number, // in seconds
    default: 0,
  },
  pagesRead: {
    type: Number,
    default: 0,
  },
  // Completion status
  isCompleted: {
    type: Boolean,
    default: false,
  },
  completionPercentage: {
    type: Number, // 0-100
    default: 0,
  },
  // Drop-off point
  lastPageRead: {
    type: Number,
    default: 0,
  },
  totalPages: {
    type: Number,
    default: 0,
  },
  // Reading pattern data
  dayOfWeek: {
    type: Number, // 0-6 (Sunday-Saturday)
    required: true,
  },
  hourOfDay: {
    type: Number, // 0-23
    required: true,
  },
  // Genre tracking
  genres: [{
    type: String,
  }],
}, {
  timestamps: true,
});

// Compound indexes for efficient queries
readingAnalyticsSchema.index({ userId: 1, sessionStart: -1 });
readingAnalyticsSchema.index({ userId: 1, mangaId: 1, sessionStart: -1 });
readingAnalyticsSchema.index({ userId: 1, dayOfWeek: 1 });
readingAnalyticsSchema.index({ userId: 1, hourOfDay: 1 });
readingAnalyticsSchema.index({ userId: 1, genres: 1 });
readingAnalyticsSchema.index({ sessionStart: -1 }); // For admin analytics queries
readingAnalyticsSchema.index({ mangaId: 1, sessionStart: -1 }); // For content performance queries

module.exports = mongoose.model('ReadingAnalytics', readingAnalyticsSchema);

