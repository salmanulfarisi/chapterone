const mongoose = require('mongoose');

const bookmarkSchema = new mongoose.Schema({
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
  collectionName: {
    type: String,
    default: 'default',
  },
}, {
  timestamps: true,
});

// Indexes
bookmarkSchema.index({ userId: 1, mangaId: 1 }, { unique: true });
bookmarkSchema.index({ userId: 1, collectionName: 1 });

module.exports = mongoose.model('Bookmark', bookmarkSchema);

