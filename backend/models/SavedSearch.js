const mongoose = require('mongoose');

const savedSearchSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  name: {
    type: String,
    required: true,
    trim: true,
  },
  query: {
    type: String,
    trim: true,
  },
  filters: {
    genre: String,
    status: String,
    minRating: Number,
    maxRating: Number,
    dateFrom: Date,
    dateTo: Date,
    sortBy: String,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Compound index
savedSearchSchema.index({ userId: 1, isActive: 1 });

module.exports = mongoose.model('SavedSearch', savedSearchSchema);

