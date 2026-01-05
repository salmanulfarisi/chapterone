const express = require('express');
const Comment = require('../models/Comment');
const Manga = require('../models/Manga');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');
const optionalAuth = require('../middleware/optionalAuth');
const firebaseFunctionsService = require('../services/firebaseFunctions');

const router = express.Router();

// Get comments for a manga or chapter
router.get('/', optionalAuth, async (req, res) => {
  try {
    const { mangaId, chapterId } = req.query;

    if (!mangaId) {
      return res.status(400).json({ message: 'mangaId is required' });
    }

    const query = {
      mangaId,
      isDeleted: false,
    };

    if (chapterId) {
      query.chapterId = chapterId;
    } else {
      query.chapterId = null; // Only top-level manga comments
    }

    // Get all comments (both main and replies)
    const allComments = await Comment.find(query)
      .populate('userId', 'username avatar')
      .populate('likes', 'username')
      .sort({ createdAt: -1 })
      .lean();

    // Separate main comments (no parent) and replies (have parent)
    const mainComments = allComments.filter(c => !c.parentCommentId);
    const replies = allComments.filter(c => c.parentCommentId);

    // Format main comments with nested replies
    const formattedComments = mainComments.map(comment => {
      // Find all replies for this comment
      const commentReplies = replies
        .filter(reply => reply.parentCommentId?.toString() === comment._id.toString())
        .map(reply => ({
          ...reply,
          likesCount: reply.likes?.length || 0,
          isLiked: req.user && reply.likes?.some(
            like => like._id.toString() === req.user._id.toString()
          ),
        }))
        .sort((a, b) => new Date(a.createdAt) - new Date(b.createdAt)); // Sort replies by oldest first

      return {
        ...comment,
        likesCount: comment.likes?.length || 0,
        isLiked: req.user && comment.likes?.some(
          like => like._id.toString() === req.user._id.toString()
        ),
        repliesCount: commentReplies.length,
        replies: commentReplies,
      };
    });

    res.json(formattedComments);
  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({ message: 'Failed to fetch comments' });
  }
});

// Create comment
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { mangaId, chapterId, content, parentCommentId } = req.body;

    if (!mangaId || !content || !content.trim()) {
      return res.status(400).json({ message: 'mangaId and content are required' });
    }

    // Verify manga exists
    const manga = await Manga.findById(mangaId);
    if (!manga) {
      return res.status(404).json({ message: 'Manga not found' });
    }

    const comment = new Comment({
      userId: req.user._id,
      mangaId,
      chapterId: chapterId || null,
      content: content.trim(),
      parentCommentId: parentCommentId || null,
    });

    await comment.save();
    await comment.populate('userId', 'username avatar');

    // Send engagement notifications
    if (firebaseFunctionsService.isConfigured()) {
      try {
        const notificationRecipients = new Set();
        
        // If it's a reply, notify the parent comment author
        if (parentCommentId) {
          const parentComment = await Comment.findById(parentCommentId)
            .populate('userId', 'fcmToken preferences')
            .lean();
          
          if (parentComment && parentComment.userId) {
            const parentUser = parentComment.userId;
            // Don't notify if it's the same user
            if (parentUser._id.toString() !== req.user._id.toString()) {
              if (parentUser.preferences?.notifications?.engagement !== false &&
                  parentUser.preferences?.notifications?.comments !== false &&
                  parentUser.fcmToken) {
                notificationRecipients.add({
                  userId: parentUser._id.toString(),
                  token: parentUser.fcmToken,
                  type: 'reply',
                });
              }
            }
          }
        }

        // Notify other commenters on the same manga/chapter
        const otherComments = await Comment.find({
          mangaId,
          chapterId: chapterId || null,
          userId: { $ne: req.user._id },
          isDeleted: false,
        })
          .populate('userId', 'fcmToken preferences')
          .select('userId')
          .lean();

        const notifiedUserIds = new Set(
          Array.from(notificationRecipients).map(r => r.userId)
        );

        for (const otherComment of otherComments) {
          if (otherComment.userId && otherComment.userId.fcmToken) {
            const otherUser = otherComment.userId;
            // Avoid duplicate notifications
            const userIdStr = otherUser._id.toString();
            if (!notifiedUserIds.has(userIdStr) &&
                otherUser.preferences?.notifications?.engagement !== false &&
                otherUser.preferences?.notifications?.comments !== false) {
              notificationRecipients.add({
                userId: userIdStr,
                token: otherUser.fcmToken,
                type: 'comment',
              });
              notifiedUserIds.add(userIdStr);
            }
          }
        }

        // Send notifications to all recipients
        if (notificationRecipients.size > 0) {
          const tokens = Array.from(notificationRecipients).map(r => r.token).filter(Boolean);
          const commenterName = req.user.username || 'Someone';
          const mangaTitle = manga.title || 'a manga';
          const title = parentCommentId ? 'New Reply' : 'New Comment';
          const body = parentCommentId
            ? `${commenterName} replied to your comment on ${mangaTitle}`
            : `${commenterName} commented on ${mangaTitle}`;

          if (tokens.length > 0) {
            const result = await firebaseFunctionsService.sendBulkNotifications(
              tokens,
              title,
              body,
              {
                type: 'engagement',
                engagementType: parentCommentId ? 'reply' : 'comment',
                mangaId: mangaId.toString(),
                commentId: comment._id.toString(),
                userId: req.user._id.toString(),
              }
            );

            if (result.success) {
              console.log(`✅ Sent ${result.data?.successCount || tokens.length} engagement notifications for comment`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending engagement notifications:', notifError);
        // Don't fail the comment creation if notifications fail
      }
    }

    res.status(201).json({
      ...comment.toObject(),
      likesCount: 0,
      isLiked: false,
    });
  } catch (error) {
    console.error('Create comment error:', error);
    res.status(500).json({ message: 'Failed to create comment' });
  }
});

// Update comment
router.put('/:id', authMiddleware, async (req, res) => {
  try {
    const { content } = req.body;

    const comment = await Comment.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    comment.content = content.trim();
    comment.isEdited = true;
    await comment.save();
    await comment.populate('userId', 'username avatar');

    res.json({
      ...comment.toObject(),
      likesCount: comment.likes?.length || 0,
      isLiked: comment.likes?.some(
        like => like.toString() === req.user._id.toString()
      ),
    });
  } catch (error) {
    console.error('Update comment error:', error);
    res.status(500).json({ message: 'Failed to update comment' });
  }
});

// Delete comment (soft delete)
router.delete('/:id', authMiddleware, async (req, res) => {
  try {
    const comment = await Comment.findOne({
      _id: req.params.id,
      userId: req.user._id,
    });

    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    comment.isDeleted = true;
    comment.content = '[Deleted]';
    await comment.save();

    res.json({ message: 'Comment deleted' });
  } catch (error) {
    console.error('Delete comment error:', error);
    res.status(500).json({ message: 'Failed to delete comment' });
  }
});

// Like/Unlike comment
router.post('/:id/like', authMiddleware, async (req, res) => {
  try {
    const comment = await Comment.findById(req.params.id);

    if (!comment) {
      return res.status(404).json({ message: 'Comment not found' });
    }

    if (comment.isDeleted) {
      return res.status(400).json({ message: 'Cannot like deleted comment' });
    }

    const userId = req.user._id;
    const userIdStr = userId.toString();
    
    // Ensure likes is an array
    if (!Array.isArray(comment.likes)) {
      comment.likes = [];
    }

    // Check if already liked (handle both ObjectId and string comparisons)
    const isLiked = comment.likes.some(like => {
      if (like == null) return false;
      const likeStr = like.toString ? like.toString() : String(like);
      return likeStr === userIdStr;
    });

    if (isLiked) {
      // Unlike: remove user from likes array
      comment.likes = comment.likes.filter(like => {
        if (like == null) return false;
        const likeStr = like.toString ? like.toString() : String(like);
        return likeStr !== userIdStr;
      });
    } else {
      // Like: add user to likes array (avoid duplicates)
      const alreadyInLikes = comment.likes.some(like => {
        if (like == null) return false;
        const likeStr = like.toString ? like.toString() : String(like);
        return likeStr === userIdStr;
      });
      
      if (!alreadyInLikes) {
        comment.likes.push(userId);
      }
      
      // Send engagement notification when someone likes a comment
      if (firebaseFunctionsService.isConfigured()) {
        try {
          await comment.populate('userId', 'fcmToken preferences username');
          const commentAuthor = comment.userId;
          
          // Don't notify if the user liked their own comment
          if (commentAuthor && 
              commentAuthor._id && 
              commentAuthor._id.toString() !== userIdStr &&
              commentAuthor.preferences?.notifications?.engagement !== false &&
              commentAuthor.fcmToken) {
            const likerName = req.user.username || 'Someone';
            const title = 'New Like';
            const body = `${likerName} liked your comment`;
            
            const mangaIdStr = comment.mangaId ? 
              (comment.mangaId.toString ? comment.mangaId.toString() : String(comment.mangaId)) : 
              '';
            
            const result = await firebaseFunctionsService.sendNotification(
              commentAuthor._id.toString(),
              commentAuthor.fcmToken,
              title,
              body,
              {
                type: 'engagement',
                engagementType: 'like',
                commentId: comment._id.toString(),
                mangaId: mangaIdStr,
                userId: userIdStr,
              }
            );

            if (result.success) {
              console.log(`✅ Sent engagement notification for comment like`);
            }
          }
        } catch (notifError) {
          console.error('Error sending like notification:', notifError);
          // Don't fail the like action if notifications fail
        }
      }
    }

    await comment.save();

    // Recalculate likes count after save
    const finalLikesCount = Array.isArray(comment.likes) ? comment.likes.length : 0;
    const finalIsLiked = comment.likes.some(like => {
      if (like == null) return false;
      const likeStr = like.toString ? like.toString() : String(like);
      return likeStr === userIdStr;
    });

    res.json({
      likesCount: finalLikesCount,
      isLiked: finalIsLiked,
    });
  } catch (error) {
    console.error('Like comment error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({ 
      message: 'Failed to like comment',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined,
    });
  }
});

module.exports = router;
