const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
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
  rating: {
    type: Number,
    required: true,
    min: 1,
    max: 10,
  },
  review: {
    type: String,
  },
}, {
  timestamps: true,
});

// Indexes
ratingSchema.index({ userId: 1, mangaId: 1 }, { unique: true });
ratingSchema.index({ mangaId: 1, rating: -1 });

module.exports = mongoose.model('Rating', ratingSchema);

