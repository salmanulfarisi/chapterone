const express = require('express');
const ScraperSource = require('../models/ScraperSource');
const ScrapingJob = require('../models/ScrapingJob');
const Manga = require('../models/Manga');
const Chapter = require('../models/Chapter');
const Bookmark = require('../models/Bookmark');
const adminAuthMiddleware = require('../middleware/adminAuth');
const ScraperEngine = require('../services/scraper/scraper');
const asurascanzScraper = require('../services/scraper/asurascanzScraper');
const asuracomicScraper = require('../services/scraper/asuracomicScraper');
const hotcomicsScraper = require('../services/scraper/hotcomicsScraper');
const firebaseStorage = require('../services/firebaseStorage');
const { URL } = require('url');
const activityLogger = require('../services/activityLogger');
const firebaseFunctions = require('../services/firebaseFunctions');
const User = require('../models/User');

const router = express.Router();

// Helper to parse date strings like "December 9th 2025" or "December 9, 2025"
function parseChapterDate(dateStr) {
  if (!dateStr) return null;
  // Remove ordinal suffixes (st, nd, rd, th)
  const cleaned = dateStr.replace(/(\d+)(st|nd|rd|th)/gi, '$1');
  const parsed = new Date(cleaned);
  return isNaN(parsed.getTime()) ? null : parsed;
}

// All routes require admin authentication
router.use(adminAuthMiddleware);

// Get all sources
router.get('/sources', async (req, res) => {
  try {
    const sources = await ScraperSource.find().lean();
    res.json(sources);
  } catch (error) {
    console.error('Get sources error:', error);
    res.status(500).json({ message: 'Failed to fetch sources' });
  }
});

// Create/Update source
router.post('/sources', async (req, res) => {
  try {
    const source = await ScraperSource.findOneAndUpdate(
      { name: req.body.name },
      req.body,
      { upsert: true, new: true }
    );
    res.json(source);
  } catch (error) {
    console.error('Create source error:', error);
    res.status(500).json({ message: 'Failed to create source' });
  }
});

// Test source
router.post('/sources/:id/test', async (req, res) => {
  try {
    const source = await ScraperSource.findById(req.params.id);
    if (!source) {
      return res.status(404).json({ message: 'Source not found' });
    }

    const scraper = new ScraperEngine(source);
    await scraper.init();

    try {
      const testUrl = req.body.url || source.baseUrl;
      const result = await scraper.scrapeMangaList(testUrl);
      await scraper.close();
      res.json({ success: true, result });
    } catch (error) {
      await scraper.close();
      res.status(400).json({ success: false, error: error.message });
    }
  } catch (error) {
    console.error('Test source error:', error);
    res.status(500).json({ message: 'Failed to test source' });
  }
});

// Create scraping job
router.post('/jobs', async (req, res) => {
  try {
    const { scraper, url, jobType, mangaUrl, mangaTitle, mangaId, type, maxItems } = req.body;
    
    // Determine job type based on scraper selection
    let actualJobType = jobType || 'scraper';
    
    // If scraper is specified, set job type accordingly
    if (scraper === 'asurascanz') {
      actualJobType = url ? 'asurascanz_import' : 'asurascanz_updates';
    } else if (scraper === 'asuracomic') {
      actualJobType = url ? 'asuracomic_import' : 'asuracomic_updates';
    } else if (scraper === 'hotcomics') {
      actualJobType = url ? 'hotcomics_import' : 'hotcomics_updates';
    } else if (url) {
      // Auto-detect from URL if scraper not specified
      try {
        const urlObj = new URL(url);
        if (urlObj.hostname.includes('asurascanz') || urlObj.hostname.includes('asurascans')) {
          actualJobType = 'asurascanz_import';
        } else if (urlObj.hostname.includes('asuracomic')) {
          actualJobType = 'asuracomic_import';
        } else if (urlObj.hostname.includes('hotcomics.io')) {
          actualJobType = 'hotcomics_import';
        }
      } catch (e) {
        // Invalid URL, will be handled by validation
      }
    }
    
    // Validate that we have scraper and url (or mangaId for updates)
    if (!scraper && !url && !mangaId) {
      return res.status(400).json({ message: 'scraper and url (or mangaId) are required' });
    }

    const job = new ScrapingJob({
      jobType: actualJobType,
      url: url || undefined,
      mangaUrl: url || mangaUrl || undefined,
      mangaTitle: mangaTitle || undefined,
      mangaId: mangaId || undefined,
      status: 'pending',
      progress: {
        current: 0,
        total: maxItems || 0,
        percentage: 0,
        currentChapter: 0,
        totalChapters: 0,
      },
    });
    await job.save();
    
    // Log job creation for debugging
    console.log('Created job:', {
      id: job._id,
      scraper: scraper,
      url: job.url,
      jobType: job.jobType,
    });

    // Start processing in background
    if (actualJobType === 'asurascanz_import' || actualJobType === 'asurascanz_updates') {
      processAsuraScanzJob(job._id).catch((err) => {
        console.error('Failed to process AsuraScanz job:', err);
      });
    } else if (actualJobType === 'asuracomic_import' || actualJobType === 'asuracomic_updates') {
      processAsuraComicJob(job._id).catch((err) => {
        console.error('Failed to process AsuraComic job:', err);
      });
    } else if (actualJobType === 'hotcomics_import' || actualJobType === 'hotcomics_updates') {
      // Use the hotcomics import endpoint directly
      processHotComicsJob(job._id).catch((err) => {
        console.error('Failed to process HotComics job:', err);
      });
    }

    res.status(201).json(job);
  } catch (error) {
    console.error('Create job error:', error);
    res.status(500).json({ message: 'Failed to create job' });
  }
});

// Get jobs
router.get('/jobs', async (req, res) => {
  try {
    const jobs = await ScrapingJob.find()
      .populate('sourceId', 'name')
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();
    res.json(jobs);
  } catch (error) {
    console.error('Get jobs error:', error);
    res.status(500).json({ message: 'Failed to fetch jobs' });
  }
});

// Get job by ID
router.get('/jobs/:id', async (req, res) => {
  try {
    const job = await ScrapingJob.findById(req.params.id)
      .populate('sourceId')
      .lean();
    res.json(job);
  } catch (error) {
    console.error('Get job error:', error);
    res.status(500).json({ message: 'Failed to fetch job' });
  }
});

// Cancel a running job
router.post('/jobs/:id/cancel', async (req, res) => {
  try {
    const job = await ScrapingJob.findById(req.params.id);
    if (!job) {
      return res.status(404).json({ message: 'Job not found' });
    }

    if (job.status !== 'running' && job.status !== 'pending') {
      return res.status(400).json({ message: 'Job is not running or pending' });
    }

    job.status = 'cancelled';
    job.completedAt = new Date();
    job.errorLog.push({
      message: 'Job cancelled by user',
      timestamp: new Date(),
    });
    await job.save();

    res.json({ message: 'Job cancelled successfully', job });
  } catch (error) {
    console.error('Cancel job error:', error);
    res.status(500).json({ message: 'Failed to cancel job' });
  }
});

// ---------- AsuraScanz special endpoints (direct scraper) ----------

// Get home/latest manga from AsuraScanz
router.get('/asurascanz/home', async (req, res) => {
  try {
    const page = parseInt(req.query.page, 10) || 1;
    const data = await asurascanzScraper.fetchHomeManga({ page });
    res.json(data);
  } catch (error) {
    console.error('Asurascanz home error:', error);
    res.status(500).json({ message: 'Failed to fetch AsuraScanz home manga' });
  }
});

// Get manga details + chapters from AsuraScanz
router.get('/asurascanz/manga', async (req, res) => {
  try {
    const { url } = req.query;
    if (!url) {
      return res.status(400).json({ message: 'url query parameter is required' });
    }

    const data = await asurascanzScraper.fetchMangaDetails(url);
    res.json(data);
  } catch (error) {
    console.error('Asurascanz manga error:', error);
    res.status(500).json({ message: 'Failed to fetch AsuraScanz manga details' });
  }
});

// Get chapter pages from AsuraScanz
router.get('/asurascanz/chapter', async (req, res) => {
  try {
    const { url } = req.query;
    if (!url) {
      return res.status(400).json({ message: 'url query parameter is required' });
    }

    const data = await asurascanzScraper.fetchChapterPages(url);
    res.json(data);
  } catch (error) {
    console.error('Asurascanz chapter error:', error);
    res.status(500).json({ message: 'Failed to fetch AsuraScanz chapter pages' });
  }
});

// Search AsuraScanz
router.get('/asurascanz/search', async (req, res) => {
  try {
    const { q, page, fetchAll } = req.query;
    if (!q) {
      return res.status(400).json({ message: 'q query parameter is required' });
    }

    const pageNum = page ? parseInt(page, 10) : 1;
    const fetchAllPages = fetchAll === 'true' || fetchAll === '1';
    
    const data = await asurascanzScraper.searchManga(q, { 
      page: pageNum, 
      fetchAllPages: fetchAllPages 
    });
    
    res.json(data);
  } catch (error) {
    console.error('Asurascanz search error:', error);
    res.status(500).json({ message: 'Failed to search AsuraScanz' });
  }
});

// Preview AsuraScanz manga (with local import info)
router.post('/asurascanz/preview', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'url is required' });
    }

    const details = await asurascanzScraper.fetchMangaDetails(url);

    // Check if this manga already exists in our DB
    const existingManga = await Manga.findOne({
      source: 'asurascanz',
      sourceUrl: details.url,
    }).lean();

    let existingChaptersMap = new Set();
    if (existingManga) {
      const existingChapters = await Chapter.find({
        mangaId: existingManga._id,
      })
        .select('chapterNumber')
        .lean();
      existingChaptersMap = new Set(
        existingChapters.map((c) => c.chapterNumber),
      );
    }

    const chaptersWithImportInfo = details.chapters.map((ch) => ({
      ...ch,
      exists: ch.number != null && existingChaptersMap.has(ch.number),
    }));

    res.json({
      manga: {
        ...details,
        chapters: chaptersWithImportInfo,
      },
      existingMangaId: existingManga ? existingManga._id : null,
    });
  } catch (error) {
    console.error('Asurascanz preview error:', error);
    res.status(500).json({ message: 'Failed to preview AsuraScanz manga' });
  }
});

// Import AsuraScanz manga + chapters into our DB
router.post('/asurascanz/import', async (req, res) => {
  try {
    const { url, chapterNumbers } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'url is required' });
    }

    const details = await asurascanzScraper.fetchMangaDetails(url);

    // Find or create manga
    let manga = await Manga.findOne({
      source: 'asurascanz',
      sourceUrl: details.url,
    });

    const isNewManga = !manga;
    const mappedStatus = details.status
      ? details.status.toLowerCase()
      : 'ongoing';

    if (!manga) {
      manga = new Manga({
        title: details.title,
        description: details.synopsis,
        cover: details.cover,
        genres: details.genres || [],
        status: ['ongoing', 'completed', 'hiatus', 'cancelled'].includes(
          mappedStatus,
        )
          ? mappedStatus
          : 'ongoing',
        source: 'asurascanz',
        sourceUrl: details.url,
      });
    } else {
      // Update basic fields if they changed
      manga.title = details.title || manga.title;
      manga.description = details.synopsis || manga.description;
      manga.cover = details.cover || manga.cover;
      manga.genres = details.genres?.length ? details.genres : manga.genres;
    }

    // Ensure rating stays within schema bounds (0–5) to avoid validation errors
    if (typeof manga.rating === 'number') {
      if (Number.isNaN(manga.rating)) manga.rating = 0;
      if (manga.rating > 5) manga.rating = 5;
      if (manga.rating < 0) manga.rating = 0;
    }

    await manga.save();

    // Determine which chapters to import
    let chaptersToImport = details.chapters;
    if (Array.isArray(chapterNumbers) && chapterNumbers.length > 0) {
      const chapterSet = new Set(
        chapterNumbers.map((n) => Number.parseInt(n, 10)),
      );
      chaptersToImport = details.chapters.filter(
        (ch) => ch.number != null && chapterSet.has(ch.number),
      );
    }

    const imported = [];

    for (const ch of chaptersToImport) {
      if (!ch.url || ch.number == null) continue;

      // Fetch pages for this chapter
      const pagesResult = await asurascanzScraper.fetchChapterPages(ch.url);
      const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);

      if (pageUrls.length === 0) continue;

      const releaseDate = parseChapterDate(ch.date);

      const chapterDoc = await Chapter.findOneAndUpdate(
        {
          mangaId: manga._id,
          chapterNumber: ch.number,
        },
        {
          $set: {
            title: ch.name || `Chapter ${ch.number}`,
            pages: pageUrls,
            releaseDate: releaseDate,
            isActive: true,
          },
        },
        {
          new: true,
          upsert: true,
        },
      );

      imported.push({
        chapterNumber: chapterDoc.chapterNumber,
        id: chapterDoc._id,
      });
    }

    // Update manga totalChapters
    const maxChapter = await Chapter.find({ mangaId: manga._id })
      .sort({ chapterNumber: -1 })
      .limit(1)
      .lean();
    if (maxChapter.length > 0) {
      manga.totalChapters = maxChapter[0].chapterNumber;
    }

    // Clamp rating again here in case it was set out of range elsewhere
    if (typeof manga.rating === 'number') {
      if (Number.isNaN(manga.rating)) manga.rating = 0;
      if (manga.rating > 5) manga.rating = 5;
      if (manga.rating < 0) manga.rating = 0;
    }

    await manga.save();

    // Send notifications for new chapters if any were imported
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    // Send notification for new manga if this is a new manga
    if (isNewManga && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have notifications enabled for new manga
        const users = await User.find({
          'preferences.notifications.newManga': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            const result = await firebaseFunctions.notifyNewManga(
              tokens,
              manga._id.toString(),
              manga.title,
              manga.genres || []
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new manga "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending new manga notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    res.json({
      message: 'Import completed',
      mangaId: manga._id,
      importedCount: imported.length,
      imported,
    });
  } catch (error) {
    console.error('Asurascanz import error:', error);
    res.status(500).json({ message: 'Failed to import AsuraScanz manga' });
  }
});

// Check for updates for all imported AsuraScanz manga
router.get('/asurascanz/updates', async (req, res) => {
  try {
    const { mangaId } = req.query;
    
    // If mangaId is provided, check only that manga
    if (mangaId) {
      const manga = await Manga.findById(mangaId).lean();
      if (!manga || manga.source !== 'asurascanz' || !manga.sourceUrl) {
        return res.status(404).json({ message: 'Manga not found or invalid' });
      }

      const fullManga = await Manga.findById(mangaId).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await asurascanzScraper.fetchMangaDetails(manga.sourceUrl);
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        return res.json({
          mangaId: manga._id,
          title: manga.title,
          sourceUrl: manga.sourceUrl,
          localMaxChapter: localMax,
          remoteMaxChapter: 0,
          hasUpdates: false,
          newChaptersCount: 0,
          newChapters: [],
          error: `Failed to fetch: ${err.message || 'Unknown error'}`,
        });
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      return res.json({
        mangaId: manga._id,
        title: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          name: ch.name,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    // Otherwise, check all manga
    const importedManga = await Manga.find({
      source: 'asurascanz',
      sourceUrl: { $ne: null },
      isActive: true,
    })
      .select('title sourceUrl')
      .lean();

    const results = [];

    for (const manga of importedManga) {
      // Get local max chapter from embedded chapters array
      const fullManga = await Manga.findById(manga._id).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await asurascanzScraper.fetchMangaDetails(
          manga.sourceUrl,
        );
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) =>
            ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        console.error(
          `Failed to fetch remote details for ${manga.sourceUrl}`,
          err,
        );
        continue;
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      results.push({
        mangaId: manga._id,
        title: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          name: ch.name,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    res.json(results);
  } catch (error) {
    console.error('Asurascanz updates error:', error);
    res.status(500).json({ message: 'Failed to check AsuraScanz updates' });
  }
});

// Create background job for AsuraScanz import
router.post('/asurascanz/import-background', async (req, res) => {
  try {
    const { mangaId, url, mangaTitle, chapterNumbers } = req.body;
    
    if (!mangaId && !url) {
      return res.status(400).json({ message: 'mangaId or url is required' });
    }

    const job = new ScrapingJob({
      jobType: mangaId ? 'asurascanz_updates' : 'asurascanz_import',
      mangaId: mangaId || undefined,
      mangaUrl: url || undefined,
      mangaTitle: mangaTitle || undefined,
      chapterNumbers: chapterNumbers || undefined, // Store selected chapters
      status: 'pending',
      progress: {
        current: 0,
        total: 0,
        percentage: 0,
        currentChapter: 0,
        totalChapters: 0,
      },
    });
    await job.save();

    // Start processing in background
    processAsuraScanzJob(job._id).catch((err) => {
      console.error('Failed to process AsuraScanz job:', err);
    });

    res.status(201).json(job);
  } catch (error) {
    console.error('Create AsuraScanz background job error:', error);
    res.status(500).json({ message: 'Failed to create background job' });
  }
});

// Import only new chapters for a specific imported manga
router.post('/asurascanz/import-updates', async (req, res) => {
  try {
    const { mangaId } = req.body;
    if (!mangaId) {
      return res.status(400).json({ message: 'mangaId is required' });
    }

    const manga = await Manga.findById(mangaId);
    if (!manga || manga.source !== 'asurascanz' || !manga.sourceUrl) {
      return res.status(404).json({ message: 'Asurascanz manga not found' });
    }

    // Get local max chapter from embedded chapters array
    let localMax = 0;
    if (manga.chapters && Array.isArray(manga.chapters)) {
      const activeChapters = manga.chapters.filter(ch => ch.isActive !== false);
      if (activeChapters.length > 0) {
        localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
      }
    }

    const details = await asurascanzScraper.fetchMangaDetails(manga.sourceUrl);
    const remoteChapters = details.chapters || [];

    const chaptersToImport = remoteChapters.filter(
      (ch) => ch.number != null && ch.number > localMax,
    );

    const imported = [];

    for (const ch of chaptersToImport) {
      if (!ch.url || ch.number == null) continue;

      const pagesResult = await asurascanzScraper.fetchChapterPages(ch.url);
      const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);
      if (pageUrls.length === 0) continue;

      const releaseDate = parseChapterDate(ch.date);

      // Update manga's embedded chapters array
      if (!manga.chapters) {
        manga.chapters = [];
      }

      // Find existing chapter or create new
      const chapterIndex = manga.chapters.findIndex(
        c => c.chapterNumber === ch.number
      );

      const chapterData = {
        chapterNumber: ch.number,
        title: ch.name || `Chapter ${ch.number}`,
        pages: pageUrls,
        releaseDate: releaseDate,
        isActive: true,
        updatedAt: new Date(),
      };

      const isNewChapter = chapterIndex < 0;

      if (chapterIndex >= 0) {
        // Update existing chapter
        manga.chapters[chapterIndex] = {
          ...manga.chapters[chapterIndex],
          ...chapterData,
        };
      } else {
        // Add new chapter
        chapterData.createdAt = new Date();
        manga.chapters.push(chapterData);
      }

      await manga.save();

      imported.push({
        chapterNumber: ch.number,
        id: `${manga._id}_ch${ch.number}`,
      });

      // Log activity for new chapter
      if (isNewChapter) {
        try {
          await activityLogger.logActivity({
            action: 'chapter_added',
            entityType: 'chapter',
            entityId: `${manga._id}_ch${ch.number}`,
            details: {
              mangaTitle: manga.title,
              chapterNumber: ch.number,
            },
            severity: 'info',
          });
        } catch (logError) {
          console.error('Failed to log activity:', logError);
        }
      }
    }

    // Update manga totalChapters from embedded array
    if (manga.chapters && manga.chapters.length > 0) {
      const maxChapter = manga.chapters
        .filter(ch => ch.isActive !== false)
        .reduce((max, ch) => ch.chapterNumber > max ? ch.chapterNumber : max, 0);
      manga.totalChapters = maxChapter;
      await manga.save();
    }

    // Send notifications for new chapters if any were imported
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    res.json({
      message: 'Update import completed',
      mangaId: manga._id,
      importedCount: imported.length,
      imported,
    });
  } catch (error) {
    console.error('Asurascanz import-updates error:', error);
    res.status(500).json({ message: 'Failed to import AsuraScanz updates' });
  }
});

// Background job processor for AsuraScanz imports
async function processAsuraScanzJob(jobId) {
  const job = await ScrapingJob.findById(jobId);
  if (!job) {
    console.error(`Job ${jobId} not found`);
    return;
  }

  try {
    job.status = 'running';
    job.startedAt = new Date();
    await job.save();

    let manga;
    let chaptersToImport = [];
    let mangaUrl;
    let isNewManga = false; // Initialize for updates (manga already exists)

    if (job.jobType === 'asurascanz_updates' && job.mangaId) {
      // Import updates for existing manga
      manga = await Manga.findById(job.mangaId);
      if (!manga || manga.source !== 'asurascanz' || !manga.sourceUrl) {
        throw new Error('AsuraScanz manga not found');
      }
      mangaUrl = manga.sourceUrl;

      // Get local max chapter from embedded chapters array
      const fullManga = await Manga.findById(manga._id).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      const details = await asurascanzScraper.fetchMangaDetails(mangaUrl);
      const remoteChapters = details.chapters || [];

      chaptersToImport = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );
    } else if (job.jobType === 'asurascanz_import' && job.mangaUrl) {
      // Import new manga
      mangaUrl = job.mangaUrl;
      const details = await asurascanzScraper.fetchMangaDetails(mangaUrl);
      let allChapters = details.chapters || [];
      
      // Filter by chapterNumbers if provided
      if (job.chapterNumbers && Array.isArray(job.chapterNumbers) && job.chapterNumbers.length > 0) {
        const chapterSet = new Set(
          job.chapterNumbers.map((n) => Number.parseInt(n, 10)),
        );
        chaptersToImport = allChapters.filter(
          (ch) => ch.number != null && chapterSet.has(ch.number),
        );
      } else {
        chaptersToImport = allChapters;
      }

      // Find or create manga
      manga = await Manga.findOne({
        source: 'asurascanz',
        sourceUrl: details.url,
      });

      const mappedStatus = details.status
        ? details.status.toLowerCase()
        : 'ongoing';

      const isNewManga = !manga;
      if (!manga) {
        manga = new Manga({
          title: details.title,
          description: details.synopsis,
          cover: details.cover,
          genres: details.genres || [],
          status: ['ongoing', 'completed', 'hiatus', 'cancelled'].includes(
            mappedStatus,
          )
            ? mappedStatus
            : 'ongoing',
          source: 'asurascanz',
          sourceUrl: details.url,
        });
      } else {
        manga.title = details.title || manga.title;
        manga.description = details.synopsis || manga.description;
        manga.cover = details.cover || manga.cover;
        manga.genres = details.genres?.length ? details.genres : manga.genres;
      }

      if (typeof manga.rating === 'number') {
        if (Number.isNaN(manga.rating)) manga.rating = 0;
        if (manga.rating > 5) manga.rating = 5;
        if (manga.rating < 0) manga.rating = 0;
      }

      await manga.save();
    } else {
      throw new Error('Invalid job configuration');
    }

    // Update job with total chapters and track if manga is new
    job.progress.totalChapters = chaptersToImport.length;
    job.progress.total = chaptersToImport.length;
    job.mangaTitle = manga.title;
    job.isNewManga = isNewManga;
    await job.save();

    const imported = [];

    // Process chapters one by one with progress updates
    for (let i = 0; i < chaptersToImport.length; i++) {
      const ch = chaptersToImport[i];
      if (!ch.url || ch.number == null) continue;

      try {
        // Fetch pages for this chapter
        const pagesResult = await asurascanzScraper.fetchChapterPages(ch.url);
        const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);

        if (pageUrls.length === 0) continue;

        const releaseDate = parseChapterDate(ch.date);

        // Update manga's embedded chapters array
        if (!manga.chapters) {
          manga.chapters = [];
        }

        // Find existing chapter or create new
        const chapterIndex = manga.chapters.findIndex(
          c => c.chapterNumber === ch.number
        );

        const chapterData = {
          chapterNumber: ch.number,
          title: ch.name || `Chapter ${ch.number}`,
          pages: pageUrls,
          releaseDate: releaseDate,
          isActive: true,
          updatedAt: new Date(),
        };

        const isNewChapter = chapterIndex < 0;
        
        if (chapterIndex >= 0) {
          // Update existing chapter
          manga.chapters[chapterIndex] = {
            ...manga.chapters[chapterIndex],
            ...chapterData,
          };
        } else {
          // Add new chapter
          chapterData.createdAt = new Date();
          manga.chapters.push(chapterData);
        }

        await manga.save();

        imported.push({
          chapterNumber: ch.number,
          id: `${manga._id}_ch${ch.number}`,
        });

        // Log activity for new chapter
        if (isNewChapter) {
          try {
            await activityLogger.logActivity({
              action: 'chapter_added',
              entityType: 'chapter',
              entityId: `${manga._id}_ch${ch.number}`,
              details: {
                mangaTitle: manga.title,
                chapterNumber: ch.number,
                jobType: job.jobType,
              },
              severity: 'info',
            });
          } catch (logError) {
            console.error('Failed to log activity:', logError);
          }
        }


        // Update progress
        job.progress.currentChapter = i + 1;
        job.progress.current = i + 1;
        job.progress.percentage = Math.round(
          ((i + 1) / chaptersToImport.length) * 100,
        );
        await job.save();
      } catch (chapterError) {
        console.error(`Error importing chapter ${ch.number}:`, chapterError);
        job.errorLog.push({
          message: `Failed to import chapter ${ch.number}: ${chapterError.message}`,
          stack: chapterError.stack,
          timestamp: new Date(),
        });
        await job.save();
      }
    }

    // Update manga totalChapters from embedded array
    if (manga.chapters && manga.chapters.length > 0) {
      const maxChapter = manga.chapters
        .filter(ch => ch.isActive !== false)
        .reduce((max, ch) => ch.chapterNumber > max ? ch.chapterNumber : max, 0);
      manga.totalChapters = maxChapter;
      await manga.save();
    }

    // Send notifications for new chapters via Firebase Functions
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the job if notifications fail
      }
    }

    // Send notification for new manga if this is a new manga
    if (isNewManga && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have notifications enabled for new manga
        const users = await User.find({
          'preferences.notifications.newManga': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            const result = await firebaseFunctions.notifyNewManga(
              tokens,
              manga._id.toString(),
              manga.title,
              manga.genres || []
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new manga "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending new manga notifications:', notifError);
        // Don't fail the job if notifications fail
      }
    }

    // Mark job as completed
    job.status = 'completed';
    job.completedAt = new Date();
    job.progress.percentage = 100;
    await job.save();

    // Log activity
    try {
      await activityLogger.logActivity({
        action: 'scraper_job_completed',
        entityType: 'job',
        entityId: job._id.toString(),
        details: {
          jobType: job.jobType,
          mangaTitle: job.mangaTitle || manga?.title,
          chaptersImported: imported.length,
        },
        severity: 'info',
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

  } catch (error) {
    console.error(`Error processing AsuraScanz job ${jobId}:`, error);
    job.status = 'failed';
    job.completedAt = new Date();
    job.errorLog.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date(),
    });
    await job.save();
  }
}

// Background job processor for regular scraper jobs
async function processScraperJob(jobId, options = {}) {
  const job = await ScrapingJob.findById(jobId);
  if (!job) {
    console.error(`Job ${jobId} not found`);
    return;
  }

  try {
    job.status = 'running';
    job.startedAt = new Date();
    await job.save();

    const { type = 'full', maxItems = 100 } = options;

    // Check if job has URL (for URL-based scraping)
    const hasUrl = job.url && typeof job.url === 'string' && job.url.trim().length > 0;
    const hasSourceId = job.sourceId && (job.sourceId.toString ? job.sourceId.toString().trim().length > 0 : true);

    if (hasUrl && !hasSourceId) {
      // URL-based scraping - try to determine source or use AsuraScanz
      try {
        const urlObj = new URL(job.url);
        if (urlObj.hostname.includes('asurascanz') || urlObj.hostname.includes('asurascans')) {
          // This should have been handled as AsuraScanz job, but process it anyway
          const details = await asurascanzScraper.fetchMangaDetails(job.url);
          
          // Find or create manga
          let manga = await Manga.findOne({
            source: 'asurascanz',
            sourceUrl: details.url,
          });

          if (!manga) {
            manga = new Manga({
              title: details.title,
              description: details.synopsis,
              cover: details.cover,
              genres: details.genres || [],
              status: 'ongoing',
              source: 'asurascanz',
              sourceUrl: details.url,
            });
            await manga.save();
          }

          // Update job progress
          job.progress.total = details.chapters?.length || 0;
          job.progress.totalChapters = details.chapters?.length || 0;
          job.mangaTitle = details.title;
          await job.save();

          // Import chapters
          const chapters = details.chapters || [];
          let imported = 0;

          for (let i = 0; i < Math.min(chapters.length, maxItems); i++) {
            const ch = chapters[i];
            if (!ch.url || ch.number == null) continue;

            try {
              const pagesResult = await asurascanzScraper.fetchChapterPages(ch.url);
              const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);

              if (pageUrls.length === 0) continue;

              await Chapter.findOneAndUpdate(
                {
                  mangaId: manga._id,
                  chapterNumber: ch.number,
                },
                {
                  $set: {
                    title: ch.name || `Chapter ${ch.number}`,
                    pages: pageUrls,
                    releaseDate: parseChapterDate(ch.date),
                    isActive: true,
                  },
                },
                {
                  new: true,
                  upsert: true,
                },
              );

              imported++;
              job.progress.current = imported;
              job.progress.currentChapter = imported;
              job.progress.percentage = Math.round((imported / job.progress.total) * 100);
              await job.save();
            } catch (chapterError) {
              console.error(`Error importing chapter ${ch.number}:`, chapterError);
            }
          }

          job.status = 'completed';
          job.completedAt = new Date();
          job.progress.percentage = 100;
          await job.save();
        } else {
          throw new Error(`Unsupported URL source: ${urlObj.hostname}`);
        }
      } catch (urlError) {
        throw new Error(`Failed to process URL: ${urlError.message}`);
      }
    } else if (hasSourceId) {
      // Source-based scraping
      const source = await ScraperSource.findById(job.sourceId);
      if (!source) {
        throw new Error('Source not found');
      }

      const scraper = new ScraperEngine(source);
      await scraper.init();

      try {
        // This is a placeholder - actual implementation depends on source configuration
        // For now, just mark as completed
        job.status = 'completed';
        job.completedAt = new Date();
        job.progress.percentage = 100;
        await job.save();
      } finally {
        await scraper.close();
      }
    } else {
      // Log job details for debugging
      console.error('Job details:', {
        id: job._id,
        url: job.url,
        sourceId: job.sourceId,
        jobType: job.jobType,
        hasUrl: hasUrl,
        hasSourceId: hasSourceId,
      });
      throw new Error('Job must have either sourceId or url');
    }
  } catch (error) {
    console.error(`Error processing scraper job ${jobId}:`, error);
    job.status = 'failed';
    job.completedAt = new Date();
    job.errorLog.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date(),
    });
    await job.save();
  }
}

// ---------- AsuraComic special endpoints (direct scraper) ----------

// Search AsuraComic
router.get('/asuracomic/search', async (req, res) => {
  try {
    const { q, page, fetchAll } = req.query;
    if (!q) {
      return res.status(400).json({ message: 'q query parameter is required' });
    }

    const pageNum = page ? parseInt(page, 10) : 1;
    const fetchAllPages = fetchAll === 'true' || fetchAll === '1';
    
    const data = await asuracomicScraper.searchManga(q, { 
      page: pageNum, 
      fetchAllPages: fetchAllPages 
    });
    
    res.json(data);
  } catch (error) {
    console.error('AsuraComic search error:', error);
    res.status(500).json({ message: 'Failed to search AsuraComic' });
  }
});

// Preview AsuraComic manga (with local import info)
router.post('/asuracomic/preview', async (req, res) => {
  try {
    const { url } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'url is required' });
    }

    const details = await asuracomicScraper.fetchMangaDetails(url);

    // Check if this manga already exists in our DB
    const existingManga = await Manga.findOne({
      source: 'asuracomic',
      sourceUrl: details.url,
    }).lean();

    let existingChaptersMap = new Set();
    if (existingManga) {
      const existingChapters = await Chapter.find({
        mangaId: existingManga._id,
      })
        .select('chapterNumber')
        .lean();
      existingChaptersMap = new Set(
        existingChapters.map((c) => c.chapterNumber),
      );
    }

    const chaptersWithImportInfo = details.chapters.map((ch) => ({
      ...ch,
      exists: ch.number != null && existingChaptersMap.has(ch.number),
    }));

    res.json({
      manga: {
        ...details,
        chapters: chaptersWithImportInfo,
      },
      existingMangaId: existingManga ? existingManga._id : null,
    });
  } catch (error) {
    console.error('AsuraComic preview error:', error);
    res.status(500).json({ message: 'Failed to preview AsuraComic manga' });
  }
});

// Import AsuraComic manga + chapters into our DB
router.post('/asuracomic/import', async (req, res) => {
  try {
    const { url, chapterNumbers } = req.body;
    if (!url) {
      return res.status(400).json({ message: 'url is required' });
    }

    const details = await asuracomicScraper.fetchMangaDetails(url);

    // Find or create manga
    let manga = await Manga.findOne({
      source: 'asuracomic',
      sourceUrl: details.url,
    });

    const isNewManga = !manga;
    const mappedStatus = details.status
      ? details.status.toLowerCase()
      : 'ongoing';

    if (!manga) {
      manga = new Manga({
        title: details.title,
        description: details.synopsis,
        cover: details.cover,
        genres: details.genres || [],
        status: ['ongoing', 'completed', 'hiatus', 'cancelled'].includes(
          mappedStatus,
        )
          ? mappedStatus
          : 'ongoing',
        source: 'asuracomic',
        sourceUrl: details.url,
      });
    } else {
      manga.title = details.title || manga.title;
      manga.description = details.synopsis || manga.description;
      manga.cover = details.cover || manga.cover;
      manga.genres = details.genres?.length ? details.genres : manga.genres;
    }

    if (typeof manga.rating === 'number') {
      if (Number.isNaN(manga.rating)) manga.rating = 0;
      if (manga.rating > 5) manga.rating = 5;
      if (manga.rating < 0) manga.rating = 0;
    }

    await manga.save();

    // Determine which chapters to import
    let chaptersToImport = details.chapters;
    if (Array.isArray(chapterNumbers) && chapterNumbers.length > 0) {
      const chapterSet = new Set(
        chapterNumbers.map((n) => Number.parseInt(n, 10)),
      );
      chaptersToImport = details.chapters.filter(
        (ch) => ch.number != null && chapterSet.has(ch.number),
      );
    }

    const imported = [];

    for (const ch of chaptersToImport) {
      if (!ch.url || ch.number == null) continue;

      const pagesResult = await asuracomicScraper.fetchChapterPages(ch.url);
      const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);

      if (pageUrls.length === 0) continue;

      const releaseDate = parseChapterDate(ch.date);

      const chapterDoc = await Chapter.findOneAndUpdate(
        {
          mangaId: manga._id,
          chapterNumber: ch.number,
        },
        {
          $set: {
            title: ch.name || `Chapter ${ch.number}`,
            pages: pageUrls,
            releaseDate: releaseDate,
            isActive: true,
          },
        },
        {
          new: true,
          upsert: true,
        },
      );

      imported.push({
        chapterNumber: chapterDoc.chapterNumber,
        id: chapterDoc._id,
      });
    }

    // Update manga totalChapters
    const maxChapter = await Chapter.find({ mangaId: manga._id })
      .sort({ chapterNumber: -1 })
      .limit(1)
      .lean();
    if (maxChapter.length > 0) {
      manga.totalChapters = maxChapter[0].chapterNumber;
    }

    if (typeof manga.rating === 'number') {
      if (Number.isNaN(manga.rating)) manga.rating = 0;
      if (manga.rating > 5) manga.rating = 5;
      if (manga.rating < 0) manga.rating = 0;
    }

    await manga.save();

    // Send notifications for new chapters if any were imported
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    // Send notification for new manga if this is a new manga
    if (isNewManga && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have notifications enabled for new manga
        const users = await User.find({
          'preferences.notifications.newManga': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            const result = await firebaseFunctions.notifyNewManga(
              tokens,
              manga._id.toString(),
              manga.title,
              manga.genres || []
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new manga "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending new manga notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    res.json({
      message: 'Import completed',
      mangaId: manga._id,
      importedCount: imported.length,
      imported,
    });
  } catch (error) {
    console.error('AsuraComic import error:', error);
    res.status(500).json({ message: 'Failed to import AsuraComic manga' });
  }
});

// Create background job for AsuraComic import
router.post('/asuracomic/import-background', async (req, res) => {
  try {
    const { mangaId, url, mangaTitle, chapterNumbers } = req.body;
    
    if (!mangaId && !url) {
      return res.status(400).json({ message: 'mangaId or url is required' });
    }

    const job = new ScrapingJob({
      jobType: mangaId ? 'asuracomic_updates' : 'asuracomic_import',
      mangaId: mangaId || undefined,
      mangaUrl: url || undefined,
      mangaTitle: mangaTitle || undefined,
      chapterNumbers: chapterNumbers || undefined,
      status: 'pending',
      progress: {
        current: 0,
        total: 0,
        percentage: 0,
        currentChapter: 0,
        totalChapters: 0,
      },
    });
    await job.save();

    // Start processing in background
    processAsuraComicJob(job._id).catch((err) => {
      console.error('Failed to process AsuraComic job:', err);
    });

    res.status(201).json(job);
  } catch (error) {
    console.error('Create AsuraComic background job error:', error);
    res.status(500).json({ message: 'Failed to create background job' });
  }
});

// Check for updates for all imported AsuraComic manga
router.get('/asuracomic/updates', async (req, res) => {
  try {
    const { mangaId } = req.query;
    
    // If mangaId is provided, check only that manga
    if (mangaId) {
      const manga = await Manga.findById(mangaId).lean();
      if (!manga || manga.source !== 'asuracomic' || !manga.sourceUrl) {
        return res.status(404).json({ message: 'Manga not found or invalid' });
      }

      const fullManga = await Manga.findById(mangaId).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await asuracomicScraper.fetchMangaDetails(manga.sourceUrl);
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        return res.json({
          mangaId: manga._id,
          title: manga.title,
          sourceUrl: manga.sourceUrl,
          localMaxChapter: localMax,
          remoteMaxChapter: 0,
          hasUpdates: false,
          newChaptersCount: 0,
          newChapters: [],
          error: `Failed to fetch: ${err.message || 'Unknown error'}`,
        });
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      return res.json({
        mangaId: manga._id,
        title: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          name: ch.name,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    // Otherwise, check all manga
    // First, check if there are any manga with this source at all
    const allMangaWithSource = await Manga.find({
      source: 'asuracomic',
    })
      .select('title sourceUrl isActive')
      .lean();
    
    console.log(`Found ${allMangaWithSource.length} total manga with source 'asuracomic'`);
    
    // Filter for manga with sourceUrl and isActive
    const importedManga = allMangaWithSource.filter(m => 
      m.sourceUrl != null && m.isActive !== false
    );
    
    console.log(`Found ${importedManga.length} imported manga with sourceUrl and isActive`);

    // If no manga found, return empty array with debug info
    if (importedManga.length === 0) {
      console.log('No manga found matching criteria. Debug info:');
      console.log(`- Total manga with source 'asuracomic': ${allMangaWithSource.length}`);
      if (allMangaWithSource.length > 0) {
        const sample = allMangaWithSource[0];
        console.log(`- Sample manga:`, {
          title: sample.title,
          hasSourceUrl: !!sample.sourceUrl,
          isActive: sample.isActive,
        });
      }
      return res.json([]);
    }

    const results = [];

    for (const manga of importedManga) {
      // Get local max chapter from embedded chapters array
      const fullManga = await Manga.findById(manga._id).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await asuracomicScraper.fetchMangaDetails(
          manga.sourceUrl,
        );
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) =>
            ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        console.error(
          `Failed to fetch remote details for ${manga.title} (${manga.sourceUrl}):`,
          err.message || err,
        );
        // Still include in results but mark as error
        results.push({
          mangaId: manga._id,
          title: manga.title,
          sourceUrl: manga.sourceUrl,
          localMaxChapter: localMax,
          remoteMaxChapter: 0,
          hasUpdates: false,
          newChaptersCount: 0,
          newChapters: [],
          error: `Failed to fetch: ${err.message || 'Unknown error'}`,
        });
        continue;
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      results.push({
        mangaId: manga._id,
        title: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          name: ch.name,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    res.json(results);
  } catch (error) {
    console.error('AsuraComic updates error:', error);
    res.status(500).json({ message: 'Failed to check AsuraComic updates' });
  }
});

// Import only new chapters for a specific imported manga
router.post('/asuracomic/import-updates', async (req, res) => {
  try {
    const { mangaId } = req.body;
    if (!mangaId) {
      return res.status(400).json({ message: 'mangaId is required' });
    }

    const manga = await Manga.findById(mangaId);
    if (!manga || manga.source !== 'asuracomic' || !manga.sourceUrl) {
      return res.status(404).json({ message: 'AsuraComic manga not found' });
    }

    // Get local max chapter from embedded chapters array
    let localMax = 0;
    if (manga.chapters && Array.isArray(manga.chapters)) {
      const activeChapters = manga.chapters.filter(ch => ch.isActive !== false);
      if (activeChapters.length > 0) {
        localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
      }
    }

    const details = await asuracomicScraper.fetchMangaDetails(manga.sourceUrl);
    const remoteChapters = details.chapters || [];

    const chaptersToImport = remoteChapters.filter(
      (ch) => ch.number != null && ch.number > localMax,
    );

    const imported = [];

    for (const ch of chaptersToImport) {
      if (!ch.url || ch.number == null) continue;

      const pagesResult = await asuracomicScraper.fetchChapterPages(ch.url);
      const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);
      if (pageUrls.length === 0) continue;

      const releaseDate = parseChapterDate(ch.date);

      // Update manga's embedded chapters array
      if (!manga.chapters) {
        manga.chapters = [];
      }

      // Find existing chapter or create new
      const chapterIndex = manga.chapters.findIndex(
        c => c.chapterNumber === ch.number
      );

      const chapterData = {
        chapterNumber: ch.number,
        title: ch.name || `Chapter ${ch.number}`,
        pages: pageUrls,
        releaseDate: releaseDate,
        isActive: true,
        updatedAt: new Date(),
      };

      if (chapterIndex >= 0) {
        // Update existing chapter
        manga.chapters[chapterIndex] = {
          ...manga.chapters[chapterIndex],
          ...chapterData,
        };
      } else {
        // Add new chapter
        chapterData.createdAt = new Date();
        manga.chapters.push(chapterData);
      }

      const isNewChapter = chapterIndex < 0;
      await manga.save();

      imported.push({
        chapterNumber: ch.number,
        id: `${manga._id}_ch${ch.number}`,
      });

      // Log activity for new chapter
      if (isNewChapter) {
        try {
          await activityLogger.logActivity({
            action: 'chapter_added',
            entityType: 'chapter',
            entityId: `${manga._id}_ch${ch.number}`,
            details: {
              mangaTitle: manga.title,
              chapterNumber: ch.number,
            },
            severity: 'info',
          });
        } catch (logError) {
          console.error('Failed to log activity:', logError);
        }
      }
    }

    // Update manga totalChapters from embedded array
    if (manga.chapters && manga.chapters.length > 0) {
      const maxChapter = manga.chapters
        .filter(ch => ch.isActive !== false)
        .reduce((max, ch) => ch.chapterNumber > max ? ch.chapterNumber : max, 0);
      manga.totalChapters = maxChapter;
      await manga.save();
    }

    // Send notifications for new chapters if any were imported
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the import if notifications fail
      }
    }

    res.json({
      message: 'Update import completed',
      mangaId: manga._id,
      importedCount: imported.length,
      imported,
    });
  } catch (error) {
    console.error('AsuraComic import-updates error:', error);
    res.status(500).json({ message: 'Failed to import AsuraComic updates' });
  }
});

// Background job processor for AsuraComic imports
async function processAsuraComicJob(jobId) {
  const job = await ScrapingJob.findById(jobId);
  if (!job) {
    console.error(`Job ${jobId} not found`);
    return;
  }

  try {
    job.status = 'running';
    job.startedAt = new Date();
    await job.save();

    let manga;
    let chaptersToImport = [];
    let mangaUrl;
    let isNewManga = false; // Initialize for updates (manga already exists)

    if (job.jobType === 'asuracomic_updates' && job.mangaId) {
      manga = await Manga.findById(job.mangaId);
      if (!manga || manga.source !== 'asuracomic' || !manga.sourceUrl) {
        throw new Error('AsuraComic manga not found');
      }
      mangaUrl = manga.sourceUrl;

      // Get local max chapter from embedded array
      const localMax = manga.chapters && manga.chapters.length > 0
        ? Math.max(...manga.chapters.filter(ch => ch.isActive !== false).map(ch => ch.chapterNumber))
        : 0;

      const details = await asuracomicScraper.fetchMangaDetails(mangaUrl);
      const remoteChapters = details.chapters || [];

      chaptersToImport = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );
    } else if (job.jobType === 'asuracomic_import' && job.mangaUrl) {
      mangaUrl = job.mangaUrl;
      const details = await asuracomicScraper.fetchMangaDetails(mangaUrl);
      let allChapters = details.chapters || [];
      
      if (job.chapterNumbers && Array.isArray(job.chapterNumbers) && job.chapterNumbers.length > 0) {
        const chapterSet = new Set(
          job.chapterNumbers.map((n) => Number.parseInt(n, 10)),
        );
        chaptersToImport = allChapters.filter(
          (ch) => ch.number != null && chapterSet.has(ch.number),
        );
      } else {
        chaptersToImport = allChapters;
      }

      manga = await Manga.findOne({
        source: 'asuracomic',
        sourceUrl: details.url,
      });

      const mappedStatus = details.status
        ? details.status.toLowerCase()
        : 'ongoing';

      // Map type from scraper
      const typeMap = { 'manhwa': 'manhwa', 'manga': 'manga', 'manhua': 'manhua' };
      const mappedType = typeMap[(details.type || '').toLowerCase()] || 'manhwa';

      const isNewManga = !manga;
      if (!manga) {
        manga = new Manga({
          title: details.title,
          description: details.synopsis,
          cover: details.cover,
          genres: details.genres || [],
          status: ['ongoing', 'completed', 'hiatus', 'cancelled'].includes(
            mappedStatus,
          )
            ? mappedStatus
            : 'ongoing',
          source: 'asuracomic',
          sourceUrl: details.url,
          type: mappedType,
          rating: details.rating || 0,
          author: details.author || null,
          artist: details.artist || null,
        });
      } else {
        manga.title = details.title || manga.title;
        manga.description = details.synopsis || manga.description;
        manga.cover = details.cover || manga.cover;
        manga.genres = details.genres?.length ? details.genres : manga.genres;
        manga.type = mappedType;
        if (details.rating) manga.rating = details.rating;
        if (details.author) manga.author = details.author;
        if (details.artist) manga.artist = details.artist;
      }

      // Validate rating (max 10 from AsuraComic)
      if (typeof manga.rating === 'number') {
        if (Number.isNaN(manga.rating)) manga.rating = 0;
        if (manga.rating > 10) manga.rating = 10;
        if (manga.rating < 0) manga.rating = 0;
      }

      await manga.save();
    } else {
      throw new Error('Invalid job configuration');
    }

    job.progress.totalChapters = chaptersToImport.length;
    job.progress.total = chaptersToImport.length;
    job.mangaTitle = manga.title;
    job.isNewManga = isNewManga;
    await job.save();

    const imported = [];

    for (let i = 0; i < chaptersToImport.length; i++) {
      const ch = chaptersToImport[i];
      if (!ch.url || ch.number == null) continue;

      try {
        console.log(`Fetching pages for AsuraComic chapter ${ch.number}: ${ch.url}`);
        const pagesResult = await asuracomicScraper.fetchChapterPages(ch.url);
        const pageUrls = (pagesResult.pages || []).map((p) => p.imageUrl);

        if (pageUrls.length === 0) {
          console.warn(`No pages found for AsuraComic chapter ${ch.number} at ${ch.url}. Selector used: ${pagesResult.selectorUsed || 'none'}`);
          job.errorLog.push({
            message: `No images found for chapter ${ch.number}`,
            chapterUrl: ch.url,
            selectorUsed: pagesResult.selectorUsed || 'none',
            timestamp: new Date(),
          });
          await job.save();
          continue;
        }
        
        console.log(`Found ${pageUrls.length} pages for chapter ${ch.number}`);

        const releaseDate = parseChapterDate(ch.date);

        // Update manga's embedded chapters array
        if (!manga.chapters) {
          manga.chapters = [];
        }

        // Find existing chapter or create new
        const chapterIndex = manga.chapters.findIndex(
          c => c.chapterNumber === ch.number
        );

        const chapterData = {
          chapterNumber: ch.number,
          title: ch.name || `Chapter ${ch.number}`,
          pages: pageUrls,
          releaseDate: releaseDate,
          isActive: true,
          updatedAt: new Date(),
        };

        if (chapterIndex >= 0) {
          // Update existing chapter
          manga.chapters[chapterIndex] = {
            ...manga.chapters[chapterIndex],
            ...chapterData,
          };
        } else {
          // Add new chapter
          chapterData.createdAt = new Date();
          manga.chapters.push(chapterData);
        }

        await manga.save();

        imported.push({
          chapterNumber: ch.number,
          id: `${manga._id}_ch${ch.number}`,
        });

        // Log activity for new chapter
        try {
          await activityLogger.logActivity({
            action: 'chapter_added',
            entityType: 'chapter',
            entityId: `${manga._id}_ch${ch.number}`,
            details: {
              mangaTitle: manga.title,
              chapterNumber: ch.number,
              jobType: job.jobType,
            },
            severity: 'info',
          });
        } catch (logError) {
          console.error('Failed to log activity:', logError);
        }

        job.progress.currentChapter = i + 1;
        job.progress.current = i + 1;
        job.progress.percentage = Math.round(
          ((i + 1) / chaptersToImport.length) * 100,
        );
        await job.save();
      } catch (chapterError) {
        console.error(`Error importing chapter ${ch.number}:`, chapterError);
        job.errorLog.push({
          message: `Failed to import chapter ${ch.number}: ${chapterError.message}`,
          stack: chapterError.stack,
          timestamp: new Date(),
        });
        await job.save();
      }
    }

    // Update manga totalChapters from embedded array
    if (manga.chapters && manga.chapters.length > 0) {
      const maxChapter = manga.chapters
        .filter(ch => ch.isActive !== false)
        .reduce((max, ch) => ch.chapterNumber > max ? ch.chapterNumber : max, 0);
      manga.totalChapters = maxChapter;
      await manga.save();
    }

    // Send notifications for new chapters via Firebase Functions
    if (imported.length > 0 && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have bookmarked this manga and have notifications enabled
        const bookmarks = await Bookmark.find({ mangaId: manga._id })
          .select('userId')
          .lean();
        const bookmarkUserIds = bookmarks.map(b => b.userId);
        
        const users = await User.find({
          _id: { $in: bookmarkUserIds },
          'preferences.notifications.newChapters': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            // Get the latest imported chapter
            const latestChapter = imported[imported.length - 1];
            
            const result = await firebaseFunctions.notifyNewChapter(
              tokens,
              manga._id.toString(),
              latestChapter.chapterNumber,
              manga.title
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new chapter of "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending notifications:', notifError);
        // Don't fail the job if notifications fail
      }
    }

    // Send notification for new manga if this is a new manga
    if (isNewManga && firebaseFunctions.isConfigured()) {
      try {
        // Get users who have notifications enabled for new manga
        const users = await User.find({
          'preferences.notifications.newManga': true,
          fcmToken: { $ne: null, $exists: true },
        }).select('fcmToken').lean();

        if (users.length > 0) {
          const tokens = users.map(u => u.fcmToken).filter(Boolean);
          
          if (tokens.length > 0) {
            const result = await firebaseFunctions.notifyNewManga(
              tokens,
              manga._id.toString(),
              manga.title,
              manga.genres || []
            );

            if (result.success) {
              console.log(`✅ Sent notifications to ${result.data?.successCount || tokens.length} users for new manga "${manga.title}"`);
            } else {
              console.error(`❌ Failed to send notifications: ${result.error}`);
            }
          }
        }
      } catch (notifError) {
        console.error('Error sending new manga notifications:', notifError);
        // Don't fail the job if notifications fail
      }
    }

    job.status = 'completed';
    job.completedAt = new Date();
    job.progress.percentage = 100;
    await job.save();

    // Log activity
    try {
      await activityLogger.logActivity({
        action: 'scraper_job_completed',
        entityType: 'job',
        entityId: job._id.toString(),
        details: {
          jobType: job.jobType,
          mangaTitle: job.mangaTitle || manga?.title,
          chaptersImported: imported.length,
          isNewManga: job.isNewManga || false,
        },
        severity: 'info',
      });
    } catch (logError) {
      console.error('Failed to log activity:', logError);
    }

  } catch (error) {
    console.error(`Error processing AsuraComic job ${jobId}:`, error);
    job.status = 'failed';
    job.completedAt = new Date();
    job.errorLog.push({
      message: error.message,
      stack: error.stack,
      timestamp: new Date(),
    });
    await job.save();
  }
}

// Chapter monitoring endpoints
const chapterMonitor = require('../services/chapterMonitor');

// Get monitoring status
router.get('/monitoring/status', adminAuthMiddleware, (req, res) => {
  try {
    const status = chapterMonitor.getMonitoringStatus();
    res.json(status);
  } catch (error) {
    console.error('Get monitoring status error:', error);
    res.status(500).json({ message: 'Failed to get monitoring status' });
  }
});

// Enable/disable monitoring
router.post('/monitoring/enable', adminAuthMiddleware, (req, res) => {
  try {
    const { enabled } = req.body;
    chapterMonitor.setMonitoringEnabled(enabled === true);
    res.json({
      message: `Monitoring ${enabled ? 'enabled' : 'disabled'}`,
      status: chapterMonitor.getMonitoringStatus(),
    });
  } catch (error) {
    console.error('Set monitoring enabled error:', error);
    res.status(500).json({ message: 'Failed to set monitoring status' });
  }
});

// Set monitoring interval (cron expression)
router.post('/monitoring/interval', adminAuthMiddleware, (req, res) => {
  try {
    const { interval } = req.body;
    if (!interval || typeof interval !== 'string') {
      return res.status(400).json({ message: 'Valid cron interval is required' });
    }
    chapterMonitor.setMonitoringInterval(interval);
    res.json({
      message: 'Monitoring interval updated',
      status: chapterMonitor.getMonitoringStatus(),
    });
  } catch (error) {
    console.error('Set monitoring interval error:', error);
    res.status(500).json({ message: 'Failed to set monitoring interval' });
  }
});

// Manually trigger chapter check
router.post('/monitoring/check', adminAuthMiddleware, async (req, res) => {
  try {
    chapterMonitor.checkForNewChapters();
    res.json({ message: 'Chapter check started' });
  } catch (error) {
    console.error('Manual chapter check error:', error);
    res.status(500).json({ message: 'Failed to start chapter check' });
  }
});

// ==================== HotComics Scraper Routes ====================

// Get manga details from HotComics
router.get('/hotcomics/manga', adminAuthMiddleware, async (req, res) => {
  try {
    const { url } = req.query;
    if (!url) {
      return res.status(400).json({ message: 'url query parameter is required' });
    }

    const data = await hotcomicsScraper.fetchMangaDetails(url);
    res.json(data);
  } catch (error) {
    console.error('HotComics manga error:', error);
    res.status(500).json({ message: 'Failed to fetch HotComics manga details', error: error.message });
  }
});

// Get chapter pages from HotComics
router.get('/hotcomics/chapter', adminAuthMiddleware, async (req, res) => {
  try {
    const { url } = req.query;
    if (!url) {
      return res.status(400).json({ message: 'url query parameter is required' });
    }

    const data = await hotcomicsScraper.fetchChapterPages(url);
    res.json(data);
  } catch (error) {
    console.error('HotComics chapter error:', error);
    res.status(500).json({ message: 'Failed to fetch HotComics chapter pages', error: error.message });
  }
});

// Search HotComics
router.get('/hotcomics/search', adminAuthMiddleware, async (req, res) => {
  try {
    const { q, page } = req.query;
    if (!q) {
      return res.status(400).json({ message: 'q query parameter is required' });
    }

    const pageNum = page ? parseInt(page, 10) : 1;
    const data = await hotcomicsScraper.searchManga(q, { page: pageNum });
    res.json(data);
  } catch (error) {
    console.error('HotComics search error:', error);
    res.status(500).json({ message: 'Failed to search HotComics', error: error.message });
  }
});

// Check for updates for all imported HotComics manga
router.get('/hotcomics/updates', adminAuthMiddleware, async (req, res) => {
  try {
    const { mangaId } = req.query;
    
    // If mangaId is provided, check only that manga
    if (mangaId) {
      const manga = await Manga.findById(mangaId).lean();
      if (!manga || manga.source !== 'hotcomics' || !manga.sourceUrl) {
        return res.status(404).json({ message: 'Manga not found or invalid' });
      }

      const fullManga = await Manga.findById(mangaId).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await hotcomicsScraper.fetchMangaDetails(manga.sourceUrl);
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        return res.json({
          mangaId: manga._id,
          title: manga.title,
          sourceUrl: manga.sourceUrl,
          localMaxChapter: localMax,
          remoteMaxChapter: 0,
          hasUpdates: false,
          newChaptersCount: 0,
          newChapters: [],
          error: `Failed to fetch: ${err.message || 'Unknown error'}`,
        });
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      return res.json({
        mangaId: manga._id,
        title: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          name: ch.name,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    // Otherwise, check all manga
    const importedManga = await Manga.find({
      source: 'hotcomics',
      sourceUrl: { $ne: null },
      isActive: true,
    })
      .select('title sourceUrl')
      .lean();

    const results = [];

    for (const manga of importedManga) {
      // Get local max chapter from embedded chapters array
      const fullManga = await Manga.findById(manga._id).lean();
      let localMax = 0;
      if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
        const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
        if (activeChapters.length > 0) {
          localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
        }
      }

      let remoteMax = 0;
      let remoteChapters = [];

      try {
        const details = await hotcomicsScraper.fetchMangaDetails(
          manga.sourceUrl,
        );
        remoteChapters = details.chapters || [];
        remoteMax = remoteChapters.reduce(
          (max, ch) =>
            ch.number != null && ch.number > max ? ch.number : max,
          0,
        );
      } catch (err) {
        console.error(
          `Failed to fetch remote details for ${manga.sourceUrl}`,
          err,
        );
        continue;
      }

      const hasUpdates = remoteMax > localMax;
      const newChapters = remoteChapters.filter(
        (ch) => ch.number != null && ch.number > localMax,
      );

      results.push({
        mangaId: manga._id,
        mangaTitle: manga.title,
        sourceUrl: manga.sourceUrl,
        localMaxChapter: localMax,
        remoteMaxChapter: remoteMax,
        hasUpdates,
        newChaptersCount: newChapters.length,
        newChapters: newChapters.map((ch) => ({
          number: ch.number,
          title: ch.title,
          url: ch.url,
          date: ch.date,
        })),
      });
    }

    res.json(results);
  } catch (error) {
    console.error('HotComics updates error:', error);
    res.status(500).json({ message: 'Failed to check HotComics updates' });
  }
});

// Import manga from HotComics
router.post('/hotcomics/import', adminAuthMiddleware, async (req, res) => {
  try {
    const { url, downloadToFirebase = false } = req.body;

    if (!url) {
      return res.status(400).json({ message: 'url is required' });
    }

    console.log(`Starting HotComics import for: ${url}`);
    console.log(`Download to Firebase: ${downloadToFirebase}`);

    // Fetch manga details
    const mangaData = await hotcomicsScraper.fetchMangaDetails(url);

    // Create or update manga
    let manga = await Manga.findOne({ sourceUrl: url });

    const isNewManga = !manga;

    if (!manga) {
      manga = new Manga({
        title: mangaData.title,
        description: mangaData.description,
        cover: mangaData.cover,
        genres: mangaData.genres,
        source: 'hotcomics',
        sourceUrl: url,
        isAdult: mangaData.isAdult,
        ageRating: mangaData.ageRating,
        freeChapters: 3,
        status: mangaData.status || 'ongoing',
        author: mangaData.author,
        type: 'comic',
      });
    } else {
      // Update existing manga
      manga.title = mangaData.title;
      manga.description = mangaData.description;
      manga.cover = mangaData.cover || manga.cover;
      manga.genres = mangaData.genres;
      manga.isAdult = mangaData.isAdult;
      manga.ageRating = mangaData.ageRating;
      manga.status = mangaData.status || manga.status;
      manga.author = mangaData.author || manga.author;
    }

    // Process chapters
    let newChaptersCount = 0;
    for (const chapterData of mangaData.chapters) {
      const chapterNum = chapterData.number;

      // Check if chapter exists
      const existingChapter = manga.chapters.find(
        (ch) => ch.chapterNumber === chapterNum,
      );

      if (!existingChapter) {
        console.log(`Fetching pages for chapter ${chapterNum}...`);

        // Fetch chapter pages
        const pages = await hotcomicsScraper.fetchChapterPages(chapterData.url);

        let pageUrls = pages.map((p) => p.imageUrl);

        // Download to Firebase if requested
        if (downloadToFirebase && firebaseStorage.isConfigured() && pages.length > 0) {
          try {
            console.log(`Uploading ${pages.length} images to Firebase Storage...`);
            pageUrls = await firebaseStorage.uploadChapterImages(
              manga._id.toString(),
              chapterNum,
              pages.map((p) => p.imageUrl),
            );
            console.log(`✅ Successfully uploaded ${pageUrls.length} images to Firebase`);
          } catch (firebaseError) {
            console.error('Firebase upload failed, using original URLs:', firebaseError);
            // Continue with original URLs as fallback
          }
        }

        // Determine if chapter is locked (after first 3)
        const isLocked = chapterNum > manga.freeChapters;

        manga.chapters.push({
          chapterNumber: chapterNum,
          title: chapterData.title,
          pages: pageUrls,
          releaseDate: chapterData.date ? new Date(chapterData.date) : new Date(),
          isLocked,
          firebaseStoragePath: downloadToFirebase && firebaseStorage.isConfigured()
            ? `manga/${manga._id}/ch${chapterNum}/`
            : null,
        });

        newChaptersCount++;
      }
    }

    manga.totalChapters = manga.chapters.length;
    await manga.save();

    // Send notifications if new manga or new chapters
    if (firebaseFunctions.isConfigured()) {
      try {
        if (isNewManga && mangaData.isAdult === false) {
          // Only notify for non-adult new manga
          await firebaseFunctions.notifyNewManga(manga._id.toString());
        }

        if (newChaptersCount > 0 && mangaData.isAdult === false) {
          // Only notify for non-adult manga chapters
          await firebaseFunctions.notifyNewChapter(
            manga._id.toString(),
            newChaptersCount,
          );
        }
      } catch (notifError) {
        console.error('Notification error:', notifError);
      }
    }

    res.json({
      success: true,
      manga,
      isNewManga,
      newChaptersCount,
      totalChapters: manga.chapters.length,
    });
  } catch (error) {
    console.error('HotComics import error:', error);
    res.status(500).json({
      message: 'Failed to import manga',
      error: error.message,
    });
  }
});

// Process HotComics job
async function processHotComicsJob(jobId) {
  try {
    const job = await ScrapingJob.findById(jobId);
    if (!job) {
      console.error(`Job ${jobId} not found`);
      return;
    }

    if (job.status === 'completed' || job.status === 'failed') {
      return; // Already processed
    }

    job.status = 'running';
    await job.save();

    const url = job.url || job.mangaUrl;
    if (!url) {
      throw new Error('URL is required for HotComics import');
    }

    // Use the existing hotcomics import logic
    const mangaData = await hotcomicsScraper.fetchMangaDetails(url);
    
    // Find or create manga
    let manga = await Manga.findOne({
      source: 'hotcomics',
      sourceUrl: mangaData.url || url,
    });

    const isNewManga = !manga;

    if (!manga) {
      manga = new Manga({
        title: mangaData.title,
        description: mangaData.description,
        cover: mangaData.cover,
        genres: mangaData.genres || [],
        source: 'hotcomics',
        sourceUrl: mangaData.url || url,
        isAdult: mangaData.isAdult !== false,
        ageRating: mangaData.ageRating || '18+',
        freeChapters: 3,
        status: mangaData.status || 'ongoing',
        author: mangaData.author || 'Unknown',
        type: 'comic',
      });
    } else {
      // Update existing manga
      manga.title = mangaData.title;
      manga.description = mangaData.description;
      manga.cover = mangaData.cover || manga.cover;
      manga.genres = mangaData.genres || manga.genres;
      manga.isAdult = mangaData.isAdult !== false;
      manga.ageRating = mangaData.ageRating || manga.ageRating;
      manga.status = mangaData.status || manga.status;
      manga.author = mangaData.author || manga.author;
    }

    // Save manga first to get a valid _id (required for Firebase Storage folder structure)
    await manga.save();

    // Process chapters
    const chapters = mangaData.chapters || [];
    job.progress.totalChapters = chapters.length;
    job.progress.currentChapter = 0;
    await job.save();

    let newChaptersCount = 0;
    for (let i = 0; i < chapters.length; i++) {
      const chapterData = chapters[i];
      const chapterNum = chapterData.number || (i + 1);
      
      job.progress.currentChapter = i + 1;
      job.progress.percentage = Math.round(((i + 1) / chapters.length) * 100);
      await job.save();

      // Check if chapter exists
      const existingChapter = manga.chapters.find(
        (ch) => ch.chapterNumber === chapterNum,
      );

      if (!existingChapter) {
        try {
          console.log(`Fetching pages for chapter ${chapterNum}...`);
          const pages = await hotcomicsScraper.fetchChapterPages(chapterData.url);
          
          if (!pages || pages.length === 0) {
            console.warn(`No pages found for chapter ${chapterNum}`);
            continue;
          }

          // Use original URLs directly - no Firebase Storage
          let pageUrls = pages.map((p) => p.imageUrl || p);
          
          console.log(`✅ Found ${pageUrls.length} pages for chapter ${chapterNum}`);
          console.log(`   Using original URLs directly (no Firebase Storage)`);

          // Determine if chapter is locked (after first 3)
          const isLocked = chapterNum > manga.freeChapters;

          // Reload manga to get latest state
          manga = await Manga.findById(manga._id);

          // Ensure chapters array exists
          if (!manga.chapters) {
            manga.chapters = [];
          }

          manga.chapters.push({
            chapterNumber: chapterNum,
            title: chapterData.title || `Chapter ${chapterNum}`,
            pages: pageUrls, // Direct URLs from hotcomics.io
            releaseDate: chapterData.date ? new Date(chapterData.date) : new Date(),
            isLocked,
            isActive: true, // Explicitly set isActive to true
            createdAt: new Date(),
            updatedAt: new Date(),
          });

          await manga.save();
          console.log(`✅ Chapter ${chapterNum} saved to database with ${pageUrls.length} pages`);
          newChaptersCount++;
        } catch (chapterError) {
          console.error(`Error processing chapter ${chapterNum}:`, chapterError);
          job.errorLog.push({
            message: `Chapter ${chapterNum} error: ${chapterError.message}`,
            stack: chapterError.stack,
            timestamp: new Date(),
          });
          await job.save();
        }
      }
    }

    // Reload manga to get latest chapters count
    manga = await Manga.findById(manga._id);
    
    // Update totalChapters based on active chapters
    if (manga.chapters && manga.chapters.length > 0) {
      const activeChapters = manga.chapters.filter(ch => ch.isActive !== false);
      manga.totalChapters = activeChapters.length > 0 
        ? Math.max(...activeChapters.map(ch => ch.chapterNumber || 0))
        : 0;
    } else {
      manga.totalChapters = 0;
    }
    
    await manga.save();

    job.status = 'completed';
    job.progress.percentage = 100;
    job.mangaId = manga._id;
    job.mangaTitle = manga.title;
    await job.save();

    console.log(`✅ HotComics job ${jobId} completed successfully`);
    console.log(`   Manga: ${manga.title}`);
    console.log(`   Total chapters: ${manga.totalChapters}`);
    console.log(`   New chapters added: ${newChaptersCount}`);
  } catch (error) {
    console.error(`HotComics job ${jobId} failed:`, error);
    const job = await ScrapingJob.findById(jobId);
    if (job) {
      job.status = 'failed';
      job.error = error.message;
      await job.save();
    }
  }
}

// Export job processors for monitoring service
module.exports = router;
module.exports.processAsuraScanzJob = processAsuraScanzJob;
module.exports.processAsuraComicJob = processAsuraComicJob;
module.exports.processHotComicsJob = processHotComicsJob;

