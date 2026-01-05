const authMiddleware = require('./auth');

const adminAuthMiddleware = async (req, res, next) => {
  // First check if user is authenticated
  await new Promise((resolve, reject) => {
    authMiddleware(req, res, (err) => {
      if (err) reject(err);
      else resolve();
    });
  }).catch(() => {
    return res.status(401).json({ message: 'Authentication required' });
  });

  // Then check if user is admin
  if (!req.user || (!req.user.role.includes('admin') && req.user.role !== 'super_admin')) {
    return res.status(403).json({ message: 'Admin access required' });
  }

  next();
};

module.exports = adminAuthMiddleware;

