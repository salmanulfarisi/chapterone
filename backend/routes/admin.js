const express = require('express');
const mongoose = require('mongoose');
const Manga = require('../models/Manga');
const Chapter = require('../models/Chapter');
const User = require('../models/User');
const FeaturedManga = require('../models/FeaturedManga');
const ReadingHistory = require('../models/ReadingHistory');
const ReadingAnalytics = require('../models/ReadingAnalytics');
const ChapterUnlock = require('../models/ChapterUnlock');
const adminAuthMiddleware = require('../middleware/adminAuth');
const activityLogger = require('../services/activityLogger');
const firebaseFunctionsService = require('../services/firebaseFunctions');

const router = express.Router();

// All routes require admin authentication
router.use(adminAuthMiddleware);

// Manga Management
// Get all manga (including adult content) for admin
router.get('/manga', async (req, res) => {
  try {
    const {
      search,
      status,
      genre,
      type,
      sortBy = 'createdAt',
      sort = 'desc',
      limit,
      page = 1,
    } = req.query;

    // Build query - admins can see ALL manga including hotcomics
    const query = { isActive: true };
    
    // Add search filter
    if (search) {
      query.$or = [
        { title: { $regex: search, $options: 'i' } },
        { description: { $regex: search, $options: 'i' } },
        { author: { $regex: search, $options: 'i' } },
      ];
    }

    // Add status filter
    if (status) {
      query.status = status;
    }

    // Add genre filter
    if (genre) {
      query.genres = { $in: [genre] };
    }

    // Add type filter
    if (type) {
      query.type = type;
    }

    // Build sort
    const sortMap = {
      createdAt: { createdAt: sort === 'asc' ? 1 : -1 },
      rating: { rating: sort === 'asc' ? 1 : -1 },
      views: { totalViews: sort === 'asc' ? 1 : -1 },
      updatedAt: { updatedAt: sort === 'asc' ? 1 : -1 },
      title: { title: sort === 'asc' ? 1 : -1 },
    };
    const sortOptions = sortMap[sortBy] || sortMap.createdAt;

    // Calculate pagination
    // For admin, default to 50 manga per page to prevent timeouts
    // If limit is explicitly set, use it; otherwise use 50
    const pageNum = parseInt(page, 10) || 1;
    const limitNum = limit ? parseInt(limit, 10) : 50;
    const skip = (pageNum - 1) * limitNum;

    // Set timeout for the query (15 seconds - reduced for faster failure)
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Request timeout')), 15000);
    });

    // Optimize: Use projection to exclude heavy fields (chapters array)
    // Only fetch essential fields for the list view
    // Use exclusion-only projection to exclude heavy fields
    const projection = {
      chapters: 0, // Exclude chapters array to reduce data transfer
      description: 0, // Exclude description for list view
    };

    // Execute query with timeout - run countDocuments separately to avoid blocking
    const [manga, total] = await Promise.race([
      Promise.all([
        // Main query with projection to reduce data transfer
        Manga.find(query, projection)
          .sort(sortOptions)
          .skip(skip)
          .limit(limitNum)
          .lean()
          .maxTimeMS(10000), // 10 second max time for query
        // Use estimatedDocumentCount for faster counting (approximate but much faster)
        // Only use exact count if we're on the first page or if explicitly needed
        pageNum === 1 && !search
          ? Manga.countDocuments(query).maxTimeMS(5000)
          : Promise.resolve(null), // Skip count for subsequent pages to speed up
      ]),
      timeoutPromise
    ]);

    // If count is null (subsequent pages), estimate it
    let totalCount = total;
    if (totalCount === null) {
      // For subsequent pages, we can estimate or skip total count
      // This speeds up the query significantly
      totalCount = manga.length === limitNum ? (pageNum * limitNum) + 1 : (pageNum - 1) * limitNum + manga.length;
    }

    // Debug logging for admin
    console.log(`[Admin Manga] Query returned ${manga.length} manga out of ${totalCount} total. Limit: ${limitNum}, Page: ${pageNum}`);

    res.json({
      manga,
      total: totalCount,
      page: pageNum,
      limit: limitNum,
      totalPages: limitNum ? Math.ceil(totalCount / limitNum) : 1,
    });
  } catch (error) {
    console.error('Get admin manga error:', error);
    if (error.message === 'Request timeout') {
      res.status(504).json({ 
        message: 'Request timeout - try reducing the limit or using search',
        error: 'timeout',
        manga: [],
        total: 0,
        page: 1,
        limit: 100,
        totalPages: 0
      });
    } else {
      res.status(500).json({ 
        message: 'Failed to fetch manga',
        error: error.message,
        manga: [],
        total: 0,
        page: 1,
        limit: 100,
        totalPages: 0
      });
    }
  }
});

router.post('/manga', async (req, res) => {
  try {
    const manga = new Manga(req.body);
    await manga.save();
    
    // Log activity
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'manga_created',
        entityType: 'manga',
        entityId: manga._id.toString(),
        details: { title: manga.title },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }
    
    res.status(201).json(manga);
  } catch (error) {
    console.error('Create manga error:', error);
    res.status(500).json({ message: 'Failed to create manga' });
  }
});

router.put('/manga/:id', async (req, res) => {
  try {
    // Validate manga ID
    const mangaId = req.params.id;
    if (!mangaId || mangaId === 'null' || mangaId === 'undefined' || !mongoose.Types.ObjectId.isValid(mangaId)) {
      return res.status(400).json({ message: 'Invalid manga ID' });
    }

    // Only allow specific fields to be updated
    const allowedFields = ['title', 'description', 'cover', 'genres', 'status', 'type', 'author', 'artist', 'rating', 'releaseDate'];
    const updateData = {};
    for (const field of allowedFields) {
      if (req.body[field] !== undefined) {
        updateData[field] = req.body[field];
      }
    }
    
    const manga = await Manga.findByIdAndUpdate(
      mangaId,
      updateData,
      { new: true, runValidators: true }
    );
    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }
    
    // Log activity
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'manga_updated',
        entityType: 'manga',
        entityId: manga._id.toString(),
        details: { title: manga.title, updatedFields: Object.keys(updateData) },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }
    
    res.json(manga);
  } catch (error) {
    console.error('Update manga error:', error);
    res.status(500).json({ message: error.message || 'Failed to update manga' });
  }
});

router.delete('/manga/:id', async (req, res) => {
  try {
    const manga = await Manga.findById(req.params.id);
    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }
    
    await Manga.findByIdAndUpdate(req.params.id, { isActive: false });
    
    // Log activity
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'manga_deleted',
        entityType: 'manga',
        entityId: req.params.id,
        details: { title: manga.title },
        severity: 'warning',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }
    
    res.json({ message: 'Manga deleted' });
  } catch (error) {
    console.error('Delete manga error:', error);
    res.status(500).json({ message: 'Failed to delete manga' });
  }
});

// Chapter Management
router.post('/manga/:mangaId/chapters', async (req, res) => {
  try {
    const chapter = new Chapter({
      ...req.body,
      mangaId: req.params.mangaId,
    });
    await chapter.save();
    res.status(201).json(chapter);
  } catch (error) {
    console.error('Create chapter error:', error);
    res.status(500).json({ message: 'Failed to create chapter' });
  }
});

router.put('/chapters/:id', async (req, res) => {
  try {
    const chapter = await Chapter.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true }
    );
    res.json(chapter);
  } catch (error) {
    console.error('Update chapter error:', error);
    res.status(500).json({ message: 'Failed to update chapter' });
  }
});

router.delete('/chapters/:id', async (req, res) => {
  try {
    await Chapter.findByIdAndUpdate(req.params.id, { isActive: false });
    res.json({ message: 'Chapter deleted' });
  } catch (error) {
    console.error('Delete chapter error:', error);
    res.status(500).json({ message: 'Failed to delete chapter' });
  }
});

// User Management
router.get('/users', async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
      User.find().skip(skip).limit(limit).lean(),
      User.countDocuments(),
    ]);

    res.json({
      users,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ message: 'Failed to fetch users' });
  }
});

router.put('/users/:id', async (req, res) => {
  try {
    const { role, isActive } = req.body;
    const updateData = {};
    if (role) updateData.role = role;
    if (isActive !== undefined) updateData.isActive = isActive;

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { $set: updateData },
      { new: true }
    );

    res.json({ user });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ message: 'Failed to update user' });
  }
});

// Statistics
router.get('/stats/overview', async (req, res) => {
  try {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    // Set timeout for the entire operation (45 seconds - increased for large datasets)
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Request timeout')), 45000);
    });

    // Run all queries in parallel for better performance with timeout
    // Use aggregation to count chapters instead of fetching all manga documents
    const overviewData = await Promise.race([
      Promise.all([
        User.countDocuments({ isActive: { $ne: false } }),
        Manga.countDocuments({ isActive: true }),
        // Count embedded chapters using aggregation (much faster than fetching all documents)
        Manga.aggregate([
          { $match: { isActive: true } },
          { $project: { 
            chapterCount: { 
              $cond: [
                { $isArray: '$chapters' },
                { $size: { 
                  $filter: { 
                    input: '$chapters', 
                    as: 'ch', 
                    cond: { $ne: ['$$ch.isActive', false] }
                  }
                }},
                0
              ]
            }
          }},
          { $group: { _id: null, total: { $sum: '$chapterCount' } } }
        ]).allowDiskUse(true),
        // Legacy chapters from separate collection
        Chapter.countDocuments({ isActive: true }),
        // Optimized genre aggregation - use aggregation instead of fetching all
        Manga.aggregate([
          { $match: { isActive: true } },
          { $unwind: '$genres' },
          { $group: { _id: '$genres', count: { $sum: 1 } } },
          { $sort: { count: -1 } },
          { $limit: 6 }
        ]).allowDiskUse(true),
        // User growth (last 7 days)
        User.aggregate([
          {
            $match: {
              createdAt: { $gte: sevenDaysAgo }
            }
          },
          {
            $group: {
              _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
              count: { $sum: 1 }
            }
          },
          { $sort: { _id: 1 } }
        ]).allowDiskUse(true),
        // Reading activity (last 7 days) - from ReadingHistory
        ReadingHistory.aggregate([
          {
            $match: {
              lastRead: { $gte: sevenDaysAgo }
            }
          },
          {
            $group: {
              _id: { $dateToString: { format: '%Y-%m-%d', date: '$lastRead' } },
              count: { $sum: 1 }
            }
          },
          { $sort: { _id: 1 } }
        ]).allowDiskUse(true)
      ]),
      timeoutPromise
    ]);

    const [
      totalUsers,
      totalManga,
      embeddedChaptersResult,
      legacyChapters,
      popularGenresAgg,
      userGrowth,
      readingActivity
    ] = overviewData;

    // Calculate total chapters from aggregation result
    const embeddedChapters = embeddedChaptersResult[0]?.total || 0;
    const totalChapters = embeddedChapters + (legacyChapters || 0);

    // Format popular genres
    const popularGenres = popularGenresAgg.reduce((acc, item) => {
      acc[item._id] = item.count;
      return acc;
    }, {});

    // Format user growth data
    const userGrowthData = Array(7).fill(0);
    const today = new Date();
    userGrowth.forEach(item => {
      const itemDate = new Date(item._id);
      const daysAgo = Math.floor((today - itemDate) / (1000 * 60 * 60 * 24));
      if (daysAgo >= 0 && daysAgo < 7) {
        userGrowthData[6 - daysAgo] = item.count;
      }
    });

    // Format reading activity data
    const readingActivityData = Array(7).fill(0);
    readingActivity.forEach(item => {
      const itemDate = new Date(item._id);
      const daysAgo = Math.floor((today - itemDate) / (1000 * 60 * 60 * 24));
      if (daysAgo >= 0 && daysAgo < 7) {
        readingActivityData[6 - daysAgo] = item.count;
      }
    });

    res.json({
      totalUsers: totalUsers || 0,
      totalManga: totalManga || 0,
      totalChapters: totalChapters || 0,
      chartData: {
        userGrowth: userGrowthData || [],
        popularGenres: popularGenres || {},
        readingActivity: readingActivityData || [],
      },
    });
  } catch (error) {
    console.error('Get stats error:', error);
    // Return partial data if possible
    if (error.message === 'Request timeout') {
      res.status(504).json({ 
        message: 'Request timeout - data may be incomplete',
        error: 'timeout'
      });
    } else {
      res.status(500).json({ 
        message: 'Failed to fetch stats',
        error: error.message
      });
    }
  }
});

// Real-time user activity monitoring
router.get('/analytics/user-activity', async (req, res) => {
  try {
    const { timeframe = '24h' } = req.query; // 1h, 24h, 7d, 30d
    
    let startDate = new Date();
    switch (timeframe) {
      case '1h':
        startDate.setHours(startDate.getHours() - 1);
        break;
      case '24h':
        startDate.setHours(startDate.getHours() - 24);
        break;
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      default:
        startDate.setHours(startDate.getHours() - 24);
    }

    // Run all queries in parallel for better performance
    const [
      activeUsers,
      newUsers,
      readingSessions,
      totalReadingTime,
      hourlyActivity
    ] = await Promise.all([
      // Active users (users who read in the timeframe)
      ReadingHistory.distinct('userId', {
        lastRead: { $gte: startDate }
      }),
      // New users
      User.countDocuments({
        createdAt: { $gte: startDate }
      }),
      // Reading sessions
      ReadingAnalytics.countDocuments({
        sessionStart: { $gte: startDate }
      }),
      // Total reading time (in hours) - optimized aggregation
      ReadingAnalytics.aggregate([
        {
          $match: { sessionStart: { $gte: startDate } }
        },
        {
          $group: {
            _id: null,
            totalSeconds: { $sum: '$timeSpent' }
          }
        }
      ]),
      // Active users by hour (only for 24h timeframe)
      timeframe === '24h' || timeframe === '1h'
        ? ReadingAnalytics.aggregate([
            {
              $match: {
                sessionStart: {
                  $gte: new Date(Date.now() - 24 * 60 * 60 * 1000)
                }
              }
            },
            {
              $group: {
                _id: { $hour: '$sessionStart' },
                count: { $sum: 1 }
              }
            },
            { $sort: { _id: 1 } }
          ])
        : Promise.resolve([])
    ]);

    const totalHours = totalReadingTime[0]?.totalSeconds 
      ? (totalReadingTime[0].totalSeconds / 3600).toFixed(2)
      : 0;

    const hourlyData = Array(24).fill(0);
    hourlyActivity.forEach(item => {
      hourlyData[item._id] = item.count;
    });

    res.json({
      activeUsers: activeUsers.length,
      newUsers,
      readingSessions,
      totalReadingHours: parseFloat(totalHours),
      hourlyActivity: hourlyData,
      timeframe,
    });
  } catch (error) {
    console.error('Get user activity error:', error);
    res.status(500).json({ message: 'Failed to fetch user activity' });
  }
});

// Popular content analytics
router.get('/analytics/popular-content', async (req, res) => {
  try {
    const { limit = 10, timeframe = '30d' } = req.query;
    
    let startDate = new Date();
    switch (timeframe) {
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(startDate.getDate() - 90);
        break;
      default:
        startDate.setDate(startDate.getDate() - 30);
    }

    // Set timeout for the entire operation (20 seconds - reduced for faster response)
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Request timeout')), 20000);
    });

    // Run queries in parallel with timeout
    let mostRead = [];
    let popularGenresResult = [];
    
    try {
      [mostRead, popularGenresResult] = await Promise.race([
        Promise.all([
          // Most read manga - optimized with maxTimeMS
          ReadingHistory.aggregate([
            {
              $match: { 
                lastRead: { $gte: startDate },
                mangaId: { $exists: true, $ne: null }
              }
            },
            {
              $group: {
                _id: '$mangaId',
                readCount: { $sum: 1 },
                uniqueReaders: { $addToSet: '$userId' }
              }
            },
            {
              $project: {
                mangaId: '$_id',
                readCount: 1,
                uniqueReaders: { $size: '$uniqueReaders' }
              }
            },
            { $sort: { readCount: -1 } },
            { $limit: parseInt(limit, 10) || 10 }
          ], { allowDiskUse: true, maxTimeMS: 15000 }),
          // Most popular genres - skip if it's taking too long
          ReadingHistory.aggregate([
            {
              $match: { 
                lastRead: { $gte: startDate },
                mangaId: { $exists: true, $ne: null }
              }
            },
            {
              $lookup: {
                from: 'mangas',
                localField: 'mangaId',
                foreignField: '_id',
                as: 'manga',
                pipeline: [
                  { $project: { genres: 1 } }
                ]
              }
            },
            { $unwind: '$manga' },
            { $unwind: '$manga.genres' },
            {
              $group: {
                _id: '$manga.genres',
                count: { $sum: 1 }
              }
            },
            { $sort: { count: -1 } },
            { $limit: 10 }
          ], { allowDiskUse: true, maxTimeMS: 15000 })
        ]),
        timeoutPromise
      ]);
    } catch (err) {
      // If timeout or error, return empty arrays
      console.error('Popular content aggregation error:', err);
      mostRead = [];
      popularGenresResult = [];
    }

    // Populate manga details - with timeout protection
    const mangaIds = (mostRead || []).map(item => item.mangaId).filter(id => id && mongoose.Types.ObjectId.isValid(id));
    let mangaDetails = [];
    let mangaMap = {};
    
    if (mangaIds.length > 0) {
      try {
        // Set a shorter timeout for manga details fetch (5 seconds)
        const detailsTimeout = new Promise((_, reject) => {
          setTimeout(() => reject(new Error('Manga details timeout')), 5000);
        });
        
        mangaDetails = await Promise.race([
          Manga.find({ _id: { $in: mangaIds } })
            .select('title cover genres rating totalViews')
            .lean()
            .maxTimeMS(5000),
          detailsTimeout
        ]);
        
        mangaDetails.forEach(manga => {
          if (manga && manga._id) {
            mangaMap[manga._id.toString()] = manga;
          }
        });
      } catch (err) {
        console.error('Error fetching manga details:', err);
        // Continue with empty manga details - better than failing entirely
      }
    }

    const popularManga = (mostRead || []).map(item => {
      if (!item || !item.mangaId) return null;
      return {
        ...item,
        manga: mangaMap[item.mangaId.toString()] || null
      };
    }).filter(item => item !== null);

    const popularGenres = (popularGenresResult || []).map(item => ({
      genre: item._id || 'Unknown',
      readCount: item.count || 0
    }));

    res.json({
      popularManga: popularManga || [],
      popularGenres: popularGenres || [],
      timeframe,
    });
  } catch (error) {
    console.error('Get popular content error:', error);
    if (error.message === 'Request timeout') {
      res.status(504).json({ 
        message: 'Request timeout - data may be incomplete',
        error: 'timeout',
        popularManga: [],
        popularGenres: [],
        timeframe: req.query.timeframe || '30d'
      });
    } else {
      res.status(500).json({ 
        message: 'Failed to fetch popular content',
        error: error.message,
        popularManga: [],
        popularGenres: [],
        timeframe: req.query.timeframe || '30d'
      });
    }
  }
});

// User retention metrics
router.get('/analytics/user-retention', async (req, res) => {
  try {
    const { period = '30d' } = req.query;
    
    let startDate = new Date();
    switch (period) {
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(startDate.getDate() - 90);
        break;
      default:
        startDate.setDate(startDate.getDate() - 30);
    }

    // Run all retention queries in parallel
    const [
      dau,
      mau,
      newUsers,
      returningUsers,
      cohortData
    ] = await Promise.all([
      // Daily active users (DAU)
      ReadingHistory.aggregate([
        {
          $match: { lastRead: { $gte: startDate } }
        },
        {
          $group: {
            _id: { $dateToString: { format: '%Y-%m-%d', date: '$lastRead' } },
            uniqueUsers: { $addToSet: '$userId' }
          }
        },
        {
          $project: {
            date: '$_id',
            count: { $size: '$uniqueUsers' }
          }
        },
        { $sort: { date: 1 } }
      ]).allowDiskUse(true),
      // Monthly active users (MAU)
      ReadingHistory.distinct('userId', {
        lastRead: { $gte: startDate }
      }),
      // New users
      User.countDocuments({
        createdAt: { $gte: startDate }
      }),
      // Returning users - optimized
      ReadingHistory.aggregate([
        {
          $match: { lastRead: { $gte: startDate } }
        },
        {
          $lookup: {
            from: 'users',
            localField: 'userId',
            foreignField: '_id',
            as: 'user',
            pipeline: [
              { $project: { createdAt: 1 } }
            ]
          }
        },
        { $unwind: '$user' },
        {
          $match: {
            'user.createdAt': { $lt: startDate }
          }
        },
        {
          $group: {
            _id: '$userId'
          }
        }
      ]).allowDiskUse(true),
      // Retention cohorts - optimized
      User.aggregate([
        {
          $match: { createdAt: { $gte: startDate } }
        },
        {
          $lookup: {
            from: 'readinghistories',
            localField: '_id',
            foreignField: 'userId',
            as: 'readingHistory',
            pipeline: [
              { $limit: 1 } // Only need to check if exists
            ]
          }
        },
        {
          $project: {
            registeredDate: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
            hasActivity: { $gt: [{ $size: '$readingHistory' }, 0] }
          }
        },
        {
          $group: {
            _id: '$registeredDate',
            total: { $sum: 1 },
            active: {
              $sum: { $cond: ['$hasActivity', 1, 0] }
            }
          }
        },
        { $sort: { _id: 1 } }
      ]).allowDiskUse(true)
    ]);

    res.json({
      dailyActiveUsers: dau,
      monthlyActiveUsers: mau.length,
      newUsers,
      returningUsers: returningUsers.length,
      retentionRate: newUsers > 0 
        ? ((returningUsers.length / newUsers) * 100).toFixed(2)
        : 0,
      cohortData,
      period,
    });
  } catch (error) {
    console.error('Get user retention error:', error);
    res.status(500).json({ message: 'Failed to fetch user retention' });
  }
});

// Revenue analytics
router.get('/analytics/revenue', async (req, res) => {
  try {
    const { timeframe = '30d' } = req.query;
    
    let startDate = new Date();
    switch (timeframe) {
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(startDate.getDate() - 90);
        break;
      default:
        startDate.setDate(startDate.getDate() - 30);
    }

    // Ad revenue (estimated based on chapter unlocks via ads)
    const adUnlocks = await ChapterUnlock.countDocuments({
      unlockMethod: 'ad',
      unlockedAt: { $gte: startDate }
    });

    // Estimate revenue: assume $0.01 per ad view (this is configurable)
    const AD_REVENUE_PER_VIEW = 0.01;
    const estimatedAdRevenue = adUnlocks * AD_REVENUE_PER_VIEW;

    // Premium subscriptions (users with premium role or subscription)
    const premiumUsers = await User.countDocuments({
      $or: [
        { role: 'premium' },
        { 'subscription.isActive': true }
      ]
    });

    // Premium revenue (estimated: assume $4.99/month per premium user)
    const PREMIUM_MONTHLY_PRICE = 4.99;
    const estimatedPremiumRevenue = premiumUsers * PREMIUM_MONTHLY_PRICE;

    // Revenue breakdown by day
    const dailyRevenue = await ChapterUnlock.aggregate([
      {
        $match: {
          unlockMethod: 'ad',
          unlockedAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$unlockedAt' } },
          adViews: { $sum: 1 }
        }
      },
      {
        $project: {
          date: '$_id',
          adRevenue: { $multiply: ['$adViews', AD_REVENUE_PER_VIEW] }
        }
      },
      { $sort: { date: 1 } }
    ]);

    // Top revenue generating manga (by ad unlocks)
    const topRevenueManga = await ChapterUnlock.aggregate([
      {
        $match: {
          unlockMethod: 'ad',
          unlockedAt: { $gte: startDate }
        }
      },
      {
        $group: {
          _id: '$mangaId',
          adUnlocks: { $sum: 1 }
        }
      },
      {
        $project: {
          mangaId: '$_id',
          adUnlocks: 1,
          estimatedRevenue: { $multiply: ['$adUnlocks', AD_REVENUE_PER_VIEW] }
        }
      },
      { $sort: { adUnlocks: -1 } },
      { $limit: 10 }
    ]);

    // Populate manga details
    const revenueMangaIds = topRevenueManga.map(item => item.mangaId).filter(id => id);
    let revenueMangaDetails = [];
    let revenueMangaMap = {};
    
    if (revenueMangaIds.length > 0) {
      try {
        revenueMangaDetails = await Manga.find({ _id: { $in: revenueMangaIds } })
          .select('title cover')
          .lean();

        revenueMangaDetails.forEach(manga => {
          revenueMangaMap[manga._id.toString()] = manga;
        });
      } catch (err) {
        console.error('Error fetching revenue manga details:', err);
      }
    }

    const topRevenueMangaWithDetails = topRevenueManga.map(item => ({
      ...item,
      manga: revenueMangaMap[item.mangaId?.toString()] || null
    }));

    res.json({
      adRevenue: {
        total: estimatedAdRevenue.toFixed(2),
        unlocks: adUnlocks,
        revenuePerView: AD_REVENUE_PER_VIEW
      },
      premiumRevenue: {
        total: estimatedPremiumRevenue.toFixed(2),
        subscribers: premiumUsers,
        monthlyPrice: PREMIUM_MONTHLY_PRICE
      },
      totalRevenue: (estimatedAdRevenue + estimatedPremiumRevenue).toFixed(2),
      dailyRevenue,
      topRevenueManga: topRevenueMangaWithDetails,
      timeframe,
    });
  } catch (error) {
    console.error('Get revenue analytics error:', error);
    res.status(500).json({ message: 'Failed to fetch revenue analytics' });
  }
});

// Content performance metrics
router.get('/analytics/content-performance', async (req, res) => {
  try {
    const { limit = 20, timeframe = '30d' } = req.query;
    
    let startDate = new Date();
    switch (timeframe) {
      case '7d':
        startDate.setDate(startDate.getDate() - 7);
        break;
      case '30d':
        startDate.setDate(startDate.getDate() - 30);
        break;
      case '90d':
        startDate.setDate(startDate.getDate() - 90);
        break;
      default:
        startDate.setDate(startDate.getDate() - 30);
    }

    // Set timeout for the entire operation (30 seconds)
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Request timeout')), 30000);
    });

    // Run both aggregations in parallel for better performance with timeout
    const [mangaPerformanceResult, completionRatesResult] = await Promise.race([
      Promise.all([
        // Manga performance metrics
        ReadingHistory.aggregate([
          {
            $match: { 
              lastRead: { $gte: startDate },
              mangaId: { $exists: true, $ne: null }
            }
          },
          {
            $group: {
              _id: '$mangaId',
              totalReads: { $sum: 1 },
              uniqueReaders: { $addToSet: '$userId' },
              avgChaptersRead: { $avg: '$chaptersRead' }
            }
          },
          {
            $project: {
              mangaId: '$_id',
              totalReads: 1,
              uniqueReaders: { $size: '$uniqueReaders' },
              avgChaptersRead: { $round: ['$avgChaptersRead', 2] }
            }
          },
          { $sort: { totalReads: -1 } },
          { $limit: parseInt(limit, 10) || 20 }
        ]).allowDiskUse(true),
        // Get completion rates from ReadingAnalytics
        ReadingAnalytics.aggregate([
          {
            $match: { 
              sessionStart: { $gte: startDate },
              mangaId: { $exists: true, $ne: null }
            }
          },
          {
            $group: {
              _id: '$mangaId',
              totalSessions: { $sum: 1 },
              completedSessions: {
                $sum: { $cond: ['$isCompleted', 1, 0] }
              },
              avgCompletionPercentage: { $avg: '$completionPercentage' },
              avgTimeSpent: { $avg: '$timeSpent' }
            }
          },
          {
            $project: {
              mangaId: '$_id',
              totalSessions: 1,
              completedSessions: 1,
              completionRate: {
                $multiply: [
                  { $divide: ['$completedSessions', '$totalSessions'] },
                  100
                ]
              },
              avgCompletionPercentage: { $round: ['$avgCompletionPercentage', 2] },
              avgTimeSpent: { $round: ['$avgTimeSpent', 0] }
            }
          }
        ]).allowDiskUse(true)
      ]),
      timeoutPromise
    ]);

    const mangaPerformance = mangaPerformanceResult || [];
    const completionRates = completionRatesResult || [];

    // Merge performance data
    const performanceMap = {};
    mangaPerformance.forEach(item => {
      if (item.mangaId) {
        performanceMap[item.mangaId.toString()] = item;
      }
    });

    completionRates.forEach(item => {
      if (item.mangaId) {
        const key = item.mangaId.toString();
        if (performanceMap[key]) {
          performanceMap[key] = {
            ...performanceMap[key],
            ...item
          };
        }
      }
    });

    // Get manga IDs for details fetch (will be fetched in parallel with avgMetrics)
    const mangaIds = Object.keys(performanceMap)
      .filter(id => mongoose.Types.ObjectId.isValid(id))
      .map(id => new mongoose.Types.ObjectId(id));

    // Average metrics across all content - run in parallel with manga details fetch
    const [avgMetricsResult, mangaDetailsResult] = await Promise.all([
      ReadingHistory.aggregate([
        {
          $match: { lastRead: { $gte: startDate } }
        },
        {
          $group: {
            _id: null,
            avgChaptersRead: { $avg: '$chaptersRead' },
            totalReads: { $sum: 1 }
          }
        }
      ]).allowDiskUse(true),
      // Populate manga details
      mangaIds.length > 0 && mongoose.Types.ObjectId.isValid(mangaIds[0])
        ? Manga.find({ _id: { $in: mangaIds } })
            .select('title cover genres rating totalViews status createdAt')
            .lean()
        : Promise.resolve([])
    ]);

    const avgMetrics = avgMetricsResult || [];
    let mangaDetails = mangaDetailsResult || [];
    let mangaDetailsMap = {};

    mangaDetails.forEach(manga => {
      mangaDetailsMap[manga._id.toString()] = manga;
    });

    const contentPerformance = Object.values(performanceMap)
      .map(item => ({
        ...item,
        manga: mangaDetailsMap[item.mangaId?.toString()] || null
      }))
      .sort((a, b) => (b.totalReads || 0) - (a.totalReads || 0));

    res.json({
      contentPerformance: contentPerformance || [],
      averageMetrics: {
        avgChaptersRead: avgMetrics[0]?.avgChaptersRead?.toFixed(2) || '0',
        totalReads: avgMetrics[0]?.totalReads || 0
      },
      timeframe,
    });
  } catch (error) {
    console.error('Get content performance error:', error);
    if (error.message === 'Request timeout') {
      res.status(504).json({ 
        message: 'Request timeout - data may be incomplete',
        error: 'timeout',
        contentPerformance: [],
        averageMetrics: {
          avgChaptersRead: '0',
          totalReads: 0
        },
        timeframe: req.query.timeframe || '30d'
      });
    } else {
      res.status(500).json({ 
        message: 'Failed to fetch content performance',
        error: error.message,
        contentPerformance: [],
        averageMetrics: {
          avgChaptersRead: '0',
          totalReads: 0
        },
        timeframe: req.query.timeframe || '30d'
      });
    }
  }
});

// ==================== Featured Manga Management ====================

// Get all featured manga
router.get('/featured', async (req, res) => {
  try {
    const { type } = req.query;
    const query = { isActive: true };
    if (type) query.type = type;

    const featured = await FeaturedManga.find(query)
      .populate('mangaId', 'title cover rating status genres updatedAt')
      .sort({ priority: -1, createdAt: -1 })
      .lean();

    // Filter out expired ones and clean up
    const now = new Date();
    const validFeatured = featured.filter(f => {
      if (f.expiresAt && new Date(f.expiresAt) < now) return false;
      return f.mangaId != null;
    });

    res.json(validFeatured);
  } catch (error) {
    console.error('Get featured error:', error);
    res.status(500).json({ message: 'Failed to fetch featured manga' });
  }
});

// Add manga to featured
router.post('/featured', async (req, res) => {
  try {
    const { mangaId, type = 'carousel', priority = 0, expiresAt } = req.body;

    // Check if manga exists
    const manga = await Manga.findById(mangaId);
    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    // Check if already featured
    const existing = await FeaturedManga.findOne({ mangaId, type });
    if (existing) {
      // Update existing
      existing.priority = priority;
      existing.isActive = true;
      existing.isManual = true;
      existing.expiresAt = expiresAt || null;
      await existing.save();
      
      const populated = await FeaturedManga.findById(existing._id)
        .populate('mangaId', 'title cover rating status genres');
      return res.json(populated);
    }

    // Create new featured entry
    const featured = new FeaturedManga({
      mangaId,
      type,
      priority,
      isManual: true,
      expiresAt: expiresAt || null,
    });
    await featured.save();

    const populated = await FeaturedManga.findById(featured._id)
      .populate('mangaId', 'title cover rating status genres');

    res.status(201).json(populated);
  } catch (error) {
    console.error('Add featured error:', error);
    res.status(500).json({ message: 'Failed to add featured manga' });
  }
});

// Update featured manga
router.put('/featured/:id', async (req, res) => {
  try {
    const { priority, isActive, expiresAt } = req.body;
    const updateData = {};
    
    if (priority !== undefined) updateData.priority = priority;
    if (isActive !== undefined) updateData.isActive = isActive;
    if (expiresAt !== undefined) updateData.expiresAt = expiresAt;

    const featured = await FeaturedManga.findByIdAndUpdate(
      req.params.id,
      updateData,
      { new: true }
    ).populate('mangaId', 'title cover rating status genres');

    if (!featured) {
      return res.status(404).json({ message: 'Featured entry not found' });
    }

    res.json(featured);
  } catch (error) {
    console.error('Update featured error:', error);
    res.status(500).json({ message: 'Failed to update featured manga' });
  }
});

// Remove from featured
router.delete('/featured/:id', async (req, res) => {
  try {
    await FeaturedManga.findByIdAndDelete(req.params.id);
    res.json({ message: 'Removed from featured' });
  } catch (error) {
    console.error('Delete featured error:', error);
    res.status(500).json({ message: 'Failed to remove from featured' });
  }
});

// Auto-add recently updated manga to carousel (cron job or manual trigger)
router.post('/featured/auto-update', async (req, res) => {
  try {
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    const oneWeekFromNow = new Date();
    oneWeekFromNow.setDate(oneWeekFromNow.getDate() + 7);

    // Find manga updated in the last week with new chapters
    const recentlyUpdated = await Manga.find({
      isActive: true,
      updatedAt: { $gte: oneWeekAgo },
    })
      .sort({ updatedAt: -1 })
      .limit(10)
      .lean();

    let added = 0;
    for (const manga of recentlyUpdated) {
      const existing = await FeaturedManga.findOne({ 
        mangaId: manga._id, 
        type: 'carousel' 
      });
      
      if (!existing) {
        await FeaturedManga.create({
          mangaId: manga._id,
          type: 'carousel',
          priority: 0,
          isManual: false,
          expiresAt: oneWeekFromNow, // Auto-expire in 1 week
        });
        added++;
      }
    }

    // Clean up expired entries
    await FeaturedManga.deleteMany({
      isManual: false,
      expiresAt: { $lt: new Date() },
    });

    res.json({ message: `Auto-update complete. Added ${added} manga to carousel.` });
  } catch (error) {
    console.error('Auto-update featured error:', error);
    res.status(500).json({ message: 'Failed to auto-update featured' });
  }
});

// Search manga for adding to featured
router.get('/manga/search', async (req, res) => {
  try {
    const { q } = req.query;
    if (!q) {
      return res.json([]);
    }

    const manga = await Manga.find({
      isActive: true,
      $or: [
        { title: { $regex: q, $options: 'i' } },
      ],
    })
      .select('title cover rating status')
      .limit(20)
      .lean();

    res.json(manga);
  } catch (error) {
    console.error('Search manga error:', error);
    res.status(500).json({ message: 'Failed to search manga' });
  }
});

// ==================== Activity Logs ====================

// Get activity logs
router.get('/logs', async (req, res) => {
  try {
    const {
      userId,
      action,
      entityType,
      entityId,
      severity,
      startDate,
      endDate,
      limit = 100,
      skip = 0,
    } = req.query;

    const result = await activityLogger.getActivityLogs({
      userId,
      action,
      entityType,
      entityId,
      severity,
      startDate,
      endDate,
      limit: parseInt(limit),
      skip: parseInt(skip),
    });

    res.json(result);
  } catch (error) {
    console.error('Get activity logs error:', error);
    res.status(500).json({ message: 'Failed to fetch activity logs' });
  }
});

// Get system health stats
router.get('/logs/health', async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 7;
    const stats = await activityLogger.getSystemHealthStats(days);
    res.json(stats);
  } catch (error) {
    console.error('Get system health error:', error);
    res.status(500).json({ message: 'Failed to fetch system health' });
  }
});


// ==================== Bulk Operations ====================

// Bulk update manga
router.post('/manga/bulk-update', async (req, res) => {
  try {
    const { mangaIds, updateData } = req.body;

    if (!mangaIds || !Array.isArray(mangaIds) || mangaIds.length === 0) {
      return res.status(400).json({ message: 'mangaIds array is required' });
    }

    if (!updateData || typeof updateData !== 'object') {
      return res.status(400).json({ message: 'updateData object is required' });
    }

    // Only allow specific fields
    const allowedFields = ['status', 'genres', 'isActive'];
    const filteredUpdate = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        filteredUpdate[field] = updateData[field];
      }
    }

    const result = await Manga.updateMany(
      { _id: { $in: mangaIds } },
      { $set: filteredUpdate }
    );

    // Log the bulk operation
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'manga_updated',
        entityType: 'manga',
        details: {
          count: mangaIds.length,
          updateData: filteredUpdate,
          modifiedCount: result.modifiedCount,
        },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

    res.json({
      message: 'Bulk update completed',
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('Bulk update manga error:', error);
    res.status(500).json({ message: 'Failed to bulk update manga' });
  }
});

// Bulk delete manga
router.post('/manga/bulk-delete', async (req, res) => {
  try {
    const { mangaIds } = req.body;

    if (!mangaIds || !Array.isArray(mangaIds) || mangaIds.length === 0) {
      return res.status(400).json({ message: 'mangaIds array is required' });
    }

    const result = await Manga.updateMany(
      { _id: { $in: mangaIds } },
      { $set: { isActive: false } }
    );

    // Log the bulk operation
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'manga_deleted',
        entityType: 'manga',
        details: {
          count: mangaIds.length,
          modifiedCount: result.modifiedCount,
        },
        severity: 'warning',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

    res.json({
      message: 'Bulk delete completed',
      deletedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('Bulk delete manga error:', error);
    res.status(500).json({ message: 'Failed to bulk delete manga' });
  }
});

// Bulk update users
router.post('/users/bulk-update', async (req, res) => {
  try {
    const { userIds, updateData } = req.body;

    if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
      return res.status(400).json({ message: 'userIds array is required' });
    }

    if (!updateData || typeof updateData !== 'object') {
      return res.status(400).json({ message: 'updateData object is required' });
    }

    // Only allow specific fields
    const allowedFields = ['isActive', 'role'];
    const filteredUpdate = {};
    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        filteredUpdate[field] = updateData[field];
      }
    }

    const result = await User.updateMany(
      { _id: { $in: userIds } },
      { $set: filteredUpdate }
    );

    // Log the bulk operation
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'user_updated',
        entityType: 'user',
        details: {
          count: userIds.length,
          updateData: filteredUpdate,
          modifiedCount: result.modifiedCount,
        },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

    res.json({
      message: 'Bulk update completed',
      modifiedCount: result.modifiedCount,
    });
  } catch (error) {
    console.error('Bulk update users error:', error);
    res.status(500).json({ message: 'Failed to bulk update users' });
  }
});

// ==================== Notification Management ====================

// Get Firebase Functions configuration (for debugging)
router.get('/notifications/config', async (req, res) => {
  try {
    const config = firebaseFunctionsService.getConfig();
    res.json({
      ...config,
      deployedFunctions: [
        'sendNotification',
        'sendBulkNotifications',
        'notifyNewChapter',
        'notifyNewManga',
      ],
    });
  } catch (error) {
    console.error('Get notification config error:', error);
    res.status(500).json({ message: 'Failed to get configuration' });
  }
});

// Send notification to a specific user
router.post('/notifications/send', async (req, res) => {
  try {
    const { userId, title, body, data = {} } = req.body;

    if (!userId || !title || !body) {
      return res.status(400).json({ 
        message: 'userId, title, and body are required' 
      });
    }

    // Get user and their FCM token
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if user has FCM token
    if (!user.fcmToken) {
      return res.status(400).json({ 
        message: 'User does not have an FCM token registered' 
      });
    }

    // Send notification via Firebase Functions
    const result = await firebaseFunctionsService.sendNotification(
      userId,
      user.fcmToken,
      title,
      body,
      data
    );

    if (!result.success) {
      return res.status(500).json({ 
        message: 'Failed to send notification',
        error: result.error 
      });
    }

    // Log activity
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'notification_sent',
        entityType: 'notification',
        entityId: userId,
        details: { title, body, targetUserId: userId },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

    res.json({ 
      success: true, 
      message: 'Notification sent successfully',
      data: result.data 
    });
  } catch (error) {
    console.error('Send notification error:', error);
    res.status(500).json({ message: 'Failed to send notification' });
  }
});

// Send notification to all users (bulk)
router.post('/notifications/send-bulk', async (req, res) => {
  try {
    const { title, body, data = {} } = req.body;

    if (!title || !body) {
      return res.status(400).json({ 
        message: 'title and body are required' 
      });
    }

    // Get all users with FCM tokens (for admin bulk notifications, send to all)
    const users = await User.find({
      fcmToken: { $exists: true, $ne: null, $ne: '' },
      isActive: { $ne: false },
    }).select('fcmToken').lean();

    if (users.length === 0) {
      return res.status(400).json({ 
        message: 'No users with FCM tokens found' 
      });
    }

    // Extract FCM tokens
    const tokens = users.map(user => user.fcmToken).filter(Boolean);

    if (tokens.length === 0) {
      return res.status(400).json({ 
        message: 'No valid FCM tokens found' 
      });
    }

    // Send bulk notification via Firebase Functions
    const result = await firebaseFunctionsService.sendBulkNotifications(
      tokens,
      title,
      body,
      data
    );

    if (!result.success) {
      return res.status(500).json({ 
        message: 'Failed to send notifications',
        error: result.error 
      });
    }

    // Log activity
    try {
      await activityLogger.logActivity({
        userId: req.user._id,
        action: 'notification_sent',
        entityType: 'notification',
        details: { 
          title, 
          body, 
          targetCount: tokens.length,
          successCount: result.data?.successCount || 0,
          failureCount: result.data?.failureCount || 0,
        },
        severity: 'info',
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

    res.json({ 
      success: true, 
      message: `Notification sent to ${tokens.length} users`,
      data: result.data 
    });
  } catch (error) {
    console.error('Send bulk notification error:', error);
    res.status(500).json({ message: 'Failed to send bulk notifications' });
  }
});

// ==================== Feedback & Requests Management ====================

const Feedback = require('../models/Feedback');

// Get all feedback/requests
router.get('/feedback', async (req, res) => {
  try {
    const { type, status, page = 1, limit = 50 } = req.query;
    const query = {};
    
    if (type) query.type = type;
    if (status) query.status = status;

    const skip = (parseInt(page) - 1) * parseInt(limit);
    
    const [feedbacks, total] = await Promise.all([
      Feedback.find(query)
        .populate('userId', 'username email')
        .populate('mangaId', 'title cover')
        .populate('reviewedBy', 'username')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(parseInt(limit))
        .lean(),
      Feedback.countDocuments(query),
    ]);

    res.json({
      feedbacks,
      total,
      page: parseInt(page),
      limit: parseInt(limit),
      totalPages: Math.ceil(total / parseInt(limit)),
    });
  } catch (error) {
    console.error('Get feedback error:', error);
    res.status(500).json({ message: 'Failed to fetch feedback' });
  }
});

// Get feedback by ID
router.get('/feedback/:id', async (req, res) => {
  try {
    const feedback = await Feedback.findById(req.params.id)
      .populate('userId', 'username email')
      .populate('mangaId', 'title cover')
      .populate('reviewedBy', 'username')
      .lean();

    if (!feedback) {
      return res.status(404).json({ message: 'Feedback not found' });
    }

    res.json(feedback);
  } catch (error) {
    console.error('Get feedback by ID error:', error);
    res.status(500).json({ message: 'Failed to fetch feedback' });
  }
});

// Update feedback status
router.put('/feedback/:id', async (req, res) => {
  try {
    const { status, adminNotes } = req.body;

    const feedback = await Feedback.findById(req.params.id);
    if (!feedback) {
      return res.status(404).json({ message: 'Feedback not found' });
    }

    if (status) {
      if (!['pending', 'reviewed', 'resolved', 'rejected'].includes(status)) {
        return res.status(400).json({ message: 'Invalid status' });
      }
      feedback.status = status;
    }

    if (adminNotes !== undefined) {
      feedback.adminNotes = adminNotes?.trim() || null;
    }

    if (status && status !== 'pending') {
      feedback.reviewedBy = req.user._id;
      feedback.reviewedAt = new Date();
    }

    await feedback.save();
    await feedback.populate('userId', 'username email');
    await feedback.populate('mangaId', 'title cover');
    await feedback.populate('reviewedBy', 'username');

    res.json(feedback);
  } catch (error) {
    console.error('Update feedback error:', error);
    res.status(500).json({ message: 'Failed to update feedback' });
  }
});

// Delete feedback
router.delete('/feedback/:id', async (req, res) => {
  try {
    const feedback = await Feedback.findByIdAndDelete(req.params.id);
    if (!feedback) {
      return res.status(404).json({ message: 'Feedback not found' });
    }

    res.json({ message: 'Feedback deleted' });
  } catch (error) {
    console.error('Delete feedback error:', error);
    res.status(500).json({ message: 'Failed to delete feedback' });
  }
});

// Get feedback statistics
router.get('/feedback/stats', async (req, res) => {
  try {
    const [total, pending, byType, byStatus] = await Promise.all([
      Feedback.countDocuments(),
      Feedback.countDocuments({ status: 'pending' }),
      Feedback.aggregate([
        { $group: { _id: '$type', count: { $sum: 1 } } }
      ]),
      Feedback.aggregate([
        { $group: { _id: '$status', count: { $sum: 1 } } }
      ]),
    ]);

    res.json({
      total,
      pending,
      byType: byType.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
      byStatus: byStatus.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
    });
  } catch (error) {
    console.error('Get feedback stats error:', error);
    res.status(500).json({ message: 'Failed to fetch feedback statistics' });
  }
});

// Debug endpoint to check admin FCM tokens
router.get('/feedback/debug-admins', async (req, res) => {
  try {
    const User = require('../models/User');
    const firebaseFunctionsService = require('../services/firebaseFunctions');
    
    const allAdmins = await User.find({
      role: { $in: ['admin', 'super_admin'] },
    }).select('fcmToken email username role').lean();
    
    const adminsWithTokens = allAdmins.filter(a => a.fcmToken && a.fcmToken.trim() !== '');
    
    res.json({
      totalAdmins: allAdmins.length,
      adminsWithTokens: adminsWithTokens.length,
      firebaseConfigured: firebaseFunctionsService.isConfigured(),
      admins: allAdmins.map(a => ({
        email: a.email,
        username: a.username,
        role: a.role,
        hasFcmToken: !!a.fcmToken,
        tokenPreview: a.fcmToken ? a.fcmToken.substring(0, 30) + '...' : null,
      })),
    });
  } catch (error) {
    console.error('Debug admins error:', error);
    res.status(500).json({ message: 'Failed to debug admins', error: error.message });
  }
});

module.exports = router;

