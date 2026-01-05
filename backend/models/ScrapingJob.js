const mongoose = require('mongoose');

const scrapingJobSchema = new mongoose.Schema({
  sourceId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ScraperSource',
    required: false, // Not required for AsuraScanz imports
    index: true,
  },
  jobType: {
    type: String,
    enum: ['scraper', 'asurascanz_import', 'asurascanz_updates', 'asuracomic_import', 'asuracomic_updates', 'hotcomics_import', 'hotcomics_updates'],
    default: 'scraper',
    index: true,
  },
  mangaUrl: {
    type: String,
    // For AsuraScanz imports
  },
  mangaTitle: {
    type: String,
    // For AsuraScanz imports
  },
  isNewManga: {
    type: Boolean,
    default: false,
    // Track if manga was newly created during this job
  },
  mangaId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Manga',
    // For AsuraScanz updates
  },
  chapterNumbers: {
    type: [Number],
    // For selective chapter imports
  },
  status: {
    type: String,
    enum: ['pending', 'running', 'completed', 'failed', 'cancelled'],
    default: 'pending',
    index: true,
  },
  progress: {
    current: {
      type: Number,
      default: 0,
    },
    total: {
      type: Number,
      default: 0,
    },
    percentage: {
      type: Number,
      default: 0,
    },
    currentChapter: {
      type: Number,
      default: 0,
    },
    totalChapters: {
      type: Number,
      default: 0,
    },
  },
  mangaData: [{
    title: String,
    description: String,
    cover: String,
    genres: [String],
    chapters: [{
      number: Number,
      title: String,
      pages: [String],
    }],
  }],
  errorLog: [{
    message: String,
    stack: String,
    timestamp: Date,
  }],
  startedAt: {
    type: Date,
  },
  completedAt: {
    type: Date,
  },
}, {
  timestamps: true,
});

// Indexes
scrapingJobSchema.index({ status: 1, createdAt: -1 });
scrapingJobSchema.index({ sourceId: 1, createdAt: -1 });

module.exports = mongoose.model('ScrapingJob', scrapingJobSchema);

