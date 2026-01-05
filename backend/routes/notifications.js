const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const NotificationPreferences = require('../models/NotificationPreferences');
const Notification = require('../models/Notification');
const User = require('../models/User');

// Get user's notification preferences
router.get('/preferences', authMiddleware, async (req, res) => {
  try {
    let preferences = await NotificationPreferences.findOne({ userId: req.user.id });

    if (!preferences) {
      // Create default preferences
      preferences = new NotificationPreferences({
        userId: req.user.id,
      });
      await preferences.save();
    }

    res.json(preferences);
  } catch (error) {
    console.error('Error getting notification preferences:', error);
    res.status(500).json({ error: 'Failed to get notification preferences' });
  }
});

// Update user's notification preferences
router.put('/preferences', authMiddleware, async (req, res) => {
  try {
    const preferences = await NotificationPreferences.findOneAndUpdate(
      { userId: req.user.id },
      {
        $set: req.body,
      },
      { new: true, upsert: true }
    );

    res.json(preferences);
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    res.status(500).json({ error: 'Failed to update notification preferences' });
  }
});

// Get notification preferences for a specific manga
router.get('/manga-settings/:mangaId', authMiddleware, async (req, res) => {
  try {
    const preferences = await NotificationPreferences.findOne({ userId: req.user.id });

    if (!preferences) {
      return res.json({
        enabled: true,
        immediate: true,
        onlyNewChapters: true,
      });
    }

    const mangaSettings = preferences.mangaSettings.get(req.params.mangaId) || {
      enabled: true,
      immediate: true,
      onlyNewChapters: true,
    };

    res.json(mangaSettings);
  } catch (error) {
    console.error('Error getting manga notification settings:', error);
    res.status(500).json({ error: 'Failed to get manga notification settings' });
  }
});

// Update notification preferences for a specific manga
router.put('/manga-settings/:mangaId', authMiddleware, async (req, res) => {
  try {
    const preferences = await NotificationPreferences.findOne({ userId: req.user.id });

    if (!preferences) {
      const newPreferences = new NotificationPreferences({
        userId: req.user.id,
        mangaSettings: {
          [req.params.mangaId]: req.body,
        },
      });
      await newPreferences.save();
      return res.json(req.body);
    }

    preferences.mangaSettings.set(req.params.mangaId, req.body);
    await preferences.save();

    res.json(req.body);
  } catch (error) {
    console.error('Error updating manga notification settings:', error);
    res.status(500).json({ error: 'Failed to update manga notification settings' });
  }
});

// Get user's notifications
router.get('/', authMiddleware, async (req, res) => {
  try {
    const { limit = 50, skip = 0 } = req.query;

    const notifications = await Notification.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(parseInt(limit))
      .skip(parseInt(skip));

    res.json({ notifications });
  } catch (error) {
    console.error('Error getting notifications:', error);
    res.status(500).json({ error: 'Failed to get notifications' });
  }
});

// Get unread notifications count
router.get('/unread-count', authMiddleware, async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user.id,
      read: false,
    });

    res.json({ count });
  } catch (error) {
    console.error('Error getting unread count:', error);
    res.status(500).json({ error: 'Failed to get unread count' });
  }
});

// Mark notification as read
router.put('/mark-read/:id', authMiddleware, async (req, res) => {
  try {
    const notification = await Notification.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { $set: { read: true } },
      { new: true }
    );

    if (!notification) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json(notification);
  } catch (error) {
    console.error('Error marking notification as read:', error);
    res.status(500).json({ error: 'Failed to mark notification as read' });
  }
});

// Mark all notifications as read
router.put('/mark-all-read', authMiddleware, async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user.id, read: false },
      { $set: { read: true } }
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Error marking all notifications as read:', error);
    res.status(500).json({ error: 'Failed to mark all notifications as read' });
  }
});

// Delete notification
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const notification = await Notification.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!notification) {
      return res.status(404).json({ error: 'Notification not found' });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Error deleting notification:', error);
    res.status(500).json({ error: 'Failed to delete notification' });
  }
});

// Schedule digest notification (for Firebase Functions)
router.post('/schedule-digest', authMiddleware, async (req, res) => {
  try {
    // This endpoint is called by the client to schedule digest
    // The actual scheduling will be handled by Firebase Functions
    // This just confirms the request
    res.json({ success: true, message: 'Digest scheduled' });
  } catch (error) {
    console.error('Error scheduling digest:', error);
    res.status(500).json({ error: 'Failed to schedule digest' });
  }
});

module.exports = router;

