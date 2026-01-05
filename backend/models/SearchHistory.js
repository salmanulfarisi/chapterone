const mongoose = require('mongoose');

const searchHistorySchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  query: {
    type: String,
    required: true,
    trim: true,
  },
  filters: {
    genre: String,
    status: String,
    minRating: Number,
    maxRating: Number,
    dateFrom: Date,
    dateTo: Date,
  },
  resultCount: {
    type: Number,
    default: 0,
  },
  searchedAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
}, {
  timestamps: true,
});

// Compound index for user search history
searchHistorySchema.index({ userId: 1, searchedAt: -1 });
// Index for trending searches (aggregation)
searchHistorySchema.index({ query: 1, searchedAt: -1 });

module.exports = mongoose.model('SearchHistory', searchHistorySchema);

