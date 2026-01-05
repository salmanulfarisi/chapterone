const mongoose = require('mongoose');

const chapterSchema = new mongoose.Schema({
  mangaId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Manga',
    required: true,
    index: true,
  },
  chapterNumber: {
    type: Number,
    required: true,
  },
  title: {
    type: String,
  },
  pages: [{
    type: String,
    required: true,
  }],
  releaseDate: {
    type: Date,
  },
  views: {
    type: Number,
    default: 0,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Indexes
chapterSchema.index({ mangaId: 1, chapterNumber: 1 }, { unique: true });
chapterSchema.index({ mangaId: 1, createdAt: -1 });

module.exports = mongoose.model('Chapter', chapterSchema);

