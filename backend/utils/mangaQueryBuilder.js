/**
 * Utility to build manga queries with adult content filtering
 */

/**
 * Build a manga query with appropriate filters
 * @param {Object} user - The user object (can be null for anonymous)
 * @param {Object} options - Additional query options
 * @returns {Object} MongoDB query object
 */
function buildMangaQuery(user, options = {}) {
  const query = { isActive: true };

  // Handle source filter
  if (options.source) {
    query.source = options.source;
    // If filtering by hotcomics source, require age verification
    if (options.source === 'hotcomics') {
      if (user?.ageVerified) {
        query.isAdult = true; // Show adult content for verified users
      } else {
        // Non-verified users can't see hotcomics content
        query._id = null; // Return no results
      }
    }
    // For other sources, don't filter by adult content - show everything
  } else {
    // For regular queries (no source specified), EXCLUDE hotcomics content
    // Hotcomics content should only appear on the adult content page
    query.source = { $ne: 'hotcomics' };
  }

  // Add genre filter
  if (options.genre) {
    query.genres = { $in: [options.genre] };
  }

  // Add status filter
  if (options.status) {
    query.status = options.status;
  }

  // Add search text
  if (options.search) {
    query.$text = { $search: options.search };
  }

  // Add rating filter (min and max)
  if (options.minRating || options.maxRating) {
    query.rating = {};
    if (options.minRating) {
      query.rating.$gte = parseFloat(options.minRating);
    }
    if (options.maxRating) {
      query.rating.$lte = parseFloat(options.maxRating);
    }
  }

  // Add date range filter (for createdAt or updatedAt)
  if (options.dateFrom || options.dateTo) {
    const dateField = options.dateField || 'createdAt';
    query[dateField] = {};
    if (options.dateFrom) {
      query[dateField].$gte = new Date(options.dateFrom);
    }
    if (options.dateTo) {
      query[dateField].$lte = new Date(options.dateTo);
    }
  }

  // Add type filter
  if (options.type) {
    query.type = options.type;
  }

  return query;
}

/**
 * Build sort options for manga queries
 * @param {Object} options - Sort options
 * @returns {Object} MongoDB sort object
 */
function buildMangaSort(options = {}) {
  const { sortBy = 'createdAt', sort = 'desc' } = options;

  const sortMap = {
    createdAt: { createdAt: sort === 'asc' ? 1 : -1 },
    rating: { rating: sort === 'asc' ? 1 : -1 },
    views: { totalViews: sort === 'asc' ? 1 : -1 },
    updatedAt: { updatedAt: sort === 'asc' ? 1 : -1 },
    title: { title: sort === 'asc' ? 1 : -1 },
  };

  return sortMap[sortBy] || sortMap.createdAt;
}

module.exports = {
  buildMangaQuery,
  buildMangaSort,
};

