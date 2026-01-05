const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  password: {
    type: String,
    required: true,
    select: false,
  },
  username: {
    type: String,
    trim: true,
  },
  avatar: {
    type: String,
  },
  role: {
    type: String,
    enum: ['user', 'admin', 'moderator', 'super_admin'],
    default: 'user',
  },
  profile: {
    bio: String,
    favoriteGenres: [String],
    readingPreferences: {
      readingMode: {
        type: String,
        enum: ['webtoon', 'page', 'double'],
        default: 'webtoon',
      },
      autoScroll: {
        type: Boolean,
        default: false,
      },
    },
  },
  preferences: {
    notifications: {
      newChapters: { type: Boolean, default: true },
      newManga: { type: Boolean, default: true },
      engagement: { type: Boolean, default: true },
      comments: { type: Boolean, default: true },
    },
    theme: {
      type: String,
      enum: ['dark', 'light'],
      default: 'dark',
    },
  },
  fcmToken: {
    type: String,
    default: null,
  },
  readingStreak: {
    currentStreak: { type: Number, default: 0 },
    longestStreak: { type: Number, default: 0 },
    lastReadDate: { type: Date, default: null },
  },
  // Age verification for adult content
  ageVerified: {
    type: Boolean,
    default: false,
  },
  ageVerifiedAt: {
    type: Date,
    default: null,
  },
  achievements: [{
    type: {
      type: String,
      enum: ['first_chapter', 'ten_chapters', 'hundred_chapters', 'week_streak', 'month_streak', 'year_streak', 'bookworm', 'speed_reader'],
    },
    unlockedAt: { type: Date, default: Date.now },
  }],
  isActive: {
    type: Boolean,
    default: true,
  },
}, {
  timestamps: true,
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (error) {
    next(error);
  }
});

// Compare password method
userSchema.methods.comparePassword = async function(candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

// Remove password from JSON output
userSchema.methods.toJSON = function() {
  const obj = this.toObject();
  delete obj.password;
  return obj;
};

module.exports = mongoose.model('User', userSchema);

