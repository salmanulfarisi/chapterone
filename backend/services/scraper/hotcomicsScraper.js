const axios = require('axios');
const cheerio = require('cheerio');
const { URL } = require('url');

// Special scraper for https://hotcomics.io

const BASE_URL = 'https://hotcomics.io';

// Rate limiting: minimum delay between requests (ms)
const MIN_REQUEST_DELAY = 1500; // 1.5 seconds
let lastRequestTime = 0;

// Retry configuration
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds

function absoluteUrl(href) {
  if (!href) return null;
  try {
    return new URL(href, BASE_URL).href;
  } catch {
    return href;
  }
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchHtml(url, options = {}) {
  const now = Date.now();
  const timeSinceLastRequest = now - lastRequestTime;
  if (timeSinceLastRequest < MIN_REQUEST_DELAY) {
    await delay(MIN_REQUEST_DELAY - timeSinceLastRequest);
  }
  lastRequestTime = Date.now();

  return await retry(async () => {
    try {
      const res = await axios.get(url, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          Accept:
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          Referer: BASE_URL,
        },
        timeout: options.timeout || 30000,
        maxRedirects: 5,
        validateStatus: (status) => status >= 200 && status < 400,
      });

      if (!res.data || typeof res.data !== 'string') {
        throw new Error('Invalid response: expected HTML string');
      }

      return res.data;
    } catch (error) {
      if (error.response) {
        throw new Error(
          `HTTP ${error.response.status}: ${error.response.statusText}`,
        );
      } else if (error.request) {
        throw new Error('Network error: No response received');
      } else {
        throw new Error(`Request setup error: ${error.message}`);
      }
    }
  });
}

async function retry(fn, retries = MAX_RETRIES) {
  try {
    return await fn();
  } catch (error) {
    if (retries > 0) {
      await delay(RETRY_DELAY);
      return retry(fn, retries - 1);
    }
    throw error;
  }
}

/**
 * Extract URL from CSS background-image property
 */
function extractUrlFromBackground(backgroundValue) {
  if (!backgroundValue) return null;
  const match = backgroundValue.match(/url\(['"]?([^'"]+)['"]?\)/);
  return match ? match[1] : null;
}

/**
 * Fetch manga details from a manga detail page
 */
async function fetchMangaDetails(mangaUrl) {
  const url = absoluteUrl(mangaUrl);
  const html = await fetchHtml(url, { timeout: 45000 });
  const $ = cheerio.load(html);

  // Extract title
  const title =
    $('.episode-title span').text().trim() ||
    $('h2.episode-title').text().trim() ||
    $('h1').first().text().trim() ||
    '';

  if (!title) {
    throw new Error('Could not extract manga title from page');
  }

  // Extract cover image from background-image CSS
  let cover = null;
  const coverStyle = $('.ep-cover_ch').attr('style') || $('.inner_ch').attr('style');
  if (coverStyle) {
    cover = extractUrlFromBackground(coverStyle);
  }
  // Fallback to img tag
  if (!cover) {
    cover = $('.ep-cover_ch img, .inner_ch img').attr('src') ||
            $('.ep-cover_ch img, .inner_ch img').attr('data-src');
  }
  cover = cover ? absoluteUrl(cover) : null;

  // Extract description
  const description = $('.desc-text').text().trim() || '';

  // Extract genres
  const genres = [];
  const genreText = $('.type_box .type').text().trim();
  if (genreText) {
    genreText.split('/').forEach((g) => {
      const genre = g.trim();
      if (genre && !genres.includes(genre)) {
        genres.push(genre);
      }
    });
  }

  // Check for 18+ tag
  const isAdult = $('.tag-list .tag').text().includes('18+') ||
                  $('.ico-18plus').length > 0;

  // Extract status from update schedule
  let status = 'ongoing';
  const updateText = $('.text-red').text().trim().toLowerCase();
  if (updateText.includes('end') || updateText.includes('completed')) {
    status = 'completed';
  }

  // Extract author/artist
  const writerText = $('.writer').text().trim();
  const author = writerText.replace('ⓒ', '').trim() || null;

  // Extract chapters from .list-ep li
  const chapters = [];
  $('.list-ep li').each((_, el) => {
    const $li = $(el);
    const chapterNumText = $li.find('.cell-num .num').text().trim();
    const chapterNum = parseInt(chapterNumText) || chapters.length + 1;

    // Extract URL from onclick attribute
    const onclickAttr = $li.find('a').attr('onclick') || '';
    const urlMatch = onclickAttr.match(/popupLogin\(['"]([^'"]+)['"]/);
    const chapterUrl = urlMatch ? urlMatch[1] : null;

    if (chapterUrl) {
      const chapterTitle = $li.find('.cell-title strong').text().trim() || 
                          `Episode ${chapterNum}`;
      const thumbnail = $li.find('.thumb img').attr('src') ||
                       $li.find('.thumb img').attr('data-src');
      const dateText = $li.find('time').attr('datetime') ||
                      $li.find('.cell-time time').text().trim();

      chapters.push({
        number: chapterNum,
        url: absoluteUrl(chapterUrl),
        title: chapterTitle,
        thumbnail: thumbnail ? absoluteUrl(thumbnail) : null,
        date: dateText,
      });
    }
  });

  // Sort chapters by number (ascending)
  chapters.sort((a, b) => a.number - b.number);

  return {
    source: 'hotcomics',
    url,
    title,
    cover,
    description,
    genres,
    status,
    author,
    isAdult,
    ageRating: isAdult ? '18+' : 'all',
    chapters,
  };
}

/**
 * Fetch chapter pages (images) from a chapter URL
 */
async function fetchChapterPages(chapterUrl) {
  const url = absoluteUrl(chapterUrl);
  const html = await fetchHtml(url, { timeout: 45000 });
  const $ = cheerio.load(html);

  const pages = [];
  const seenUrls = new Set();

  // Primary method: Extract from .viewer-imgs container (hotcomics.io structure)
  const viewerImgs = $('.viewer-imgs, #viewer-img');
  if (viewerImgs.length > 0) {
    // Find all img elements inside .lazy divs
    viewerImgs.find('.lazy img, img[id^="set_image_"]').each((_, el) => {
      const $img = $(el);
      let imgUrl = $img.attr('src') ||
                   $img.attr('data-src') ||
                   $img.attr('data-lazy-src') ||
                   $img.attr('data-original');

      if (imgUrl) {
        // Preserve full URL including query parameters (e.g., ?sda2=1)
        // These parameters might be required for the images to load
        imgUrl = absoluteUrl(imgUrl);
        
        if (!seenUrls.has(imgUrl)) {
          seenUrls.add(imgUrl);
          
          // Extract index from id attribute (e.g., "set_image_0" -> 0)
          const id = $img.attr('id') || '';
          const indexMatch = id.match(/set_image_(\d+)/);
          const index = indexMatch ? parseInt(indexMatch[1], 10) : pages.length;
          
          pages.push({
            index,
            imageUrl: imgUrl,
          });
        }
      }
    });

    // Sort by index to ensure correct order
    if (pages.length > 0) {
      pages.sort((a, b) => a.index - b.index);
      return pages;
    }
  }

  // Fallback: Try multiple selectors for chapter images
  const selectors = [
    '.reader-content img',
    '.chapter-images img',
    '.ep-reader img',
    '.reading-content img',
    '#reader img',
    '.comic-reader img',
    '.viewer-body img',
  ];

  for (const selector of selectors) {
    $(selector).each((_, el) => {
      const $img = $(el);
      let imgUrl = $img.attr('src') ||
                   $img.attr('data-src') ||
                   $img.attr('data-lazy-src') ||
                   $img.attr('data-original');

      if (imgUrl) {
        // Skip banner/ads images
        if (imgUrl.includes('banner') || imgUrl.includes('ad') || 
            imgUrl.includes('logo') || imgUrl.includes('icon')) {
          return;
        }
        
        imgUrl = absoluteUrl(imgUrl);
        if (!seenUrls.has(imgUrl)) {
          seenUrls.add(imgUrl);
          pages.push({
            index: pages.length,
            imageUrl: imgUrl,
          });
        }
      }
    });

    if (pages.length > 0) break;
  }

  // If no images found, try to extract from script tags
  if (pages.length === 0) {
    const scriptTags = $('script').toArray();
    for (const script of scriptTags) {
      const scriptContent = $(script).html() || '';
      
      // Look for image arrays in JavaScript
      const imageArrayMatch = scriptContent.match(/images\s*[:=]\s*\[(.*?)\]/s);
      if (imageArrayMatch) {
        const imageUrls = imageArrayMatch[1]
          .split(',')
          .map((url) => url.trim().replace(/['"]/g, ''))
          .filter((url) => url && url.startsWith('http'));

        imageUrls.forEach((imgUrl, index) => {
          const absoluteImgUrl = absoluteUrl(imgUrl);
          if (!seenUrls.has(absoluteImgUrl)) {
            seenUrls.add(absoluteImgUrl);
            pages.push({
              index,
              imageUrl: absoluteImgUrl,
            });
          }
        });
        break;
      }
    }
  }

  if (pages.length === 0) {
    throw new Error('No chapter images found on page');
  }

  return pages;
}

/**
 * Search manga on hotcomics.io
 */
async function searchManga(query, options = {}) {
  const { page = 1 } = options;
  const searchUrl = `${BASE_URL}/en/search?q=${encodeURIComponent(query)}&page=${page}`;
  
  const html = await fetchHtml(searchUrl);
  const $ = cheerio.load(html);

  const results = [];

  // Extract search results - adjust selectors based on actual search page structure
  $('.list-sidebar li, .manga-item, .search-result-item').each((_, el) => {
    const $item = $(el);
    const $link = $item.find('a').first();
    const link = absoluteUrl($link.attr('href'));
    const title = $item.find('.tit, .title, h3, h4').text().trim();
    const cover = $item.find('img').attr('src') || $item.find('img').attr('data-src');
    const description = $item.find('.excerpt, .description').text().trim();

    if (title && link) {
      results.push({
        source: 'hotcomics',
        title,
        url: link,
        cover: cover ? absoluteUrl(cover) : null,
        description,
      });
    }
  });

  return results;
}

module.exports = {
  fetchMangaDetails,
  fetchChapterPages,
  searchManga,
  BASE_URL,
};

