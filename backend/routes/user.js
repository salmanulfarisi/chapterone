const express = require('express');
const mongoose = require('mongoose');
const User = require('../models/User');
const ReadingHistory = require('../models/ReadingHistory');
const Bookmark = require('../models/Bookmark');
const Rating = require('../models/Rating');
const Manga = require('../models/Manga');
const Chapter = require('../models/Chapter');
const ReadingList = require('../models/ReadingList');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');

const router = express.Router();

// Get user profile
router.get('/profile', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    res.json({ user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ message: 'Failed to fetch profile' });
  }
});

// Update user profile
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { username, profile, preferences } = req.body;
    
    const updateData = {};
    if (username) updateData.username = username;
    if (profile) updateData.profile = profile;
    if (preferences) updateData.preferences = preferences;

    const user = await User.findByIdAndUpdate(
      req.user._id,
      { $set: updateData },
      { new: true }
    );

    res.json({ user });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ message: 'Failed to update profile' });
  }
});

// Get reading history
router.get('/reading-history', authMiddleware, async (req, res) => {
  try {
    const history = await ReadingHistory.find({ userId: req.user._id })
      .populate('mangaId', 'title cover')
      .sort({ lastRead: -1 })
      .limit(50)
      .lean();

    // Manually populate chapter data from embedded chapters
    const historyWithChapters = await Promise.all(
      history.map(async (item) => {
        const chapterData = {
          _id: item.chapterId,
          chapterNumber: null,
          title: null,
        };

        // If chapterId is in new format (mangaId_chapterNumber)
        if (item.chapterId && item.chapterId.includes('_ch')) {
          const [mangaIdStr, chapterNumStr] = item.chapterId.split('_ch');
          const chapterNum = parseInt(chapterNumStr, 10);
          
          if (item.mangaId && item.mangaId._id) {
            const manga = await Manga.findById(item.mangaId._id).lean();
            if (manga && manga.chapters) {
              const embeddedChapter = manga.chapters.find(
                ch => ch.chapterNumber === chapterNum && ch.isActive !== false
              );
              if (embeddedChapter) {
                chapterData.chapterNumber = embeddedChapter.chapterNumber;
                chapterData.title = embeddedChapter.title || `Chapter ${embeddedChapter.chapterNumber}`;
              }
            }
          }
        } else if (item.chapterId && mongoose.Types.ObjectId.isValid(item.chapterId)) {
          // Legacy chapter ID - try to fetch from Chapter collection
          try {
            const legacyChapter = await Chapter.findById(item.chapterId)
              .select('chapterNumber title')
              .lean();
            if (legacyChapter) {
              chapterData.chapterNumber = legacyChapter.chapterNumber;
              chapterData.title = legacyChapter.title;
            }
          } catch (e) {
            // Legacy chapter not found, keep null values
          }
        }

        return {
          ...item,
          chapterId: chapterData,
        };
      })
    );

    res.json(historyWithChapters);
  } catch (error) {
    console.error('Get reading history error:', error);
    res.status(500).json({ message: 'Failed to fetch reading history' });
  }
});

// Update FCM token for push notifications
router.post('/fcm-token', authMiddleware, async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) {
      return res.status(400).json({ message: 'FCM token is required' });
    }

    if (typeof token !== 'string' || token.trim().length === 0) {
      return res.status(400).json({ message: 'FCM token must be a non-empty string' });
    }

    console.log(`Updating FCM token for user ${req.user._id}: ${token.substring(0, 20)}...`);
    const updatedUser = await User.findByIdAndUpdate(
      req.user._id, 
      { fcmToken: token.trim() },
      { new: true }
    ).select('fcmToken email');
    
    if (!updatedUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    console.log(`FCM token updated successfully for user ${req.user._id} (${updatedUser.email})`);
    console.log(`Token saved: ${updatedUser.fcmToken ? 'Yes' : 'No'}`);
    
    res.json({ 
      message: 'FCM token updated',
      tokenSaved: !!updatedUser.fcmToken,
    });
  } catch (error) {
    console.error('Update FCM token error:', error);
    res.status(500).json({ message: 'Failed to update FCM token', error: error.message });
  }
});

// Update reading streak (called when user reads a chapter)
router.post('/update-streak', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const lastReadDate = user.readingStreak?.lastReadDate 
      ? new Date(user.readingStreak.lastReadDate)
      : null;
    
    if (lastReadDate) {
      lastReadDate.setHours(0, 0, 0, 0);
    }

    const daysDiff = lastReadDate 
      ? Math.floor((today - lastReadDate) / (1000 * 60 * 60 * 24))
      : null;

    let currentStreak = user.readingStreak?.currentStreak || 0;
    let longestStreak = user.readingStreak?.longestStreak || 0;

    if (!lastReadDate || daysDiff === 1) {
      // Continue streak (read yesterday or today)
      currentStreak = daysDiff === 1 ? currentStreak + 1 : (currentStreak === 0 ? 1 : currentStreak);
    } else if (daysDiff === 0) {
      // Same day, don't increment
      currentStreak = currentStreak || 1;
    } else {
      // Streak broken, reset to 1
      currentStreak = 1;
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    user.readingStreak = {
      currentStreak,
      longestStreak,
      lastReadDate: today,
    };

    await user.save();

    res.json({
      currentStreak,
      longestStreak,
      lastReadDate: today,
    });
  } catch (error) {
    console.error('Update reading streak error:', error);
    res.status(500).json({ message: 'Failed to update reading streak' });
  }
});

// Get user stats
router.get('/stats', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;

    // Get counts in parallel
    const [
      bookmarksCount,
      ratingsCount,
      readingHistoryCount,
      totalChaptersRead,
      recentHistory
    ] = await Promise.all([
      Bookmark.countDocuments({ userId }),
      Rating.countDocuments({ userId }),
      ReadingHistory.countDocuments({ userId }),
      ReadingHistory.aggregate([
        { $match: { userId } },
        { $group: { _id: null, total: { $sum: '$chaptersRead' } } }
      ]),
      ReadingHistory.find({ userId })
        .populate('mangaId', 'title cover')
        .sort({ lastRead: -1 })
        .limit(5)
        .lean()
    ]);

    // Get user's average rating given
    const avgRating = await Rating.aggregate([
      { $match: { userId } },
      { $group: { _id: null, avg: { $avg: '$rating' } } }
    ]);

    // Get reading streak
    const user = await User.findById(userId).select('readingStreak').lean();
    const readingStreak = user?.readingStreak || {
      currentStreak: 0,
      longestStreak: 0,
      lastReadDate: null,
    };

    res.json({
      bookmarksCount,
      ratingsCount,
      mangaRead: readingHistoryCount,
      chaptersRead: totalChaptersRead[0]?.total || 0,
      avgRatingGiven: avgRating[0]?.avg || 0,
      recentlyRead: recentHistory,
      memberSince: req.user.createdAt,
      readingStreak: readingStreak.currentStreak || 0,
      longestStreak: readingStreak.longestStreak || 0,
    });
  } catch (error) {
    console.error('Get user stats error:', error);
    res.status(500).json({ message: 'Failed to fetch user stats' });
  }
});

// ==================== Reading Lists ====================

// Get all reading lists for user
router.get('/reading-lists', authMiddleware, async (req, res) => {
  try {
    const lists = await ReadingList.find({ userId: req.user._id })
      .populate('mangaIds', 'title cover rating genres')
      .sort({ isDefault: -1, createdAt: -1 })
      .lean();

    res.json(lists);
  } catch (error) {
    console.error('Get reading lists error:', error);
    res.status(500).json({ message: 'Failed to fetch reading lists' });
  }
});

// Create reading list
router.post('/reading-lists', authMiddleware, async (req, res) => {
  try {
    const { name, description, mangaIds, isPublic, listType } = req.body;

    if (!name || name.trim().isEmpty) {
      return res.status(400).json({ message: 'List name is required' });
    }

    // Check if list with same name exists
    const existing = await ReadingList.findOne({
      userId: req.user._id,
      name: name.trim(),
    });

    if (existing) {
      return res.status(400).json({ message: 'List with this name already exists' });
    }

    const list = new ReadingList({
      userId: req.user._id,
      name: name.trim(),
      description: description || '',
      mangaIds: mangaIds || [],
      isPublic: isPublic || false,
      listType: listType || 'custom',
    });

    await list.save();
    await list.populate('mangaIds', 'title cover rating genres');

    res.status(201).json(list);
  } catch (error) {
    console.error('Create reading list error:', error);
    res.status(500).json({ message: 'Failed to create reading list' });
  }
});

// Update reading list
router.put('/reading-lists/:id', authMiddleware, async (req, res) => {
  try {
    const { name, description, mangaIds, isPublic } = req.body;
    const listId = req.params.id;

    const list = await ReadingList.findOne({
      _id: listId,
      userId: req.user._id,
    });

    if (!list) {
      return res.status(404).json({ message: 'Reading list not found' });
    }

    if (name) list.name = name.trim();
    if (description !== undefined) list.description = description;
    if (mangaIds !== undefined) list.mangaIds = mangaIds;
    if (isPublic !== undefined) list.isPublic = isPublic;

    await list.save();
    await list.populate('mangaIds', 'title cover rating genres');

    res.json(list);
  } catch (error) {
    console.error('Update reading list error:', error);
    res.status(500).json({ message: 'Failed to update reading list' });
  }
});

// Delete reading list
router.delete('/reading-lists/:id', authMiddleware, async (req, res) => {
  try {
    const list = await ReadingList.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!list) {
      return res.status(404).json({ message: 'Reading list not found' });
    }

    if (list.isDefault) {
      return res.status(400).json({ message: 'Cannot delete default list' });
    }

    await ReadingList.findByIdAndDelete(req.params.id);
    res.json({ message: 'Reading list deleted' });
  } catch (error) {
    console.error('Delete reading list error:', error);
    res.status(500).json({ message: 'Failed to delete reading list' });
  }
});

// Add manga to list
router.post('/reading-lists/:id/manga', authMiddleware, async (req, res) => {
  try {
    const { mangaId } = req.body;
    if (!mangaId) {
      return res.status(400).json({ message: 'mangaId is required' });
    }

    const list = await ReadingList.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!list) {
      return res.status(404).json({ message: 'Reading list not found' });
    }

    if (!list.mangaIds.includes(mangaId)) {
      list.mangaIds.push(mangaId);
      await list.save();
    }

    await list.populate('mangaIds', 'title cover rating genres');
    res.json(list);
  } catch (error) {
    console.error('Add manga to list error:', error);
    res.status(500).json({ message: 'Failed to add manga to list' });
  }
});

// Remove manga from list
router.delete('/reading-lists/:id/manga/:mangaId', authMiddleware, async (req, res) => {
  try {
    const list = await ReadingList.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!list) {
      return res.status(404).json({ message: 'Reading list not found' });
    }

    list.mangaIds = list.mangaIds.filter(
      id => id.toString() !== req.params.mangaId
    );
    await list.save();

    await list.populate('mangaIds', 'title cover rating genres');
    res.json(list);
  } catch (error) {
    console.error('Remove manga from list error:', error);
    res.status(500).json({ message: 'Failed to remove manga from list' });
  }
});

// Get public reading lists
router.get('/reading-lists/public', optionalAuth, async (req, res) => {
  try {
    const lists = await ReadingList.find({ isPublic: true })
      .populate('userId', 'username avatar')
      .populate('mangaIds', 'title cover rating genres')
      .sort({ createdAt: -1 })
      .limit(20)
      .lean();

    res.json(lists);
  } catch (error) {
    console.error('Get public reading lists error:', error);
    res.status(500).json({ message: 'Failed to fetch public reading lists' });
  }
});

// ==================== Feedback & Requests ====================

const Feedback = require('../models/Feedback');

// Submit feedback/request/contact
router.post('/feedback', authMiddleware, async (req, res) => {
  try {
    const { type, subject, message, mangaTitle, mangaId } = req.body;

    if (!type || !['feedback', 'request', 'contact'].includes(type)) {
      return res.status(400).json({ message: 'Valid type is required (feedback, request, or contact)' });
    }

    if (!subject || !subject.trim()) {
      return res.status(400).json({ message: 'Subject is required' });
    }

    if (!message || !message.trim()) {
      return res.status(400).json({ message: 'Message is required' });
    }

    const feedback = new Feedback({
      userId: req.user._id,
      type,
      subject: subject.trim(),
      message: message.trim(),
      mangaTitle: mangaTitle?.trim() || null,
      mangaId: mangaId || null,
      status: 'pending',
    });

    await feedback.save();
    await feedback.populate('userId', 'username email');

    // Notify admins
    try {
      const User = require('../models/User');
      const firebaseFunctionsService = require('../services/firebaseFunctions');
      
      console.log('=== Starting admin notification process ===');
      console.log('Firebase Functions configured:', firebaseFunctionsService.isConfigured());
      
      if (firebaseFunctionsService.isConfigured()) {
        // Find all admins with FCM tokens
        // First, let's check all admins to see their status
        const allAdmins = await User.find({
          role: { $in: ['admin', 'super_admin'] },
        }).select('fcmToken email username role').lean();
        
        console.log(`Total admins found: ${allAdmins.length}`);
        allAdmins.forEach(admin => {
          console.log(`Admin: ${admin.email}, Role: ${admin.role}, Has FCM Token: ${!!admin.fcmToken}, Token: ${admin.fcmToken ? admin.fcmToken.substring(0, 20) + '...' : 'N/A'}`);
        });
        
        const admins = allAdmins.filter(a => a.fcmToken && a.fcmToken.trim() !== '');

        console.log(`Found ${admins.length} admin(s) with FCM tokens`);
        console.log('Admin details:', admins.map(a => ({ email: a.email, hasToken: !!a.fcmToken })));

        if (admins.length > 0) {
          const tokens = admins.map(a => a.fcmToken).filter(Boolean);
          console.log(`Valid FCM tokens: ${tokens.length}`);
          
          if (tokens.length > 0) {
            const typeLabel = type === 'request' ? 'Manga Request' : type === 'feedback' ? 'Feedback' : 'Contact';
            const notificationTitle = `New ${typeLabel}`;
            const notificationBody = `${req.user.username || req.user.email} submitted: ${subject}`;
            
            console.log('Sending notification:', {
              title: notificationTitle,
              body: notificationBody,
              tokenCount: tokens.length,
            });
            
            const result = await firebaseFunctionsService.sendBulkNotifications(
              tokens,
              notificationTitle,
              notificationBody,
              {
                type: 'admin_notification',
                notificationType: 'feedback',
                feedbackId: feedback._id.toString(),
                feedbackType: type,
              }
            );
            
            console.log('Notification result:', JSON.stringify(result, null, 2));
            
            if (!result.success) {
              console.error('❌ Failed to send admin notification:', result.error);
              if (result.details) {
                console.error('Error details:', JSON.stringify(result.details, null, 2));
              }
            } else {
              console.log(`✅ Admin notification sent successfully to ${tokens.length} admin(s)`);
              if (result.data) {
                console.log('Notification response data:', JSON.stringify(result.data, null, 2));
              }
            }
          } else {
            console.warn('⚠️ No valid FCM tokens found after filtering');
          }
        } else {
          console.warn('⚠️ No admins found with FCM tokens');
        }
      } else {
        console.warn('⚠️ Firebase Functions not configured. Admin notifications disabled.');
        console.warn('Set FIREBASE_FUNCTIONS_URL in .env file');
      }
    } catch (notifError) {
      console.error('❌ Error sending admin notification:', notifError);
      console.error('Stack trace:', notifError.stack);
      // Don't fail the feedback submission if notification fails
    }

    res.status(201).json({
      message: 'Feedback submitted successfully',
      feedback: feedback,
    });
  } catch (error) {
    console.error('Submit feedback error:', error);
    res.status(500).json({ message: 'Failed to submit feedback' });
  }
});

// Get user's feedback/requests
router.get('/feedback', authMiddleware, async (req, res) => {
  try {
    const feedbacks = await Feedback.find({ userId: req.user._id })
      .populate('mangaId', 'title cover')
      .sort({ createdAt: -1 })
      .lean();

    res.json(feedbacks);
  } catch (error) {
    console.error('Get feedback error:', error);
    res.status(500).json({ message: 'Failed to fetch feedback' });
  }
});

// Get detailed statistics (Spotify Wrapped style)
router.get('/statistics', authMiddleware, async (req, res) => {
  try {
    const userId = req.user._id;
    const user = await User.findById(userId).lean();
    const now = new Date();
    
    // Calculate time ranges
    const oneWeekAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const oneMonthAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const oneYearAgo = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
    
    // Get all reading history
    const allHistory = await ReadingHistory.find({ userId })
      .populate('mangaId', 'title cover genres')
      .sort({ lastRead: -1 })
      .lean();
    
    // Calculate time spent reading (estimate: 2 minutes per page, average 20 pages per chapter)
    // We'll use lastRead timestamps to estimate reading sessions
    let totalReadingTimeMinutes = 0;
    let weeklyReadingTimeMinutes = 0;
    let monthlyReadingTimeMinutes = 0;
    
    // Group by manga and calculate reading time
    const mangaReadingMap = new Map();
    allHistory.forEach(entry => {
      if (!entry.mangaId) return;
      
      const mangaId = entry.mangaId._id.toString();
      if (!mangaReadingMap.has(mangaId)) {
        mangaReadingMap.set(mangaId, {
          manga: entry.mangaId,
          chaptersRead: 0,
          lastRead: entry.lastRead,
          readingSessions: [],
        });
      }
      
      const mangaData = mangaReadingMap.get(mangaId);
      mangaData.chaptersRead = Math.max(mangaData.chaptersRead, entry.chaptersRead || 0);
      
      // Estimate reading time: 2 minutes per page, average 20 pages per chapter
      const estimatedMinutesPerChapter = 40; // 20 pages * 2 minutes
      const chaptersInThisSession = entry.chaptersRead || 1;
      const sessionMinutes = chaptersInThisSession * estimatedMinutesPerChapter;
      
      mangaData.readingSessions.push({
        date: entry.lastRead,
        minutes: sessionMinutes,
      });
      
      totalReadingTimeMinutes += sessionMinutes;
      
      if (entry.lastRead >= oneWeekAgo) {
        weeklyReadingTimeMinutes += sessionMinutes;
      }
      if (entry.lastRead >= oneMonthAgo) {
        monthlyReadingTimeMinutes += sessionMinutes;
      }
    });
    
    // Calculate total chapters read
    const totalChaptersRead = allHistory.reduce((sum, entry) => {
      return sum + (entry.chaptersRead || 0);
    }, 0);
    
    // Calculate unique chapters read (avoid double counting)
    const uniqueChapters = new Set();
    allHistory.forEach(entry => {
      if (entry.chapterId) {
        uniqueChapters.add(`${entry.mangaId?._id}_${entry.chapterId}`);
      }
    });
    const uniqueChaptersCount = uniqueChapters.size;
    
    // Genre breakdown
    const genreCount = new Map();
    let totalGenreManga = 0;
    
    mangaReadingMap.forEach((data) => {
      if (data.manga && data.manga.genres && Array.isArray(data.manga.genres)) {
        data.manga.genres.forEach(genre => {
          if (genre) {
            genreCount.set(genre, (genreCount.get(genre) || 0) + 1);
            totalGenreManga++;
          }
        });
      }
    });
    
    // Convert to percentage
    const genreBreakdown = Array.from(genreCount.entries())
      .map(([genre, count]) => ({
        genre,
        count,
        percentage: totalGenreManga > 0 ? Math.round((count / totalGenreManga) * 100) : 0,
      }))
      .sort((a, b) => b.percentage - a.percentage)
      .slice(0, 10); // Top 10 genres
    
    // Most read manga
    const mostReadManga = Array.from(mangaReadingMap.values())
      .map(data => ({
        manga: data.manga,
        chaptersRead: data.chaptersRead,
        readingTime: data.readingSessions.reduce((sum, s) => sum + s.minutes, 0),
      }))
      .sort((a, b) => b.chaptersRead - a.chaptersRead)
      .slice(0, 10);
    
    // Reading streak
    const readingStreak = user?.readingStreak || {};
    
    // Daily reading activity (last 30 days)
    const dailyActivity = [];
    for (let i = 29; i >= 0; i--) {
      const date = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      date.setHours(0, 0, 0, 0);
      
      const dayHistory = allHistory.filter(entry => {
        const entryDate = new Date(entry.lastRead);
        entryDate.setHours(0, 0, 0, 0);
        return entryDate.getTime() === date.getTime();
      });
      
      dailyActivity.push({
        date: date.toISOString().split('T')[0],
        chaptersRead: dayHistory.length,
        readingTime: dayHistory.length * 40, // Estimate
      });
    }
    
    // Favorite genres (by reading time)
    const genreReadingTime = new Map();
    mangaReadingMap.forEach((data) => {
      if (data.manga && data.manga.genres) {
        const readingTime = data.readingSessions.reduce((sum, s) => sum + s.minutes, 0);
        data.manga.genres.forEach(genre => {
          if (genre) {
            genreReadingTime.set(genre, (genreReadingTime.get(genre) || 0) + readingTime);
          }
        });
      }
    });
    
    const favoriteGenres = Array.from(genreReadingTime.entries())
      .map(([genre, minutes]) => ({
        genre,
        minutes,
        hours: Math.round((minutes / 60) * 10) / 10,
      }))
      .sort((a, b) => b.minutes - a.minutes)
      .slice(0, 5);
    
    res.json({
      timeSpent: {
        total: {
          hours: Math.round((totalReadingTimeMinutes / 60) * 10) / 10,
          minutes: totalReadingTimeMinutes,
        },
        weekly: {
          hours: Math.round((weeklyReadingTimeMinutes / 60) * 10) / 10,
          minutes: weeklyReadingTimeMinutes,
        },
        monthly: {
          hours: Math.round((monthlyReadingTimeMinutes / 60) * 10) / 10,
          minutes: monthlyReadingTimeMinutes,
        },
      },
      chaptersRead: {
        total: totalChaptersRead,
        unique: uniqueChaptersCount,
      },
      genreBreakdown,
      mostReadManga: mostReadManga.map(item => ({
        mangaId: item.manga._id,
        title: item.manga.title,
        cover: item.manga.cover,
        chaptersRead: item.chaptersRead,
        readingTime: item.readingTime,
        readingTimeHours: Math.round((item.readingTime / 60) * 10) / 10,
      })),
      readingStreak: {
        current: readingStreak.currentStreak || 0,
        longest: readingStreak.longestStreak || 0,
      },
      dailyActivity,
      favoriteGenres,
    });
  } catch (error) {
    console.error('Get statistics error:', error);
    res.status(500).json({ message: 'Failed to fetch statistics', error: error.message });
  }
});

// Verify age for adult content access
router.post('/verify-age', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.ageVerified = true;
    user.ageVerifiedAt = new Date();
    await user.save();

    res.json({
      success: true,
      message: 'Age verification completed',
      ageVerified: true,
    });
  } catch (error) {
    console.error('Age verification error:', error);
    res.status(500).json({ message: 'Failed to verify age', error: error.message });
  }
});

// Check age verification status
router.get('/age-verification', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.user._id).select('ageVerified ageVerifiedAt').lean();
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({
      ageVerified: user.ageVerified || false,
      ageVerifiedAt: user.ageVerifiedAt,
    });
  } catch (error) {
    console.error('Get age verification error:', error);
    res.status(500).json({ message: 'Failed to get age verification status' });
  }
});

module.exports = router;

