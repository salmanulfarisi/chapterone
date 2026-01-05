const mongoose = require('mongoose');

const readingListSchema = new mongoose.Schema({
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
  description: {
    type: String,
    default: '',
  },
  mangaIds: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Manga',
  }],
  isPublic: {
    type: Boolean,
    default: false,
  },
  isDefault: {
    type: Boolean,
    default: false,
  },
  listType: {
    type: String,
    enum: ['custom', 'reading', 'completed', 'on_hold', 'dropped', 'plan_to_read'],
    default: 'custom',
  },
}, {
  timestamps: true,
});

// Indexes
readingListSchema.index({ userId: 1, name: 1 }, { unique: true });
readingListSchema.index({ userId: 1, listType: 1 });
readingListSchema.index({ isPublic: 1 });

module.exports = mongoose.model('ReadingList', readingListSchema);
