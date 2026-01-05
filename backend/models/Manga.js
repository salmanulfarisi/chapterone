const mongoose = require('mongoose');

const mangaSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
    index: true,
  },
  description: {
    type: String,
  },
  cover: {
    type: String,
  },
  genres: [{
    type: String,
    trim: true,
  }],
  status: {
    type: String,
    enum: ['ongoing', 'completed', 'hiatus', 'cancelled'],
    default: 'ongoing',
  },
  author: {
    type: String,
  },
  artist: {
    type: String,
  },
  rating: {
    type: Number,
    default: 0,
    min: 0,
    max: 10,
  },
  ratingCount: {
    type: Number,
    default: 0,
  },
  totalChapters: {
    type: Number,
    default: 0,
  },
  totalViews: {
    type: Number,
    default: 0,
  },
  followersCount: {
    type: Number,
    default: 0,
  },
  type: {
    type: String,
    enum: ['manga', 'manhwa', 'manhua', 'comic', 'webtoon', 'other'],
    default: 'manhwa',
  },
  releaseDate: {
    type: Date,
  },
  source: {
    type: String,
    index: true,
  },
  sourceUrl: {
    type: String,
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  // Adult content flags
  isAdult: {
    type: Boolean,
    default: false,
    index: true,
  },
  ageRating: {
    type: String,
    enum: ['all', '13+', '16+', '18+'],
    default: 'all',
    index: true,
  },
  // Freemium model
  freeChapters: {
    type: Number,
    default: 3, // First 3 chapters free
  },
  // Embedded chapters array
  chapters: [{
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
    isLocked: {
      type: Boolean,
      default: false, // For freemium model
    },
    firebaseStoragePath: {
      type: String, // Path in Firebase Storage
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  }],
}, {
  timestamps: true,
});

// Indexes
mangaSchema.index({ title: 'text', description: 'text' });
mangaSchema.index({ genres: 1 });
mangaSchema.index({ status: 1 });
mangaSchema.index({ rating: -1 });
mangaSchema.index({ totalViews: -1 });
mangaSchema.index({ createdAt: -1 });
mangaSchema.index({ isAdult: 1, isActive: 1 }); // Compound index for filtering
mangaSchema.index({ source: 1, isAdult: 1 }); // For source-based filtering
mangaSchema.index({ isActive: 1, createdAt: -1 }); // Compound index for admin queries (most common)
mangaSchema.index({ isActive: 1, updatedAt: -1 }); // For updatedAt sorting
mangaSchema.index({ isActive: 1, rating: -1 }); // For rating sorting
mangaSchema.index({ isActive: 1, totalViews: -1 }); // For views sorting

module.exports = mongoose.model('Manga', mangaSchema);

