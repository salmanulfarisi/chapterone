const mongoose = require('mongoose');

const readingHistorySchema = new mongoose.Schema({
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
  },
  chapterId: {
    type: String,
    required: true,
  },
  pageNumber: {
    type: Number,
    default: 0,
  },
  chaptersRead: {
    type: Number,
    default: 0,
  },
  lastRead: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

// Indexes
readingHistorySchema.index({ userId: 1, mangaId: 1 }, { unique: true });
readingHistorySchema.index({ userId: 1, lastRead: -1 });
readingHistorySchema.index({ lastRead: -1 }); // For admin analytics queries
readingHistorySchema.index({ mangaId: 1, lastRead: -1 }); // For popular content queries

module.exports = mongoose.model('ReadingHistory', readingHistorySchema);

