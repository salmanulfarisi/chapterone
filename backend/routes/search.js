const express = require('express');
const Manga = require('../models/Manga');
const SearchHistory = require('../models/SearchHistory');
const SavedSearch = require('../models/SavedSearch');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');
const { buildMangaQuery } = require('../utils/mangaQueryBuilder');

const router = express.Router();

// Search manga with advanced filters
router.get('/', optionalAuth, async (req, res) => {
  try {
    const { 
      q, 
      genre, 
      status, 
      minRating, 
      maxRating,
      dateFrom,
      dateTo,
      dateField = 'createdAt',
      limit = 20 
    } = req.query;

    // Build query using query builder
    const query = buildMangaQuery(req.user, {
      search: q,
      genre,
      status,
      minRating,
      maxRating,
      dateFrom,
      dateTo,
      dateField,
    });

    const sortObj = q
      ? { score: { $meta: 'textScore' } }
      : { rating: -1, createdAt: -1 };

    const manga = await Manga.find(query)
      .sort(sortObj)
      .limit(parseInt(limit))
      .lean();

    // Save search history if user is authenticated
    if (req.user && q) {
      try {
        await SearchHistory.create({
          userId: req.user._id,
          query: q,
          filters: {
            genre,
            status,
            minRating: minRating ? parseFloat(minRating) : undefined,
            maxRating: maxRating ? parseFloat(maxRating) : undefined,
            dateFrom: dateFrom ? new Date(dateFrom) : undefined,
            dateTo: dateTo ? new Date(dateTo) : undefined,
          },
          resultCount: manga.length,
        });
      } catch (historyError) {
        // Don't fail the search if history save fails
        console.error('Failed to save search history:', historyError);
      }
    }

    res.json(manga);
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ message: 'Search failed' });
  }
});

// Get search history
router.get('/history', authMiddleware, async (req, res) => {
  try {
    const { limit = 20 } = req.query;
    
    const history = await SearchHistory.find({ userId: req.user._id })
      .sort({ searchedAt: -1 })
      .limit(parseInt(limit))
      .lean();

    res.json(history);
  } catch (error) {
    console.error('Get search history error:', error);
    res.status(500).json({ message: 'Failed to fetch search history' });
  }
});

// Clear search history
router.delete('/history', authMiddleware, async (req, res) => {
  try {
    await SearchHistory.deleteMany({ userId: req.user._id });
    res.json({ message: 'Search history cleared' });
  } catch (error) {
    console.error('Clear search history error:', error);
    res.status(500).json({ message: 'Failed to clear search history' });
  }
});

// Delete a specific search history item
router.delete('/history/:id', authMiddleware, async (req, res) => {
  try {
    const history = await SearchHistory.findOneAndDelete({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!history) {
      return res.status(404).json({ message: 'Search history not found' });
    }

    res.json({ message: 'Search history deleted' });
  } catch (error) {
    console.error('Delete search history error:', error);
    res.status(500).json({ message: 'Failed to delete search history' });
  }
});

// Get saved searches
router.get('/saved', authMiddleware, async (req, res) => {
  try {
    const savedSearches = await SavedSearch.find({
      userId: req.user._id,
      isActive: true,
    })
      .sort({ createdAt: -1 })
      .lean();

    res.json(savedSearches);
  } catch (error) {
    console.error('Get saved searches error:', error);
    res.status(500).json({ message: 'Failed to fetch saved searches' });
  }
});

// Save a search
router.post('/saved', authMiddleware, async (req, res) => {
  try {
    const { name, query, filters } = req.body;

    if (!name) {
      return res.status(400).json({ message: 'Search name is required' });
    }

    const savedSearch = await SavedSearch.create({
      userId: req.user._id,
      name,
      query: query || '',
      filters: filters || {},
    });

    res.json(savedSearch);
  } catch (error) {
    console.error('Save search error:', error);
    res.status(500).json({ message: 'Failed to save search' });
  }
});

// Update saved search
router.put('/saved/:id', authMiddleware, async (req, res) => {
  try {
    const { name, query, filters } = req.body;

    const savedSearch = await SavedSearch.findOneAndUpdate(
      {
        _id: req.params.id,
        userId: req.user._id,
      },
      {
        $set: {
          ...(name && { name }),
          ...(query !== undefined && { query }),
          ...(filters && { filters }),
        },
      },
      { new: true }
    );

    if (!savedSearch) {
      return res.status(404).json({ message: 'Saved search not found' });
    }

    res.json(savedSearch);
  } catch (error) {
    console.error('Update saved search error:', error);
    res.status(500).json({ message: 'Failed to update saved search' });
  }
});

// Delete saved search
router.delete('/saved/:id', authMiddleware, async (req, res) => {
  try {
    const savedSearch = await SavedSearch.findOneAndUpdate(
      {
        _id: req.params.id,
        userId: req.user._id,
      },
      { $set: { isActive: false } },
      { new: true }
    );

    if (!savedSearch) {
      return res.status(404).json({ message: 'Saved search not found' });
    }

    res.json({ message: 'Saved search deleted' });
  } catch (error) {
    console.error('Delete saved search error:', error);
    res.status(500).json({ message: 'Failed to delete saved search' });
  }
});

// Get trending searches
router.get('/trending', optionalAuth, async (req, res) => {
  try {
    const { limit = 10, days = 7 } = req.query;
    const daysAgo = new Date();
    daysAgo.setDate(daysAgo.getDate() - parseInt(days));

    // Aggregate to get trending searches
    const trending = await SearchHistory.aggregate([
      {
        $match: {
          searchedAt: { $gte: daysAgo },
          query: { $exists: true, $ne: '' },
        },
      },
      {
        $group: {
          _id: '$query',
          count: { $sum: 1 },
          lastSearched: { $max: '$searchedAt' },
        },
      },
      {
        $sort: { count: -1, lastSearched: -1 },
      },
      {
        $limit: parseInt(limit),
      },
      {
        $project: {
          query: '$_id',
          count: 1,
          lastSearched: 1,
          _id: 0,
        },
      },
    ]);

    res.json(trending);
  } catch (error) {
    console.error('Get trending searches error:', error);
    res.status(500).json({ message: 'Failed to fetch trending searches' });
  }
});

module.exports = router;

