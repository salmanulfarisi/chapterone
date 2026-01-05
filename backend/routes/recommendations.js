const express = require('express');
const Manga = require('../models/Manga');
const ReadingHistory = require('../models/ReadingHistory');
const Bookmark = require('../models/Bookmark');
const Rating = require('../models/Rating');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');

const router = express.Router();

// Get personalized recommendations
router.get('/', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Run initial queries in parallel
    const [userHistory, userBookmarks, userRatings] = await Promise.all([
      ReadingHistory.find({ userId }).select('mangaId').lean(),
      Bookmark.find({ userId }).select('mangaId').lean(),
      Rating.find({ userId }).select('mangaId rating').lean(),
    ]);

    // Get all manga IDs user has interacted with
    const userMangaIds = new Set();
    userHistory.forEach(h => userMangaIds.add(h.mangaId.toString()));
    userBookmarks.forEach(b => userMangaIds.add(b.mangaId.toString()));
    userRatings.forEach(r => userMangaIds.add(r.mangaId.toString()));

    // Get favorite genres from user's reading history
    const userManga = await Manga.find({
      _id: { $in: Array.from(userMangaIds) },
      isActive: true,
    }).select('genres').lean();

    const genreCounts = {};
    userManga.forEach(manga => {
      if (manga.genres && Array.isArray(manga.genres)) {
        manga.genres.forEach(genre => {
          genreCounts[genre] = (genreCounts[genre] || 0) + 1;
        });
      }
    });

    // Get top 3 favorite genres
    const favoriteGenres = Object.entries(genreCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([genre]) => genre);

    // Get average rating user gives (to find similar quality manga)
    const avgUserRating = userRatings.length > 0
      ? userRatings.reduce((sum, r) => sum + (r.rating || 0), 0) / userRatings.length
      : 0;

    // Build recommendation queries - run in parallel
    const userMangaIdsArray = Array.from(userMangaIds);
    const recommendationQueries = [];

    // 1. Based on favorite genres (exclude already read/bookmarked)
    if (favoriteGenres.length > 0) {
      recommendationQueries.push(
        Manga.find({
          _id: { $nin: userMangaIdsArray },
          genres: { $in: favoriteGenres },
          isActive: true,
        })
          .sort({ rating: -1, totalViews: -1 })
          .limit(10)
          .lean()
          .then(results => results.map(m => ({
            ...m,
            reason: `Similar to your favorite genres: ${favoriteGenres.join(', ')}`,
            score: 0.8,
          })))
      );
    }

    // 2. Highly rated manga (similar to user's average rating preference)
    recommendationQueries.push(
      Manga.find({
        _id: { $nin: userMangaIdsArray },
        isActive: true,
        rating: { $gte: Math.max(0, avgUserRating - 1) },
      })
        .sort({ rating: -1, totalViews: -1 })
        .limit(10)
        .lean()
        .then(results => results.map(m => ({
          ...m,
          reason: 'Highly rated by the community',
          score: 0.7,
        })))
    );

    // 3. Trending manga (high views, recent updates)
    recommendationQueries.push(
      Manga.find({
        _id: { $nin: userMangaIdsArray },
        isActive: true,
        totalViews: { $gte: 100 },
      })
        .sort({ totalViews: -1, updatedAt: -1 })
        .limit(10)
        .lean()
        .then(results => results.map(m => ({
          ...m,
          reason: 'Trending now',
          score: 0.6,
        })))
    );

    // 4. Recently updated manga
    recommendationQueries.push(
      Manga.find({
        _id: { $nin: userMangaIdsArray },
        isActive: true,
        updatedAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }, // Last 7 days
      })
        .sort({ updatedAt: -1 })
        .limit(10)
        .lean()
        .then(results => results.map(m => ({
          ...m,
          reason: 'Recently updated',
          score: 0.5,
        })))
    );

    // Execute all recommendation queries in parallel
    const recommendationResults = await Promise.all(recommendationQueries);
    const recommendations = recommendationResults.flat();

    // Remove duplicates and sort by score
    const uniqueRecommendations = new Map();
    recommendations.forEach(rec => {
      const id = rec._id.toString();
      if (!uniqueRecommendations.has(id) || uniqueRecommendations.get(id).score < rec.score) {
        uniqueRecommendations.set(id, rec);
      }
    });

    const finalRecommendations = Array.from(uniqueRecommendations.values())
      .sort((a, b) => b.score - a.score)
      .slice(0, 20);

    res.json(finalRecommendations);
  } catch (error) {
    console.error('Get recommendations error:', error);
    res.status(500).json({ message: 'Failed to fetch recommendations' });
  }
});

// Get "Continue Reading" - manga with reading history
router.get('/continue-reading', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    const history = await ReadingHistory.find({ userId })
      .sort({ lastRead: -1 })
      .limit(10)
      .lean();

    const mangaIds = history.map(h => h.mangaId);
    const manga = await Manga.find({
      _id: { $in: mangaIds },
      isActive: true,
      source: { $ne: 'hotcomics' }, // Exclude hotcomics from continue reading
    }).lean();

    // Map history to manga
    const continueReading = history.map(h => {
      const mangaItem = manga.find(m => m._id.toString() === h.mangaId.toString());
      if (!mangaItem) return null;

      // Get last read chapter number
      let lastChapterNumber = 0;
      if (h.chapterId && h.chapterId.includes('_ch')) {
        const parts = h.chapterId.split('_ch');
        if (parts.length > 1) {
          lastChapterNumber = parseInt(parts[1], 10) || 0;
        }
      }

      // Get total chapters
      const totalChapters = mangaItem.chapters 
        ? mangaItem.chapters.filter(ch => ch.isActive !== false).length
        : 0;

      return {
        ...mangaItem,
        lastRead: h.lastRead,
        lastChapterNumber,
        totalChapters,
        chaptersRead: h.chaptersRead || 0,
      };
    }).filter(item => item !== null);

    res.json(continueReading);
  } catch (error) {
    console.error('Get continue reading error:', error);
    res.status(500).json({ message: 'Failed to fetch continue reading' });
  }
});

// Get similar manga to a specific manga
router.get('/similar/:mangaId', optionalAuth, async (req, res) => {
  try {
    const { mangaId } = req.params;
    const limit = parseInt(req.query.limit) || 10;

    // Get the target manga
    const targetManga = await Manga.findById(mangaId).lean();
    if (!targetManga) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    const similarManga = [];
    const targetGenres = targetManga.genres || [];
    const targetRating = targetManga.rating || 0;
    const targetAuthor = targetManga.author;
    const targetArtist = targetManga.artist;

    // 1. Same genres (highest priority)
    if (targetGenres.length > 0) {
      const genreBased = await Manga.find({
        _id: { $ne: mangaId },
        genres: { $in: targetGenres },
        isActive: true,
      })
        .sort({ rating: -1, totalViews: -1 })
        .limit(limit * 2)
        .lean();

      similarManga.push(...genreBased.map(m => ({
        ...m,
        similarityScore: 0.9,
        reason: 'Similar genres',
      })));
    }

    // 2. Same author/artist
    if (targetAuthor || targetArtist) {
      const authorQuery = {};
      if (targetAuthor) authorQuery.author = targetAuthor;
      if (targetArtist) authorQuery.artist = targetArtist;

      const authorBased = await Manga.find({
        _id: { $ne: mangaId },
        ...authorQuery,
        isActive: true,
      })
        .sort({ rating: -1, totalViews: -1 })
        .limit(limit)
        .lean();

      similarManga.push(...authorBased.map(m => ({
        ...m,
        similarityScore: 0.85,
        reason: targetAuthor && targetArtist 
          ? `Same author & artist` 
          : targetAuthor 
            ? 'Same author' 
            : 'Same artist',
      })));
    }

    // 3. Similar rating range (±1.0)
    const ratingBased = await Manga.find({
      _id: { $ne: mangaId },
      rating: { 
        $gte: Math.max(0, targetRating - 1),
        $lte: Math.min(10, targetRating + 1),
      },
      isActive: true,
    })
      .sort({ rating: -1, totalViews: -1 })
      .limit(limit)
      .lean();

    similarManga.push(...ratingBased.map(m => ({
      ...m,
      similarityScore: 0.7,
      reason: 'Similar rating',
    })));

    // Remove duplicates and sort by similarity score
    const uniqueSimilar = new Map();
    similarManga.forEach(m => {
      const id = m._id.toString();
      if (!uniqueSimilar.has(id) || uniqueSimilar.get(id).similarityScore < m.similarityScore) {
        uniqueSimilar.set(id, m);
      }
    });

    const finalSimilar = Array.from(uniqueSimilar.values())
      .sort((a, b) => b.similarityScore - a.similarityScore)
      .slice(0, limit);

    res.json(finalSimilar);
  } catch (error) {
    console.error('Get similar manga error:', error);
    res.status(500).json({ message: 'Failed to fetch similar manga' });
  }
});

// Get trending manga by genre
router.get('/trending-by-genre', optionalAuth, async (req, res) => {
  try {
    const { genre, limit = 10 } = req.query;

    if (!genre) {
      return res.status(400).json({ message: 'Genre parameter is required' });
    }

    // Get trending manga in the specified genre
    // Trending = high views + recent updates
    const trending = await Manga.find({
      genres: genre,
      isActive: true,
      totalViews: { $gte: 100 }, // Minimum views threshold
    })
      .sort({ 
        totalViews: -1, 
        updatedAt: -1,
        rating: -1,
      })
      .limit(parseInt(limit))
      .lean();

    res.json(trending);
  } catch (error) {
    console.error('Get trending by genre error:', error);
    res.status(500).json({ message: 'Failed to fetch trending by genre' });
  }
});

// Get "You might also like" - enhanced personalized recommendations
router.get('/you-might-like', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const limit = parseInt(req.query.limit) || 15;

    // Get user's reading history and preferences - run in parallel
    const [userHistory, userBookmarks, userRatings] = await Promise.all([
      ReadingHistory.find({ userId }).select('mangaId').lean(),
      Bookmark.find({ userId }).select('mangaId').lean(),
      Rating.find({ userId }).select('mangaId rating').lean(),
    ]);

    const userMangaIds = new Set();
    userHistory.forEach(h => userMangaIds.add(h.mangaId.toString()));
    userBookmarks.forEach(b => userMangaIds.add(b.mangaId.toString()));
    userRatings.forEach(r => userMangaIds.add(r.mangaId.toString()));

    // Get user's favorite manga details
    const userManga = await Manga.find({
      _id: { $in: Array.from(userMangaIds) },
      isActive: true,
    }).lean();

    // Build genre and author preferences
    const genreCounts = {};
    const authorCounts = {};
    const artistCounts = {};
    let totalRating = 0;
    let ratingCount = 0;

    userManga.forEach(manga => {
      // Count genres
      if (manga.genres && Array.isArray(manga.genres)) {
        manga.genres.forEach(genre => {
          genreCounts[genre] = (genreCounts[genre] || 0) + 1;
        });
      }
      // Count authors
      if (manga.author) {
        authorCounts[manga.author] = (authorCounts[manga.author] || 0) + 1;
      }
      // Count artists
      if (manga.artist) {
        artistCounts[manga.artist] = (artistCounts[manga.artist] || 0) + 1;
      }
      // Average rating
      if (manga.rating) {
        totalRating += manga.rating;
        ratingCount++;
      }
    });

    const topGenres = Object.entries(genreCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([genre]) => genre);

    const topAuthors = Object.entries(authorCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([author]) => author);

    const topArtists = Object.entries(artistCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([artist]) => artist);

    const avgRating = ratingCount > 0 ? totalRating / ratingCount : 0;

    // Build recommendation queries - run in parallel
    const userMangaIdsArray = Array.from(userMangaIds);
    const recommendationQueries = [];

    // 1. Same genres as favorite manga (highest weight)
    if (topGenres.length > 0) {
      recommendationQueries.push(
        Manga.find({
          _id: { $nin: userMangaIdsArray },
          genres: { $in: topGenres },
          isActive: true,
        })
          .sort({ rating: -1, totalViews: -1 })
          .limit(limit)
          .lean()
          .then(results => results.map(m => ({
            ...m,
            recommendationScore: 0.9,
            reason: `Based on your favorite genres`,
          })))
      );
    }

    // 2. Same authors/artists
    if (topAuthors.length > 0 || topArtists.length > 0) {
      recommendationQueries.push(
        Manga.find({
          _id: { $nin: userMangaIdsArray },
          $or: [
            { author: { $in: topAuthors } },
            { artist: { $in: topArtists } },
          ],
          isActive: true,
        })
          .sort({ rating: -1, totalViews: -1 })
          .limit(limit)
          .lean()
          .then(results => results.map(m => ({
            ...m,
            recommendationScore: 0.85,
            reason: 'From authors/artists you like',
          })))
      );
    }

    // 3. Similar rating range
    if (avgRating > 0) {
      recommendationQueries.push(
        Manga.find({
          _id: { $nin: userMangaIdsArray },
          rating: { 
            $gte: Math.max(0, avgRating - 1.5),
            $lte: Math.min(10, avgRating + 1.5),
          },
          isActive: true,
        })
          .sort({ rating: -1, totalViews: -1 })
          .limit(limit)
          .lean()
          .then(results => results.map(m => ({
            ...m,
            recommendationScore: 0.75,
            reason: 'Similar quality to your favorites',
          })))
      );
    }

    // 4. Trending in user's preferred genres
    if (topGenres.length > 0) {
      recommendationQueries.push(
        Manga.find({
          _id: { $nin: userMangaIdsArray },
          genres: { $in: topGenres },
          isActive: true,
          totalViews: { $gte: 500 },
          updatedAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }, // Last 30 days
        })
          .sort({ totalViews: -1, updatedAt: -1 })
          .limit(limit)
          .lean()
          .then(results => results.map(m => ({
            ...m,
            recommendationScore: 0.7,
            reason: 'Trending in genres you like',
          })))
      );
    }

    // Execute all recommendation queries in parallel
    const recommendationResults = await Promise.all(recommendationQueries);
    const recommendations = recommendationResults.flat();

    // Remove duplicates and sort by score
    const uniqueRecs = new Map();
    recommendations.forEach(rec => {
      const id = rec._id.toString();
      if (!uniqueRecs.has(id) || uniqueRecs.get(id).recommendationScore < rec.recommendationScore) {
        uniqueRecs.set(id, rec);
      }
    });

    const finalRecs = Array.from(uniqueRecs.values())
      .sort((a, b) => b.recommendationScore - a.recommendationScore)
      .slice(0, limit);

    res.json(finalRecs);
  } catch (error) {
    console.error('Get you might like error:', error);
    res.status(500).json({ message: 'Failed to fetch recommendations' });
  }
});

module.exports = router;
