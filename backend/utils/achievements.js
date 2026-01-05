const User = require('../models/User');
const ReadingHistory = require('../models/ReadingHistory');
const ReadingAnalytics = require('../models/ReadingAnalytics');

/**
 * Check and award achievements for a user
 * @param {Object} userId - User ObjectId
 * @returns {Promise<Array>} Array of newly awarded achievement types
 */
async function checkAndAwardAchievements(userId) {
  try {
    const user = await User.findById(userId);
    if (!user) {
      return [];
    }

    const existingAchievements = user.achievements || [];
    const existingTypes = new Set(existingAchievements.map(a => a.type));
    const newlyAwarded = [];

    // Get user statistics
    const [readingHistory, readingAnalytics, streakData] = await Promise.all([
      ReadingHistory.find({ userId }).lean(),
      ReadingAnalytics.find({ userId }).lean(),
      Promise.resolve({
        currentStreak: user.readingStreak?.currentStreak || 0,
        longestStreak: user.readingStreak?.longestStreak || 0,
        lastReadDate: user.readingStreak?.lastReadDate || null,
      }),
    ]);

    const totalChaptersRead = readingHistory.length;
    const uniqueMangaRead = new Set(readingHistory.map(h => h.mangaId?.toString())).size;
    const totalTimeSpent = readingAnalytics.reduce((sum, a) => sum + (a.timeSpent || 0), 0);

    // Check each achievement type
    const achievementsToCheck = [
      {
        type: 'first_chapter',
        condition: totalChaptersRead >= 1,
      },
      {
        type: 'ten_chapters',
        condition: totalChaptersRead >= 10,
      },
      {
        type: 'hundred_chapters',
        condition: totalChaptersRead >= 100,
      },
      {
        type: 'week_streak',
        condition: streakData.currentStreak >= 7,
      },
      {
        type: 'month_streak',
        condition: streakData.currentStreak >= 30,
      },
      {
        type: 'year_streak',
        condition: streakData.currentStreak >= 365,
      },
      {
        type: 'bookworm',
        condition: uniqueMangaRead >= 10,
      },
      {
        type: 'speed_reader',
        condition: totalTimeSpent > 0 && readingHistory.length > 0 && 
                  (totalTimeSpent / readingHistory.length) < 300 && 
                  readingHistory.length >= 10, // At least 10 chapters read
      },
    ];

    for (const achievement of achievementsToCheck) {
      if (achievement.condition && !existingTypes.has(achievement.type)) {
        // Award new achievement
        user.achievements.push({
          type: achievement.type,
          unlockedAt: new Date(),
        });
        newlyAwarded.push(achievement.type);
      }
    }

    // Save if any new achievements were awarded
    if (newlyAwarded.length > 0) {
      await user.save();
    }

    return newlyAwarded;
  } catch (error) {
    console.error('Error checking achievements:', error);
    return [];
  }
}

/**
 * Get user's achievement progress
 * @param {Object} userId - User ObjectId
 * @returns {Promise<Object>} Achievement progress data
 */
async function getAchievementProgress(userId) {
  try {
    const user = await User.findById(userId).select('achievements readingStreak').lean();
    if (!user) {
      return {
        unlocked: [],
        progress: {},
      };
    }

    const unlocked = user.achievements || [];
    const unlockedTypes = new Set(unlocked.map(a => a.type));

    // Get statistics for progress calculation
    const [readingHistory, readingAnalytics] = await Promise.all([
      ReadingHistory.find({ userId }).lean(),
      ReadingAnalytics.find({ userId }).lean(),
    ]);

    // Count total chapters read - sum up chaptersRead from ReadingHistory
    // Also count unique chapter sessions from ReadingAnalytics as fallback
    const historyChapters = readingHistory.reduce((sum, h) => sum + (h.chaptersRead || 0), 0);
    const analyticsChapters = new Set(
      readingAnalytics
        .filter(a => a.mangaId && a.chapterNumber != null)
        .map(a => `${a.mangaId}_${a.chapterNumber}`)
    ).size;
    const totalChaptersRead = historyChapters > 0 ? historyChapters : analyticsChapters;
    const uniqueMangaRead = new Set(readingHistory.map(h => h.mangaId?.toString())).size;
    const totalTimeSpent = readingAnalytics.reduce((sum, a) => sum + (a.timeSpent || 0), 0);
    const currentStreak = user.readingStreak?.currentStreak || 0;

    // Calculate progress for each achievement
    const progress = {
      first_chapter: { current: totalChaptersRead, target: 1, unlocked: unlockedTypes.has('first_chapter') },
      ten_chapters: { current: totalChaptersRead, target: 10, unlocked: unlockedTypes.has('ten_chapters') },
      hundred_chapters: { current: totalChaptersRead, target: 100, unlocked: unlockedTypes.has('hundred_chapters') },
      week_streak: { current: currentStreak, target: 7, unlocked: unlockedTypes.has('week_streak') },
      month_streak: { current: currentStreak, target: 30, unlocked: unlockedTypes.has('month_streak') },
      year_streak: { current: currentStreak, target: 365, unlocked: unlockedTypes.has('year_streak') },
      bookworm: { current: uniqueMangaRead, target: 10, unlocked: unlockedTypes.has('bookworm') },
      speed_reader: {
        current: readingHistory.length > 0 ? Math.round(totalTimeSpent / readingHistory.length) : 0,
        target: 300, // 5 minutes in seconds
        unlocked: unlockedTypes.has('speed_reader'),
        reverse: true, // Lower is better
      },
    };

    return {
      unlocked,
      progress,
    };
  } catch (error) {
    console.error('Error getting achievement progress:', error);
    return {
      unlocked: [],
      progress: {},
    };
  }
}

module.exports = {
  checkAndAwardAchievements,
  getAchievementProgress,
};

