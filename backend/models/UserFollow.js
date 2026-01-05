const mongoose = require('mongoose');

const userFollowSchema = new mongoose.Schema({
  followerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  followingId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
}, {
  timestamps: true,
});

// Ensure unique follow relationship
userFollowSchema.index({ followerId: 1, followingId: 1 }, { unique: true });

// Prevent self-follow
userFollowSchema.pre('save', function(next) {
  if (this.followerId.toString() === this.followingId.toString()) {
    const error = new Error('Cannot follow yourself');
    return next(error);
  }
  next();
});

module.exports = mongoose.model('UserFollow', userFollowSchema);
