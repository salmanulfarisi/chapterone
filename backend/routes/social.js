const express = require('express');
const UserFollow = require('../models/UserFollow');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');
const firebaseFunctions = require('../services/firebaseFunctions');

const router = express.Router();

// Follow a user
router.post('/follow/:userId', authMiddleware, async (req, res) => {
  try {
    const targetUserId = req.params.userId;

    if (targetUserId === req.user._id.toString()) {
      return res.status(400).json({ message: 'Cannot follow yourself' });
    }

    // Check if user exists
    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Check if already following
    const existing = await UserFollow.findOne({
      followerId: req.user._id,
      followingId: targetUserId,
    });

    if (existing) {
      return res.status(400).json({ message: 'Already following this user' });
    }

    const follow = new UserFollow({
      followerId: req.user._id,
      followingId: targetUserId,
    });

    await follow.save();

    // Send engagement notification to the followed user
    if (firebaseFunctions.isConfigured()) {
      try {
        const followedUser = await User.findById(targetUserId)
          .select('fcmToken preferences username')
          .lean();
        
        if (followedUser &&
            followedUser.preferences?.notifications?.engagement !== false &&
            followedUser.fcmToken) {
          const followerName = req.user.username || 'Someone';
          const title = 'New Follower';
          const body = `${followerName} started following you`;
          
          const result = await firebaseFunctions.sendNotification(
            targetUserId,
            followedUser.fcmToken,
            title,
            body,
            {
              type: 'engagement',
              engagementType: 'follow',
              userId: req.user._id.toString(),
            }
          );

          if (result.success) {
            console.log(`✅ Sent engagement notification for follow`);
          }
        }
      } catch (notifError) {
        console.error('Error sending follow notification:', notifError);
        // Don't fail the follow action if notifications fail
      }
    }

    res.json({ message: 'User followed', following: true });
  } catch (error) {
    console.error('Follow user error:', error);
    res.status(500).json({ message: 'Failed to follow user' });
  }
});

// Unfollow a user
router.delete('/follow/:userId', authMiddleware, async (req, res) => {
  try {
    const targetUserId = req.params.userId;

    const follow = await UserFollow.findOneAndDelete({
      followerId: req.user._id,
      followingId: targetUserId,
    });

    if (!follow) {
      return res.status(404).json({ message: 'Not following this user' });
    }

    res.json({ message: 'User unfollowed', following: false });
  } catch (error) {
    console.error('Unfollow user error:', error);
    res.status(500).json({ message: 'Failed to unfollow user' });
  }
});

// Get user's followers
router.get('/followers/:userId', optionalAuth, async (req, res) => {
  try {
    const userId = req.params.userId;

    const followers = await UserFollow.find({ followingId: userId })
      .populate('followerId', 'username avatar email')
      .sort({ createdAt: -1 })
      .lean();

    res.json(followers.map(f => ({
      ...f.followerId,
      followedAt: f.createdAt,
    })));
  } catch (error) {
    console.error('Get followers error:', error);
    res.status(500).json({ message: 'Failed to fetch followers' });
  }
});

// Get user's following
router.get('/following/:userId', optionalAuth, async (req, res) => {
  try {
    const userId = req.params.userId;

    const following = await UserFollow.find({ followerId: userId })
      .populate('followingId', 'username avatar email')
      .sort({ createdAt: -1 })
      .lean();

    res.json(following.map(f => ({
      ...f.followingId,
      followedAt: f.createdAt,
    })));
  } catch (error) {
    console.error('Get following error:', error);
    res.status(500).json({ message: 'Failed to fetch following' });
  }
});

// Check if following a user
router.get('/follow-status/:userId', authMiddleware, async (req, res) => {
  try {
    const targetUserId = req.params.userId;

    const follow = await UserFollow.findOne({
      followerId: req.user._id,
      followingId: targetUserId,
    });

    res.json({ isFollowing: follow !== null });
  } catch (error) {
    console.error('Get follow status error:', error);
    res.status(500).json({ message: 'Failed to check follow status' });
  }
});

// Share manga
router.post('/share/manga/:mangaId', optionalAuth, async (req, res) => {
  try {
    const { mangaId } = req.params;
    const { platform } = req.body; // 'link', 'whatsapp', 'facebook', etc.

    // Get manga details
    const Manga = require('../models/Manga');
    const manga = await Manga.findById(mangaId).select('title cover').lean();

    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    // Generate share URL (you can customize this)
    const shareUrl = `${process.env.FRONTEND_URL || 'http://localhost'}/manga/$mangaId`;
    const shareText = `Check out ${manga.title} on ChapterOne!`;

    res.json({
      url: shareUrl,
      text: shareText,
      title: manga.title,
      cover: manga.cover,
    });
  } catch (error) {
    console.error('Share manga error:', error);
    res.status(500).json({ message: 'Failed to generate share link' });
  }
});

module.exports = router;
