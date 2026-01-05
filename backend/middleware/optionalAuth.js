const jwt = require('jsonwebtoken');
const User = require('../models/User');

// Optional auth - doesn't fail if no token, just sets req.user if valid
const optionalAuth = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
      return next();
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-password');

    if (user && user.isActive) {
      req.user = user;
    }
    
    next();
  } catch (error) {
    // Silently continue without user
    next();
  }
};

module.exports = optionalAuth;
