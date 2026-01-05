const express = require('express');
const Bookmark = require('../models/Bookmark');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authMiddleware);

// Get user bookmarks
router.get('/', async (req, res) => {
  try {
    const bookmarks = await Bookmark.find({ userId: req.user._id })
      .populate('mangaId')
      .sort({ createdAt: -1 })
      .lean();

    res.json(bookmarks);
  } catch (error) {
    console.error('Get bookmarks error:', error);
    res.status(500).json({ message: 'Failed to fetch bookmarks' });
  }
});

// Add bookmark
router.post('/', async (req, res) => {
  try {
    const { mangaId, collectionName } = req.body;

    const bookmark = await Bookmark.findOneAndUpdate(
      { userId: req.user._id, mangaId },
      {
        userId: req.user._id,
        mangaId,
        collectionName: collectionName || 'default',
      },
      { upsert: true, new: true }
    ).populate('mangaId');

    res.json(bookmark);
  } catch (error) {
    console.error('Add bookmark error:', error);
    res.status(500).json({ message: 'Failed to add bookmark' });
  }
});

// Remove bookmark
router.delete('/:mangaId', async (req, res) => {
  try {
    await Bookmark.findOneAndDelete({
      userId: req.user._id,
      mangaId: req.params.mangaId,
    });

    res.json({ message: 'Bookmark removed' });
  } catch (error) {
    console.error('Remove bookmark error:', error);
    res.status(500).json({ message: 'Failed to remove bookmark' });
  }
});

module.exports = router;

