const express = require('express');
const mongoose = require('mongoose');
const Chapter = require('../models/Chapter');
const Manga = require('../models/Manga');
const ReadingHistory = require('../models/ReadingHistory');
const ChapterUnlock = require('../models/ChapterUnlock');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');
const { checkAgeVerification } = require('../middleware/ageVerification');

const router = express.Router();

// Get chapter by ID (from embedded array or legacy Chapter collection)
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    let chapter = null;
    let manga = null;
    const chapterId = req.params.id;

    // Try to find in embedded chapters first (format: mangaId_chapterNumber)
    if (chapterId.includes('_ch')) {
      const [mangaIdStr, chapterNumStr] = chapterId.split('_ch');
      if (mongoose.Types.ObjectId.isValid(mangaIdStr)) {
        manga = await Manga.findById(mangaIdStr).lean();
        if (manga && manga.chapters && manga.chapters.length > 0) {
          const chapterNum = parseInt(chapterNumStr, 10);
          if (!isNaN(chapterNum)) {
            const embeddedChapter = manga.chapters.find(
              ch => ch.chapterNumber === chapterNum && ch.isActive !== false
            );
            if (embeddedChapter) {
              chapter = {
                _id: chapterId,
                mangaId: {
                  _id: manga._id.toString(),
                  title: manga.title || '',
                  cover: manga.cover || '',
                },
                chapterNumber: embeddedChapter.chapterNumber,
                title: embeddedChapter.title || `Chapter ${embeddedChapter.chapterNumber}`,
                pages: Array.isArray(embeddedChapter.pages) ? embeddedChapter.pages : [],
                releaseDate: embeddedChapter.releaseDate || null,
                views: embeddedChapter.views || 0,
                isActive: embeddedChapter.isActive !== false,
                isLocked: embeddedChapter.isLocked || false,
                createdAt: embeddedChapter.createdAt || manga.createdAt || new Date(),
                updatedAt: embeddedChapter.updatedAt || manga.updatedAt || new Date(),
              };
            }
          }
        }
      }
    }

    // Fallback to legacy Chapter collection (for old MongoDB ObjectIds)
    if (!chapter && mongoose.Types.ObjectId.isValid(chapterId)) {
      try {
        const legacyChapter = await Chapter.findById(chapterId)
          .populate('mangaId', 'title cover')
          .lean();
        if (legacyChapter && legacyChapter.isActive) {
          chapter = legacyChapter;
          manga = { _id: chapter.mangaId._id || chapter.mangaId };
        }
      } catch (legacyError) {
        // Legacy chapter not found, continue
        console.log(`Legacy chapter ${chapterId} not found:`, legacyError.message);
      }
    }

    // Last resort: if chapterId is in format mangaId_chapterNumber but not found,
    // try to find by searching all mangas (should rarely happen)
    if (!chapter && chapterId.includes('_ch')) {
      const [mangaIdStr, chapterNumStr] = chapterId.split('_ch');
      if (mongoose.Types.ObjectId.isValid(mangaIdStr)) {
        const chapterNum = parseInt(chapterNumStr, 10);
        if (!isNaN(chapterNum)) {
          // Try to find manga and check if chapter exists
          const foundManga = await Manga.findById(mangaIdStr).lean();
          if (foundManga && foundManga.chapters) {
            const embeddedChapter = foundManga.chapters.find(
              ch => ch.chapterNumber === chapterNum && ch.isActive !== false
            );
            if (embeddedChapter) {
              manga = foundManga;
              chapter = {
                _id: chapterId,
                mangaId: {
                  _id: foundManga._id.toString(),
                  title: foundManga.title || '',
                  cover: foundManga.cover || '',
                },
                chapterNumber: embeddedChapter.chapterNumber,
                title: embeddedChapter.title || `Chapter ${embeddedChapter.chapterNumber}`,
                pages: Array.isArray(embeddedChapter.pages) ? embeddedChapter.pages : [],
                releaseDate: embeddedChapter.releaseDate || null,
                views: embeddedChapter.views || 0,
                isActive: embeddedChapter.isActive !== false,
                createdAt: embeddedChapter.createdAt || foundManga.createdAt || new Date(),
                updatedAt: embeddedChapter.updatedAt || foundManga.updatedAt || new Date(),
              };
            }
          }
        }
      }
    }

    if (!chapter || !chapter.isActive) {
      console.error(`Chapter not found: ${chapterId}`);
      return res.status(404).json({ 
        message: 'Chapter not found',
        chapterId: chapterId,
      });
    }

    // Check if chapter is locked (freemium model)
    // First, get manga to check freeChapters if not already loaded
    if (!manga && chapter.mangaId) {
      const mangaIdForQuery = typeof chapter.mangaId === 'object' 
        ? (chapter.mangaId._id || chapter.mangaId)
        : chapter.mangaId;
      if (mongoose.Types.ObjectId.isValid(mangaIdForQuery)) {
        manga = await Manga.findById(mangaIdForQuery).select('freeChapters').lean();
      }
    }
    
    // Determine if chapter should be locked based on freeChapters
    const freeChapters = manga?.freeChapters || 3;
    const shouldBeLocked = chapter.chapterNumber > freeChapters;
    const isLocked = chapter.isLocked !== undefined ? chapter.isLocked : shouldBeLocked;
    
    let isUnlocked = false;
    
    if (isLocked) {
      // Check if user has unlocked this chapter
      if (req.user) {
        const mangaIdForUnlock = typeof chapter.mangaId === 'object' 
          ? (chapter.mangaId._id || chapter.mangaId)
          : chapter.mangaId;
        
        if (mongoose.Types.ObjectId.isValid(mangaIdForUnlock)) {
          const unlockRecord = await ChapterUnlock.findOne({
            userId: req.user._id,
            mangaId: mangaIdForUnlock,
            chapterNumber: chapter.chapterNumber,
          }).lean();
          
          isUnlocked = !!unlockRecord;
        }
      }
      
      // If locked and not unlocked, return limited data
      if (!isUnlocked) {
        return res.status(402).json({
          message: 'Chapter locked. Watch ad to unlock.',
          requiresAd: true,
          chapterId: chapter._id,
          chapterNumber: chapter.chapterNumber,
          mangaId: typeof chapter.mangaId === 'object' 
            ? (chapter.mangaId._id || chapter.mangaId)
            : chapter.mangaId,
          isLocked: true,
          freeChapters: freeChapters,
          // Don't return pages
        });
      }
    }

    // Ensure chapter has required fields and proper formatting
    if (!chapter.pages || !Array.isArray(chapter.pages)) {
      chapter.pages = [];
    }
    if (!chapter._id) {
      chapter._id = chapterId;
    }
    
    // Ensure mangaId is properly formatted
    if (chapter.mangaId && typeof chapter.mangaId === 'object') {
      if (chapter.mangaId._id && typeof chapter.mangaId._id !== 'string') {
        chapter.mangaId._id = chapter.mangaId._id.toString();
      }
    }
    
    // Ensure dates are properly formatted (convert to ISO string if needed)
    if (chapter.createdAt && !(chapter.createdAt instanceof Date)) {
      try {
        chapter.createdAt = new Date(chapter.createdAt);
      } catch (e) {
        chapter.createdAt = new Date();
      }
    }
    if (chapter.updatedAt && !(chapter.updatedAt instanceof Date)) {
      try {
        chapter.updatedAt = new Date(chapter.updatedAt);
      } catch (e) {
        chapter.updatedAt = new Date();
      }
    }
    if (chapter.releaseDate && !(chapter.releaseDate instanceof Date) && chapter.releaseDate !== null) {
      try {
        chapter.releaseDate = new Date(chapter.releaseDate);
      } catch (e) {
        chapter.releaseDate = null;
      }
    }

    // Track reading history if user is authenticated
    if (req.user) {
      try {
        // Handle both string and object mangaId
        let mangaId = null;
        if (typeof chapter.mangaId === 'object' && chapter.mangaId !== null) {
          mangaId = chapter.mangaId._id || chapter.mangaId;
        } else if (typeof chapter.mangaId === 'string') {
          mangaId = chapter.mangaId;
        } else {
          mangaId = manga?._id;
        }
        
        if (mangaId) {
          // Convert mangaId to ObjectId if it's a string
          const mangaIdObj = mongoose.Types.ObjectId.isValid(mangaId) 
            ? new mongoose.Types.ObjectId(mangaId) 
            : mangaId;
          
          // Check if this chapter was already read to avoid duplicate counts
          const existingHistory = await ReadingHistory.findOne({
            userId: req.user._id,
            mangaId: mangaIdObj,
          });
          
          // Check if this is a new entry or different chapter
          const isNewEntry = !existingHistory;
          const isDifferentChapter = existingHistory && 
            existingHistory.chapterId && 
            existingHistory.chapterId.toString() !== chapter._id.toString();
          
          const updateData = {
            $set: {
              userId: req.user._id,
              mangaId: mangaIdObj,
              chapterId: String(chapter._id || chapterId), // Ensure it's a string
              lastRead: new Date(),
            }
          };
          
          // Initialize or increment chaptersRead
          if (isNewEntry) {
            // For new entries, set chaptersRead to 1
            updateData.$set.chaptersRead = 1;
          } else if (isDifferentChapter) {
            // For different chapters, increment
            updateData.$inc = { chaptersRead: 1 };
          } else {
            // Same chapter, ensure chaptersRead exists (at least 1)
            if (!existingHistory.chaptersRead || existingHistory.chaptersRead === 0) {
              updateData.$set.chaptersRead = 1;
            }
          }
          
               await ReadingHistory.findOneAndUpdate(
                 {
                   userId: req.user._id,
                   mangaId: mangaIdObj,
                 },
                 updateData,
                 { upsert: true, new: true, setDefaultsOnInsert: true }
               );

               // Update reading streak
               try {
                 const User = require('../models/User');
                 const user = await User.findById(req.user._id);
                 if (user) {
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
                 }
               } catch (streakError) {
                 console.error('Failed to update reading streak:', streakError);
                 // Don't fail the request if streak update fails
               }

               // Check and award achievements after reading history is updated
               // Run in background to not block the response
               if (isNewEntry || isDifferentChapter) {
                 const { checkAndAwardAchievements } = require('../utils/achievements');
                 checkAndAwardAchievements(req.user._id).catch(err => {
                   console.error('Error checking achievements:', err);
                 });
               }
             }
           } catch (historyError) {
             // Log but don't fail the request if history tracking fails
             console.error('Failed to track reading history:', historyError);
           }
         }

    // Clean up the chapter object before sending
    const cleanChapter = {
      _id: chapter._id || chapterId,
      mangaId: chapter.mangaId || (manga ? { _id: manga._id.toString(), title: manga.title || '', cover: manga.cover || '' } : null),
      chapterNumber: chapter.chapterNumber || 0,
      title: chapter.title || 'Chapter',
      pages: Array.isArray(chapter.pages) ? chapter.pages : [],
      releaseDate: chapter.releaseDate || null,
      views: chapter.views || 0,
      isActive: chapter.isActive !== false,
      isLocked: isLocked && !isUnlocked,
      createdAt: chapter.createdAt || new Date(),
      updatedAt: chapter.updatedAt || new Date(),
    };

    res.json(cleanChapter);
  } catch (error) {
    console.error('Get chapter error:', error);
    console.error('Error stack:', error.stack);
    console.error('Chapter ID:', req.params.id);
    res.status(500).json({ 
      message: 'Failed to fetch chapter',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

// Update reading progress
router.post('/:id/progress', authMiddleware, async (req, res) => {
  try {
    const { pageNumber } = req.body;
    const chapterId = req.params.id;
    let chapter = null;
    let mangaId = null;

    // Try to find chapter (same logic as GET route)
    if (chapterId.includes('_ch')) {
      const [mangaIdStr, chapterNumStr] = chapterId.split('_ch');
      if (mongoose.Types.ObjectId.isValid(mangaIdStr)) {
        const manga = await Manga.findById(mangaIdStr).lean();
        if (manga && manga.chapters) {
          const chapterNum = parseInt(chapterNumStr, 10);
          if (!isNaN(chapterNum)) {
            const embeddedChapter = manga.chapters.find(
              ch => ch.chapterNumber === chapterNum && ch.isActive !== false
            );
            if (embeddedChapter) {
              chapter = { _id: chapterId };
              mangaId = new mongoose.Types.ObjectId(mangaIdStr);
            }
          }
        }
      }
    }

    // Fallback to legacy Chapter collection
    if (!chapter && mongoose.Types.ObjectId.isValid(chapterId)) {
      const legacyChapter = await Chapter.findById(chapterId).lean();
      if (legacyChapter) {
        chapter = legacyChapter;
        mangaId = legacyChapter.mangaId;
        if (typeof mangaId === 'object' && mangaId._id) {
          mangaId = mangaId._id;
        }
        if (typeof mangaId === 'string') {
          mangaId = new mongoose.Types.ObjectId(mangaId);
        }
      }
    }

    if (!chapter || !mangaId) {
      return res.status(404).json({ message: 'Chapter not found' });
    }

    await ReadingHistory.findOneAndUpdate(
      {
        userId: req.user._id,
        mangaId: mangaId,
      },
      {
        userId: req.user._id,
        mangaId: mangaId,
        chapterId: String(chapter._id || chapterId), // Ensure string
        pageNumber: pageNumber || 0,
        lastRead: new Date(),
      },
      { upsert: true, new: true }
    );

    res.json({ message: 'Progress updated' });
  } catch (error) {
    console.error('Update progress error:', error);
    res.status(500).json({ message: 'Failed to update progress' });
  }
});

// Unlock chapter (after watching ad)
router.post('/:id/unlock', authMiddleware, async (req, res) => {
  try {
    console.log('=== UNLOCK REQUEST RECEIVED ===');
    console.log('Chapter ID:', req.params.id);
    console.log('User ID:', req.user?._id);
    console.log('Request body:', req.body);
    
    const chapterId = req.params.id;
    let chapter = null;
    let mangaId = null;
    let chapterNumber = null;

    // Try to find chapter (same logic as GET route)
    if (chapterId.includes('_ch')) {
      const [mangaIdStr, chapterNumStr] = chapterId.split('_ch');
      if (mongoose.Types.ObjectId.isValid(mangaIdStr)) {
        const manga = await Manga.findById(mangaIdStr).lean();
        if (manga && manga.chapters) {
          const chapterNum = parseInt(chapterNumStr, 10);
          if (!isNaN(chapterNum)) {
            const embeddedChapter = manga.chapters.find(
              ch => ch.chapterNumber === chapterNum && ch.isActive !== false
            );
            if (embeddedChapter) {
              chapter = { _id: chapterId };
              mangaId = new mongoose.Types.ObjectId(mangaIdStr);
              chapterNumber = chapterNum;
            }
          }
        }
      }
    }

    // Fallback to legacy Chapter collection
    if (!chapter && mongoose.Types.ObjectId.isValid(chapterId)) {
      const legacyChapter = await Chapter.findById(chapterId).lean();
      if (legacyChapter) {
        chapter = legacyChapter;
        mangaId = legacyChapter.mangaId;
        chapterNumber = legacyChapter.chapterNumber;
        if (typeof mangaId === 'object' && mangaId._id) {
          mangaId = mangaId._id;
        }
        if (typeof mangaId === 'string') {
          mangaId = new mongoose.Types.ObjectId(mangaId);
        }
      }
    }

    if (!chapter || !mangaId || !chapterNumber) {
      console.log('Chapter not found - chapter:', chapter, 'mangaId:', mangaId, 'chapterNumber:', chapterNumber);
      return res.status(404).json({ message: 'Chapter not found' });
    }
    
    console.log('Chapter found - mangaId:', mangaId.toString(), 'chapterNumber:', chapterNumber);

    // Create or update unlock record
    const unlockRecord = await ChapterUnlock.findOneAndUpdate(
      {
        userId: req.user._id,
        mangaId: mangaId,
        chapterNumber: chapterNumber,
      },
      {
        userId: req.user._id,
        mangaId: mangaId,
        chapterId: String(chapter._id || chapterId),
        chapterNumber: chapterNumber,
        unlockedAt: new Date(),
        unlockMethod: 'ad',
      },
      { upsert: true, new: true }
    );

    console.log(`[UNLOCK CREATE] Chapter unlocked: mangaId=${mangaId}, chapterNumber=${chapterNumber}, userId=${req.user._id}`);
    console.log(`[UNLOCK CREATE] Unlock record ID: ${unlockRecord._id}, unlockedAt: ${unlockRecord.unlockedAt}, method: ${unlockRecord.unlockMethod}`);
    console.log(`[UNLOCK CREATE] This unlock is PERMANENT - it will not expire`);

    res.json({ 
      message: 'Chapter unlocked successfully',
      chapterId: String(chapter._id || chapterId),
      chapterNumber: chapterNumber,
      unlockedAt: unlockRecord.unlockedAt,
    });
  } catch (error) {
    console.error('Unlock chapter error:', error);
    res.status(500).json({ message: 'Failed to unlock chapter' });
  }
});

module.exports = router;

