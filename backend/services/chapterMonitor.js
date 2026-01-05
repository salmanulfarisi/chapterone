const cron = require('node-cron');
const Manga = require('../models/Manga');
const ScrapingJob = require('../models/ScrapingJob');
const asurascanzScraper = require('./scraper/asurascanzScraper');
const asuracomicScraper = require('./scraper/asuracomicScraper');
const hotcomicsScraper = require('./scraper/hotcomicsScraper');

let monitoringEnabled = true; // Default to enabled
let monitoringInterval = '0 */6 * * *'; // Every 6 hours by default
let cronJob = null;

/**
 * Check for new chapters and create import jobs
 */
async function checkForNewChapters() {
  if (!monitoringEnabled) {
    console.log('Chapter monitoring is disabled');
    return;
  }

  console.log('Starting automatic chapter monitoring check...');
  
  try {
    // Check AsuraScanz manga
    const asurascanzManga = await Manga.find({
      source: 'asurascanz',
      sourceUrl: { $ne: null },
      isActive: true,
    }).select('_id title sourceUrl').lean();

    for (const manga of asurascanzManga) {
      try {
        // Get local max chapter from embedded chapters
        const fullManga = await Manga.findById(manga._id).lean();
        let localMax = 0;
        if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
          const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
          if (activeChapters.length > 0) {
            localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
          }
        }

        // Fetch remote details
        const details = await asurascanzScraper.fetchMangaDetails(manga.sourceUrl);
        const remoteChapters = details.chapters || [];
        const remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );

        // If there are new chapters, create an update job
        if (remoteMax > localMax) {
          const newChapters = remoteChapters.filter(
            (ch) => ch.number != null && ch.number > localMax,
          );

          console.log(`Found ${newChapters.length} new chapters for "${manga.title}"`);

          // Check if there's already a pending/running job for this manga
          const existingJob = await ScrapingJob.findOne({
            mangaId: manga._id,
            jobType: 'asurascanz_updates',
            status: { $in: ['pending', 'running'] },
          });

          if (!existingJob) {
            const job = new ScrapingJob({
              jobType: 'asurascanz_updates',
              mangaId: manga._id,
              mangaTitle: manga.title,
              status: 'pending',
              progress: {
                current: 0,
                total: newChapters.length,
                percentage: 0,
                currentChapter: 0,
                totalChapters: newChapters.length,
              },
            });
            await job.save();
            console.log(`Created update job for "${manga.title}"`);
            
            // Start processing the job
            // Import the job processor function directly
            const scraperModule = require('../routes/scraper');
            // The function is exported as a property of the module
            if (scraperModule.processAsuraScanzJob) {
              scraperModule.processAsuraScanzJob(job._id).catch(err => {
                console.error(`Error processing auto-update job for ${manga.title}:`, err);
              });
            } else {
              console.error('processAsuraScanzJob not found in scraper module');
            }
          }
        }
      } catch (err) {
        console.error(`Error checking updates for "${manga.title}":`, err.message);
      }
    }

    // Check AsuraComic manga
    const asuracomicManga = await Manga.find({
      source: 'asuracomic',
      sourceUrl: { $ne: null },
      isActive: true,
    }).select('_id title sourceUrl').lean();

    for (const manga of asuracomicManga) {
      try {
        // Get local max chapter from embedded chapters
        const fullManga = await Manga.findById(manga._id).lean();
        let localMax = 0;
        if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
          const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
          if (activeChapters.length > 0) {
            localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
          }
        }

        // Fetch remote details
        const details = await asuracomicScraper.fetchMangaDetails(manga.sourceUrl);
        const remoteChapters = details.chapters || [];
        const remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );

        // If there are new chapters, create an update job
        if (remoteMax > localMax) {
          const newChapters = remoteChapters.filter(
            (ch) => ch.number != null && ch.number > localMax,
          );

          console.log(`Found ${newChapters.length} new chapters for "${manga.title}"`);

          // Check if there's already a pending/running job for this manga
          const existingJob = await ScrapingJob.findOne({
            mangaId: manga._id,
            jobType: 'asuracomic_updates',
            status: { $in: ['pending', 'running'] },
          });

          if (!existingJob) {
            const job = new ScrapingJob({
              jobType: 'asuracomic_updates',
              mangaId: manga._id,
              mangaTitle: manga.title,
              status: 'pending',
              progress: {
                current: 0,
                total: newChapters.length,
                percentage: 0,
                currentChapter: 0,
                totalChapters: newChapters.length,
              },
            });
            await job.save();
            console.log(`Created update job for "${manga.title}"`);
            
            // Start processing the job
            // Import the job processor function directly
            const scraperModule = require('../routes/scraper');
            // The function is exported as a property of the module
            if (scraperModule.processAsuraComicJob) {
              scraperModule.processAsuraComicJob(job._id).catch(err => {
                console.error(`Error processing auto-update job for ${manga.title}:`, err);
              });
            } else {
              console.error('processAsuraComicJob not found in scraper module');
            }
          }
        }
      } catch (err) {
        console.error(`Error checking updates for "${manga.title}":`, err.message);
      }
    }

    // Check HotComics manga
    const hotcomicsManga = await Manga.find({
      source: 'hotcomics',
      sourceUrl: { $ne: null },
      isActive: true,
    }).select('_id title sourceUrl').lean();

    for (const manga of hotcomicsManga) {
      try {
        // Get local max chapter from embedded chapters
        const fullManga = await Manga.findById(manga._id).lean();
        let localMax = 0;
        if (fullManga && fullManga.chapters && Array.isArray(fullManga.chapters)) {
          const activeChapters = fullManga.chapters.filter(ch => ch.isActive !== false);
          if (activeChapters.length > 0) {
            localMax = Math.max(...activeChapters.map(ch => ch.chapterNumber || 0));
          }
        }

        // Fetch remote details
        const details = await hotcomicsScraper.fetchMangaDetails(manga.sourceUrl);
        const remoteChapters = details.chapters || [];
        const remoteMax = remoteChapters.reduce(
          (max, ch) => ch.number != null && ch.number > max ? ch.number : max,
          0,
        );

        // If there are new chapters, create an update job
        if (remoteMax > localMax) {
          const newChapters = remoteChapters.filter(
            (ch) => ch.number != null && ch.number > localMax,
          );

          console.log(`Found ${newChapters.length} new chapters for "${manga.title}"`);

          // Check if there's already a pending/running job for this manga
          const existingJob = await ScrapingJob.findOne({
            mangaId: manga._id,
            jobType: 'hotcomics_updates',
            status: { $in: ['pending', 'running'] },
          });

          if (!existingJob) {
            const job = new ScrapingJob({
              jobType: 'hotcomics_updates',
              mangaId: manga._id,
              mangaUrl: manga.sourceUrl,
              mangaTitle: manga.title,
              status: 'pending',
              progress: {
                current: 0,
                total: newChapters.length,
                percentage: 0,
                currentChapter: 0,
                totalChapters: newChapters.length,
              },
            });
            await job.save();
            console.log(`Created update job for "${manga.title}"`);
            
            // Start processing the job
            const scraperModule = require('../routes/scraper');
            if (scraperModule.processHotComicsJob) {
              scraperModule.processHotComicsJob(job._id).catch(err => {
                console.error(`Error processing auto-update job for ${manga.title}:`, err);
              });
            } else {
              console.error('processHotComicsJob not found in scraper module');
            }
          }
        }
      } catch (err) {
        console.error(`Error checking updates for "${manga.title}":`, err.message);
      }
    }

    console.log('Automatic chapter monitoring check completed');
  } catch (error) {
    console.error('Error in automatic chapter monitoring:', error);
  }
}

/**
 * Start the monitoring cron job
 */
function startMonitoring() {
  if (cronJob) {
    cronJob.stop();
  }

  if (!monitoringEnabled) {
    console.log('Chapter monitoring is disabled');
    return;
  }

  cronJob = cron.schedule(monitoringInterval, () => {
    checkForNewChapters();
  }, {
    scheduled: true,
    timezone: 'UTC',
  });

  console.log(`Chapter monitoring started with schedule: ${monitoringInterval}`);
}

/**
 * Stop the monitoring cron job
 */
function stopMonitoring() {
  if (cronJob) {
    cronJob.stop();
    cronJob = null;
    console.log('Chapter monitoring stopped');
  }
}

/**
 * Set monitoring enabled/disabled
 */
function setMonitoringEnabled(enabled) {
  monitoringEnabled = enabled;
  if (enabled) {
    startMonitoring();
  } else {
    stopMonitoring();
  }
}

/**
 * Set monitoring interval (cron expression)
 */
function setMonitoringInterval(interval) {
  monitoringInterval = interval;
  if (monitoringEnabled) {
    startMonitoring();
  }
}

/**
 * Get monitoring status
 */
function getMonitoringStatus() {
  return {
    enabled: monitoringEnabled,
    interval: monitoringInterval,
    running: cronJob !== null,
  };
}

// Start monitoring on module load if enabled
if (monitoringEnabled) {
  // Wait a bit for MongoDB connection
  setTimeout(() => {
    startMonitoring();
  }, 5000);
}

module.exports = {
  checkForNewChapters,
  startMonitoring,
  stopMonitoring,
  setMonitoringEnabled,
  setMonitoringInterval,
  getMonitoringStatus,
};
