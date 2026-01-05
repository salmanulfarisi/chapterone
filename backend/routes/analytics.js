const express = require('express');
const ReadingAnalytics = require('../models/ReadingAnalytics');
const ReadingHistory = require('../models/ReadingHistory');
const Manga = require('../models/Manga');
const Chapter = require('../models/Chapter');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// Track reading session
router.post('/track', authMiddleware, async (req, res) => {
  try {
    const {
      mangaId,
      chapterId,
      chapterNumber,
      totalChapters,
      sessionStart,
      sessionEnd,
      timeSpent,
      pagesRead,
      isCompleted,
      completionPercentage,
      lastPageRead,
      totalPages,
      genres,
    } = req.body;

    const sessionStartDate = sessionStart ? new Date(sessionStart) : new Date();
    const sessionEndDate = sessionEnd ? new Date(sessionEnd) : new Date();
    const dayOfWeek = sessionStartDate.getDay();
    const hourOfDay = sessionStartDate.getHours();

    // Handle chapterId - it might be in format "mangaId_chapterNumber" or a valid ObjectId
    let actualChapterId = null;
    if (chapterId) {
      // Check if it's a valid ObjectId format (24 hex characters)
      if (/^[0-9a-fA-F]{24}$/.test(chapterId)) {
        actualChapterId = chapterId;
      } else if (chapterId.includes('_ch') && mangaId) {
        // Try to find the actual chapter ObjectId by mangaId and chapterNumber
        try {
          const chapter = await Chapter.findOne({
            mangaId: mangaId,
            chapterNumber: chapterNumber,
          }).select('_id').lean();
          
          if (chapter) {
            actualChapterId = chapter._id;
          }
        } catch (err) {
          console.warn('Could not find chapter ObjectId, using null:', err);
        }
      }
    }

    const analytics = await ReadingAnalytics.create({
      userId: req.user._id,
      mangaId,
      chapterId: actualChapterId, // Use null if we can't find a valid ObjectId
      chapterNumber,
      totalChapters,
      sessionStart: sessionStartDate,
      sessionEnd: sessionEndDate,
      timeSpent: timeSpent || Math.floor((sessionEndDate - sessionStartDate) / 1000),
      pagesRead: pagesRead || 0,
      isCompleted: isCompleted || false,
      completionPercentage: completionPercentage || 0,
      lastPageRead: lastPageRead || 0,
      totalPages: totalPages || 0,
      dayOfWeek,
      hourOfDay,
      genres: genres || [],
    });

    // Check and award achievements after tracking analytics
    // Run in background to not block the response
    const { checkAndAwardAchievements } = require('../utils/achievements');
    checkAndAwardAchievements(req.user._id).catch(err => {
      console.error('Error checking achievements:', err);
    });

    res.json(analytics);
  } catch (error) {
    console.error('Track analytics error:', error);
    res.status(500).json({ message: 'Failed to track analytics' });
  }
});

// Get reading statistics dashboard
router.get('/dashboard', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Total time spent reading (in seconds)
    const totalTimeResult = await ReadingAnalytics.aggregate([
      { $match: { userId: userId } },
      { $group: { _id: null, totalTime: { $sum: '$timeSpent' } } },
    ]);
    const totalTimeSpent = totalTimeResult[0]?.totalTime || 0;

    // Total chapters read - count from ReadingHistory (sum of chaptersRead) or unique sessions from ReadingAnalytics
    const [historyChaptersResult, analyticsChaptersResult] = await Promise.all([
      ReadingHistory.aggregate([
        { $match: { userId: userId } },
        { $group: { _id: null, total: { $sum: '$chaptersRead' } } },
      ]),
      ReadingAnalytics.aggregate([
        { $match: { userId: userId } },
        { $group: { _id: { mangaId: '$mangaId', chapterNumber: '$chapterNumber' } } },
        { $count: 'total' },
      ]),
    ]);
    
    // Use ReadingHistory count if available, otherwise use ReadingAnalytics unique chapters
    const totalChaptersRead = historyChaptersResult[0]?.total || 
                              analyticsChaptersResult[0]?.total || 
                              0;

    // Total pages read
    const totalPagesResult = await ReadingAnalytics.aggregate([
      { $match: { userId: userId } },
      { $group: { _id: null, totalPages: { $sum: '$pagesRead' } } },
    ]);
    const totalPagesRead = totalPagesResult[0]?.totalPages || 0;

    // Unique manga read
    const uniqueMangaResult = await ReadingAnalytics.aggregate([
      { $match: { userId: userId } },
      { $group: { _id: '$mangaId' } },
      { $count: 'total' },
    ]);
    const uniqueMangaRead = uniqueMangaResult[0]?.total || 0;

    // Average reading session time
    const avgSessionTimeResult = await ReadingAnalytics.aggregate([
      { $match: { userId: userId } },
      { $group: { _id: null, avgTime: { $avg: '$timeSpent' } } },
    ]);
    const avgSessionTime = avgSessionTimeResult[0]?.avgTime || 0;

    // Completion rate (manga completed / manga started)
    // ReadingHistory stores chaptersRead per manga, need to get totalChapters from Manga
    const Manga = require('../models/Manga');
    const readingHistory = await ReadingHistory.find({ userId })
      .populate('mangaId', 'totalChapters')
      .lean();
    
    let totalManga = 0;
    let completedManga = 0;
    
    for (const history of readingHistory) {
      if (history.mangaId && history.mangaId.totalChapters) {
        totalManga++;
        const chaptersRead = history.chaptersRead || 0;
        if (chaptersRead >= history.mangaId.totalChapters) {
          completedManga++;
        }
      }
    }
    
    const completionRate = totalManga > 0 ? (completedManga / totalManga) * 100 : 0;
    const completionData = { total: totalManga, completed: completedManga };

    res.json({
      totalTimeSpent,
      totalChaptersRead,
      totalPagesRead,
      uniqueMangaRead,
      avgSessionTime: Math.round(avgSessionTime),
      completionRate: Math.round(completionRate * 100) / 100,
      totalMangaStarted: completionData.total,
      totalMangaCompleted: completionData.completed,
    });
  } catch (error) {
    console.error('Get dashboard error:', error);
    res.status(500).json({ message: 'Failed to fetch dashboard data' });
  }
});

// Get genre preferences
router.get('/genres', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const Manga = require('../models/Manga');

    // First, try to get genres from ReadingAnalytics
    const analyticsWithGenres = await ReadingAnalytics.find({ 
      userId: userId,
      genres: { $exists: true, $ne: [] },
    }).select('genres mangaId timeSpent').lean();

    let genreStats = [];
    
    if (analyticsWithGenres.length > 0) {
      // Use genres from ReadingAnalytics
      const genreMap = {};
      analyticsWithGenres.forEach(a => {
        if (a.genres && Array.isArray(a.genres)) {
          a.genres.forEach(genre => {
            if (genre && genre.trim()) {
              if (!genreMap[genre]) {
                genreMap[genre] = { count: 0, totalTime: 0, totalChapters: 0 };
              }
              genreMap[genre].count += 1;
              genreMap[genre].totalTime += (a.timeSpent || 0);
              genreMap[genre].totalChapters += 1;
            }
          });
        }
      });

      genreStats = Object.entries(genreMap)
        .map(([genre, data]) => ({
          genre,
          count: data.count,
          totalTime: data.totalTime,
          totalChapters: data.totalChapters,
        }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 10);
    } else {
      // Fallback: Get genres from ReadingHistory -> Manga
      const ReadingHistory = require('../models/ReadingHistory');
      const readingHistory = await ReadingHistory.find({ userId })
        .populate('mangaId', 'genres')
        .select('mangaId chaptersRead')
        .lean();

      const genreMap = {};
      readingHistory.forEach(h => {
        if (h.mangaId && h.mangaId.genres && Array.isArray(h.mangaId.genres)) {
          h.mangaId.genres.forEach(genre => {
            if (genre && genre.trim()) {
              if (!genreMap[genre]) {
                genreMap[genre] = { count: 0, totalTime: 0, totalChapters: 0 };
              }
              genreMap[genre].count += 1;
              genreMap[genre].totalChapters += (h.chaptersRead || 0);
            }
          });
        }
      });

      genreStats = Object.entries(genreMap)
        .map(([genre, data]) => ({
          genre,
          count: data.count,
          totalTime: data.totalTime,
          totalChapters: data.totalChapters,
        }))
        .sort((a, b) => b.count - a.count)
        .slice(0, 10);
    }

    res.json(genreStats);
  } catch (error) {
    console.error('Get genre preferences error:', error);
    res.status(500).json({ message: 'Failed to fetch genre preferences' });
  }
});

// Get reading patterns (time of day, day of week)
router.get('/patterns', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Day of week patterns - filter out null values
    const dayOfWeekPatterns = await ReadingAnalytics.aggregate([
      { $match: { userId: userId, dayOfWeek: { $ne: null, $exists: true } } },
      {
        $group: {
          _id: '$dayOfWeek',
          count: { $sum: 1 },
          totalTime: { $sum: '$timeSpent' },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    // Hour of day patterns - filter out null values
    const hourOfDayPatterns = await ReadingAnalytics.aggregate([
      { $match: { userId: userId, hourOfDay: { $ne: null, $exists: true } } },
      {
        $group: {
          _id: '$hourOfDay',
          count: { $sum: 1 },
          totalTime: { $sum: '$timeSpent' },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    res.json({
      dayOfWeek: dayOfWeekPatterns.map(item => ({
        day: item._id,
        dayName: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][item._id],
        count: item.count,
        totalTime: item.totalTime,
      })),
      hourOfDay: hourOfDayPatterns.map(item => ({
        hour: item._id,
        count: item.count,
        totalTime: item.totalTime,
      })),
    });
  } catch (error) {
    console.error('Get reading patterns error:', error);
    res.status(500).json({ message: 'Failed to fetch reading patterns' });
  }
});

// Get completion rate by manga
router.get('/completion', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const Manga = require('../models/Manga');

    // Get reading history with manga details
    const readingHistory = await ReadingHistory.find({ userId })
      .populate('mangaId', 'title cover totalChapters')
      .lean();

    // Group by manga and calculate completion
    const mangaMap = new Map();
    readingHistory.forEach(h => {
      if (!h.mangaId) return;
      
      const mangaId = h.mangaId._id.toString();
      if (!mangaMap.has(mangaId)) {
        mangaMap.set(mangaId, {
          mangaId: mangaId,
          mangaTitle: h.mangaId.title || 'Unknown',
          mangaCover: h.mangaId.cover || '',
          totalChapters: h.mangaId.totalChapters || 0,
          chaptersRead: 0,
          lastRead: h.lastRead || h.updatedAt || new Date(),
        });
      }
      
      const entry = mangaMap.get(mangaId);
      entry.chaptersRead = Math.max(entry.chaptersRead, h.chaptersRead || 0);
      if (h.lastRead && h.lastRead > entry.lastRead) {
        entry.lastRead = h.lastRead;
      }
    });

    // Calculate completion percentage and format
    const completionData = Array.from(mangaMap.values()).map(entry => {
      const completionPercentage = entry.totalChapters > 0
        ? (entry.chaptersRead / entry.totalChapters) * 100
        : 0;
      
      return {
        ...entry,
        completionPercentage: Math.round(completionPercentage * 100) / 100,
        isCompleted: entry.totalChapters > 0 && entry.chaptersRead >= entry.totalChapters,
      };
    }).sort((a, b) => b.lastRead - a.lastRead).slice(0, 50);

    res.json(completionData);
  } catch (error) {
    console.error('Get completion data error:', error);
    res.status(500).json({ message: 'Failed to fetch completion data' });
  }
});

// Get drop-off analysis
router.get('/dropoff', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Get drop-off points by chapter number
    const dropoffData = await ReadingAnalytics.aggregate([
      { $match: { userId: userId, isCompleted: false } },
      {
        $group: {
          _id: {
            mangaId: '$mangaId',
            chapterNumber: '$chapterNumber',
          },
          count: { $sum: 1 },
          avgCompletionPercentage: { $avg: '$completionPercentage' },
          avgLastPage: { $avg: '$lastPageRead' },
        },
      },
      {
        $lookup: {
          from: 'mangas',
          localField: '_id.mangaId',
          foreignField: '_id',
          as: 'manga',
        },
      },
      { $unwind: '$manga' },
      {
        $project: {
          mangaId: '$_id.mangaId',
          mangaTitle: '$manga.title',
          mangaCover: '$manga.cover',
          chapterNumber: '$_id.chapterNumber',
          dropoffCount: '$count',
          avgCompletionPercentage: { $round: ['$avgCompletionPercentage', 2] },
          avgLastPage: { $round: ['$avgLastPage', 0] },
        },
      },
      { $sort: { dropoffCount: -1 } },
      { $limit: 20 },
    ]);

    // Get overall drop-off statistics
    const overallDropoff = await ReadingAnalytics.aggregate([
      { $match: { userId: userId, isCompleted: false } },
      {
        $group: {
          _id: null,
          totalDropoffs: { $sum: 1 },
          avgChapterNumber: { $avg: '$chapterNumber' },
          avgCompletionPercentage: { $avg: '$completionPercentage' },
        },
      },
    ]);

    res.json({
      dropoffPoints: dropoffData,
      overall: overallDropoff[0] || {
        totalDropoffs: 0,
        avgChapterNumber: 0,
        avgCompletionPercentage: 0,
      },
    });
  } catch (error) {
    console.error('Get drop-off analysis error:', error);
    res.status(500).json({ message: 'Failed to fetch drop-off analysis' });
  }
});

module.exports = router;

