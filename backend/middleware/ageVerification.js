const User = require('../models/User');
const Manga = require('../models/Manga');

/**
 * Middleware to check if user has verified age for adult content
 */
async function checkAgeVerification(req, res, next) {
  try {
    // Get mangaId from params, body, or query
    const mangaId = req.params.id || req.params.mangaId || req.body.mangaId || req.query.mangaId;

    if (!mangaId) {
      return next();
    }

    const manga = await Manga.findById(mangaId).select('isAdult ageRating').lean();

    if (!manga) {
      return next();
    }

    // If manga is not adult, allow access
    if (!manga.isAdult) {
      return next();
    }

    // Check if user is authenticated
    if (!req.user) {
      return res.status(401).json({
        message: 'Authentication required for adult content',
        requiresAuth: true,
        requiresAgeVerification: true,
      });
    }

    // Check if user has verified age
    const user = await User.findById(req.user._id).select('ageVerified').lean();

    if (!user || !user.ageVerified) {
      return res.status(403).json({
        message: 'Age verification required',
        requiresAgeVerification: true,
        ageRating: manga.ageRating,
      });
    }

    next();
  } catch (error) {
    console.error('Age verification middleware error:', error);
    next(error);
  }
}

/**
 * Optional age verification check (doesn't block, just adds info)
 */
async function optionalAgeVerification(req, res, next) {
  try {
    if (req.user) {
      const user = await User.findById(req.user._id).select('ageVerified').lean();
      req.userAgeVerified = user?.ageVerified || false;
    } else {
      req.userAgeVerified = false;
    }
    next();
  } catch (error) {
    req.userAgeVerified = false;
    next();
  }
}

module.exports = {
  checkAgeVerification,
  optionalAgeVerification,
};

