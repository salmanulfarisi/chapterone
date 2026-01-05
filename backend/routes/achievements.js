const express = require('express');
const authMiddleware = require('../middleware/auth');
const { checkAndAwardAchievements, getAchievementProgress } = require('../utils/achievements');

const router = express.Router();

// Get user achievements
router.get('/', authMiddleware, async (req, res) => {
  try {
    const progress = await getAchievementProgress(req.user._id);
    res.json({
      achievements: progress.unlocked,
      progress: progress.progress,
    });
  } catch (error) {
    console.error('Get achievements error:', error);
    res.status(500).json({ message: 'Failed to fetch achievements' });
  }
});

// Check and award achievements (called after reading chapters)
router.post('/check', authMiddleware, async (req, res) => {
  try {
    const newlyAwarded = await checkAndAwardAchievements(req.user._id);
    res.json({
      newlyAwarded,
      message: newlyAwarded.length > 0 
        ? `Congratulations! You unlocked ${newlyAwarded.length} achievement(s)!`
        : 'No new achievements unlocked.',
    });
  } catch (error) {
    console.error('Check achievements error:', error);
    res.status(500).json({ message: 'Failed to check achievements' });
  }
});

// Get achievement progress
router.get('/progress', authMiddleware, async (req, res) => {
  try {
    const progress = await getAchievementProgress(req.user._id);
    res.json(progress);
  } catch (error) {
    console.error('Get achievement progress error:', error);
    res.status(500).json({ message: 'Failed to fetch achievement progress' });
  }
});

module.exports = router;

