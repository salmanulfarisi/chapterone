const mongoose = require('mongoose');

const chapterUnlockSchema = new mongoose.Schema({
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
  chapterNumber: {
    type: Number,
    required: true,
  },
  unlockMethod: {
    type: String,
    enum: ['ad', 'premium', 'free'],
    default: 'ad',
  },
  unlockedAt: {
    type: Date,
    default: Date.now,
  },
}, {
  timestamps: true,
});

// Compound index to prevent duplicate unlocks
chapterUnlockSchema.index({ userId: 1, mangaId: 1, chapterNumber: 1 }, { unique: true });
chapterUnlockSchema.index({ userId: 1, unlockedAt: -1 });
chapterUnlockSchema.index({ unlockedAt: -1 }); // For admin analytics queries
chapterUnlockSchema.index({ unlockMethod: 1, unlockedAt: -1 }); // For revenue queries
chapterUnlockSchema.index({ mangaId: 1, unlockMethod: 1, unlockedAt: -1 }); // For revenue by manga

module.exports = mongoose.model('ChapterUnlock', chapterUnlockSchema);

