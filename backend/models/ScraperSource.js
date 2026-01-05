const mongoose = require('mongoose');

const scraperSourceSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    unique: true,
  },
  baseUrl: {
    type: String,
    required: true,
  },
  selectors: {
    mangaList: String,
    mangaItem: String,
    mangaTitle: String,
    mangaCover: String,
    mangaDescription: String,
    mangaGenres: String,
    chapterList: String,
    chapterItem: String,
    chapterNumber: String,
    chapterTitle: String,
    pageList: String,
    pageImage: String,
  },
  config: {
    requiresJS: {
      type: Boolean,
      default: false,
    },
    rateLimit: {
      type: Number,
      default: 60, // requests per minute
    },
    headers: {
      type: Map,
      of: String,
    },
  },
  status: {
    type: String,
    enum: ['active', 'inactive', 'error'],
    default: 'active',
  },
  lastScraped: {
    type: Date,
  },
  errorLog: [{
    message: String,
    timestamp: Date,
  }],
}, {
  timestamps: true,
});

module.exports = mongoose.model('ScraperSource', scraperSourceSchema);

