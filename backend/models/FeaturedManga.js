const mongoose = require('mongoose');

const featuredMangaSchema = new mongoose.Schema({
  mangaId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Manga',
    required: true,
  },
  type: {
    type: String,
    enum: ['featured', 'carousel', 'banner'],
    default: 'carousel',
  },
  priority: {
    type: Number,
    default: 0, // Higher = shows first
  },
  isManual: {
    type: Boolean,
    default: true, // true = manually added by admin, false = auto-added (recent updates)
  },
  expiresAt: {
    type: Date,
    default: null, // null = never expires, otherwise auto-remove after this date
  },
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Indexes
featuredMangaSchema.index({ type: 1, priority: -1 });
featuredMangaSchema.index({ isActive: 1, expiresAt: 1 });
featuredMangaSchema.index({ mangaId: 1, type: 1 }, { unique: true });

module.exports = mongoose.model('FeaturedManga', featuredMangaSchema);
