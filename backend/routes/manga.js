const express = require('express');
const mongoose = require('mongoose');
const Manga = require('../models/Manga');
const Chapter = require('../models/Chapter');
const Bookmark = require('../models/Bookmark');
const Rating = require('../models/Rating');
const FeaturedManga = require('../models/FeaturedManga');
const ChapterUnlock = require('../models/ChapterUnlock');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');
const { buildMangaQuery, buildMangaSort } = require('../utils/mangaQueryBuilder');

const router = express.Router();

// Get all unique genres
router.get('/genres', optionalAuth, async (req, res) => {
  try {
    const query = { isActive: true };
    // Don't filter by adult content - show all genres
    const genres = await Manga.distinct('genres', query);
    // Sort alphabetically and filter out empty strings
    const sortedGenres = genres
      .filter(g => g && g.trim())
      .sort((a, b) => a.localeCompare(b));
    res.json(sortedGenres);
  } catch (error) {
    console.error('Get genres error:', error);
    res.status(500).json({ message: 'Failed to fetch genres' });
  }
});

// Get featured/carousel manga for home screen
router.get('/featured', optionalAuth, async (req, res) => {
  try {
    const { type = 'carousel' } = req.query;
    const now = new Date();

    const featured = await FeaturedManga.find({
      type,
      isActive: true,
      $or: [
        { expiresAt: null },
        { expiresAt: { $gt: now } },
      ],
    })
      .populate({
        path: 'mangaId',
        match: { 
          isActive: true,
          source: { $ne: 'hotcomics' }, // Exclude hotcomics from featured
        },
        select: 'title cover rating status genres description updatedAt isAdult ageRating',
      })
      .sort({ priority: -1, createdAt: -1 })
      .limit(10)
      .lean();

    // Return just the manga data with featured info
    // Exclude hotcomics content - only show on adult page
    const result = featured
      .filter(f => f.mangaId != null)
      .map(f => ({
        ...f.mangaId,
        featuredId: f._id,
        isManual: f.isManual,
        priority: f.priority,
      }));

    res.json(result);
  } catch (error) {
    console.error('Get featured error:', error);
    res.status(500).json({ message: 'Failed to fetch featured manga' });
  }
});

// Get all manga with pagination
router.get('/', optionalAuth, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;
    const sortBy = req.query.sortBy || req.query.sort;
    const sort = req.query.sort || 'desc';

    // Build query using query builder (includes adult content filtering)
    const query = buildMangaQuery(req.user, {
      status: req.query.status,
      genre: req.query.genre,
      search: req.query.search,
      minRating: req.query.minRating,
      type: req.query.type,
      source: req.query.source, // Pass source if provided
    });

    // Build sort object
    const sortObj = buildMangaSort({ sortBy, sort });

    // Debug logging
    console.log('Manga query:', JSON.stringify(query, null, 2));
    console.log('User age verified:', req.user?.ageVerified);

    const [manga, total] = await Promise.all([
      Manga.find(query)
        .sort(sortObj)
        .skip(skip)
        .limit(limit)
        .lean(),
      Manga.countDocuments(query),
    ]);

    console.log(`Found ${manga.length} manga (total: ${total})`);

    res.json({
      manga,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('Get manga error:', error);
    res.status(500).json({ message: 'Failed to fetch manga' });
  }
});

// Get manga by ID with followers count and embedded chapters
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const manga = await Manga.findById(req.params.id).lean();
    
    if (!manga || !manga.isActive) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    // Don't check age verification here - allow viewing manga details
    // Age verification only required for adult content page (source=hotcomics)

    // Get followers count from bookmarks
    const followersCount = await Bookmark.countDocuments({ mangaId: manga._id });
    
    // Get rating stats
    const ratingStats = await Rating.aggregate([
      { $match: { mangaId: manga._id } },
      { $group: { _id: null, avgRating: { $avg: '$rating' }, count: { $sum: 1 } } }
    ]);
    
    // Get user's rating if logged in
    let userRating = null;
    if (req.user) {
      const rating = await Rating.findOne({ userId: req.user._id, mangaId: manga._id });
      userRating = rating?.rating || null;
    }

    // Get related manga (same genres) - don't filter by adult content
    const relatedQuery = {
      _id: { $ne: manga._id },
      genres: { $in: manga.genres || [] },
      isActive: true,
    };
    const relatedManga = await Manga.find(relatedQuery)
      .sort({ rating: -1 })
      .limit(6)
      .select('title cover rating status isAdult ageRating')
      .lean();

    // Get chapters from embedded array (filter active, sort by chapter number) - always use new ID format
    const chapters = (manga.chapters || [])
      .filter(ch => ch.isActive !== false)
      .sort((a, b) => a.chapterNumber - b.chapterNumber)
      .map(ch => ({
        _id: `${manga._id}_ch${ch.chapterNumber}`, // Always use new format
        mangaId: manga._id.toString(),
        chapterNumber: ch.chapterNumber,
        title: ch.title || `Chapter ${ch.chapterNumber}`,
        pages: ch.pages || [],
        releaseDate: ch.releaseDate,
        views: ch.views || 0,
        isActive: ch.isActive !== false,
        createdAt: ch.createdAt || manga.createdAt,
        updatedAt: ch.updatedAt || manga.updatedAt,
      }));

    res.json({
      ...manga,
      followersCount,
      ratingCount: ratingStats[0]?.count || 0,
      rating: ratingStats[0]?.avgRating || manga.rating || 0,
      userRating,
      relatedManga,
      chapters, // Include chapters in response
    });
  } catch (error) {
    console.error('Get manga error:', error);
    res.status(500).json({ message: 'Failed to fetch manga' });
  }
});

// Get manga chapters (from embedded array)
router.get('/:id/chapters', optionalAuth, async (req, res) => {
  try {
    const manga = await Manga.findById(req.params.id).lean();
    
    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    // Determine if chapters should be locked (for adult manga)
    const freeChapters = manga.freeChapters || 3;
    const shouldLock = manga.isAdult === true;

    // Get unlocked chapters for this user and manga (if authenticated)
    let unlockedChapters = new Set();
    if (req.user && shouldLock) {
      try {
        // Ensure mangaId is ObjectId for query
        const mangaIdForQuery = mongoose.Types.ObjectId.isValid(manga._id) 
          ? new mongoose.Types.ObjectId(manga._id.toString()) 
          : manga._id;
        
        // Query unlock records - no expiration, unlocks are permanent
        const unlockRecords = await ChapterUnlock.find({
          userId: req.user._id,
          mangaId: mangaIdForQuery,
        }).lean();
        
        console.log(`[UNLOCK CHECK] Querying unlock records for mangaId: ${mangaIdForQuery}, userId: ${req.user._id}`);
        console.log(`[UNLOCK CHECK] Found ${unlockRecords.length} unlock records`);
        
        unlockRecords.forEach(record => {
          const unlockedAt = record.unlockedAt ? new Date(record.unlockedAt) : null;
          const hoursAgo = unlockedAt ? Math.floor((Date.now() - unlockedAt.getTime()) / (1000 * 60 * 60)) : 'unknown';
          console.log(`[UNLOCK CHECK]   - Chapter ${record.chapterNumber} unlocked ${hoursAgo} hours ago (method: ${record.unlockMethod}, recordId: ${record._id})`);
          unlockedChapters.add(record.chapterNumber);
        });
        
        console.log(`[UNLOCK CHECK] Total unlocked chapters for manga ${manga._id}, user ${req.user._id}: ${unlockedChapters.size}`);
      } catch (unlockError) {
        console.error('Error fetching unlock records:', unlockError);
        // Continue without unlock records if there's an error
      }
    }

    // Get chapters from embedded array - always use new ID format
    const chapters = (manga.chapters || [])
      .filter(ch => ch.isActive !== false)
      .sort((a, b) => a.chapterNumber - b.chapterNumber)
      .map(ch => {
        // Determine if this chapter should be locked
        const shouldBeLocked = shouldLock && ch.chapterNumber > freeChapters;
        const isUnlocked = unlockedChapters.has(ch.chapterNumber);
        const isLocked = shouldBeLocked && !isUnlocked;

        // Debug logging for locked/unlocked status
        if (shouldLock && ch.chapterNumber > freeChapters) {
          console.log(`Chapter ${ch.chapterNumber}: shouldBeLocked=${shouldBeLocked}, isUnlocked=${isUnlocked}, isLocked=${isLocked}`);
        }

        return {
          _id: `${manga._id}_ch${ch.chapterNumber}`, // Always use new format
          mangaId: manga._id.toString(),
          chapterNumber: ch.chapterNumber,
          title: ch.title || `Chapter ${ch.chapterNumber}`,
          pages: ch.pages || [],
          releaseDate: ch.releaseDate,
          views: ch.views || 0,
          isActive: ch.isActive !== false,
          isLocked: isLocked,
          createdAt: ch.createdAt || manga.createdAt,
          updatedAt: ch.updatedAt || manga.updatedAt,
        };
      });

    res.json(chapters);
  } catch (error) {
    console.error('Get chapters error:', error);
    res.status(500).json({ message: 'Failed to fetch chapters' });
  }
});

// Rate manga
router.post('/:id/rate', authMiddleware, async (req, res) => {
  try {
    const { rating } = req.body;
    const mangaId = req.params.id;
    const userId = req.user._id;

    if (!rating || rating < 1 || rating > 10) {
      return res.status(400).json({ message: 'Rating must be between 1 and 10' });
    }

    const manga = await Manga.findById(mangaId);
    if (!manga || !manga.isActive) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    // Upsert user rating
    await Rating.findOneAndUpdate(
      { userId, mangaId },
      { userId, mangaId, rating },
      { upsert: true, new: true }
    );

    // Recalculate average rating
    const ratingStats = await Rating.aggregate([
      { $match: { mangaId: manga._id } },
      { $group: { _id: null, avgRating: { $avg: '$rating' }, count: { $sum: 1 } } }
    ]);

    const avgRating = ratingStats[0]?.avgRating || rating;
    const ratingCount = ratingStats[0]?.count || 1;

    // Update manga rating
    await Manga.findByIdAndUpdate(mangaId, { 
      rating: avgRating,
      ratingCount 
    });

    res.json({ 
      success: true, 
      rating: avgRating, 
      ratingCount,
      userRating: rating 
    });
  } catch (error) {
    console.error('Rate manga error:', error);
    res.status(500).json({ message: 'Failed to rate manga' });
  }
});

// Get user's rating for manga
router.get('/:id/my-rating', authMiddleware, async (req, res) => {
  try {
    const rating = await Rating.findOne({
      userId: req.user._id,
      mangaId: req.params.id,
    });

    res.json({ rating: rating?.rating || null });
  } catch (error) {
    console.error('Get rating error:', error);
    res.status(500).json({ message: 'Failed to get rating' });
  }
});

module.exports = router;

