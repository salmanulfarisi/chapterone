const axios = require('axios');
const cheerio = require('cheerio');
const { URL } = require('url');

// Special scraper for https://asurascanz.com (AsuraScanz)

const BASE_URL = 'https://asurascanz.com';

// Rate limiting: minimum delay between requests (ms)
const MIN_REQUEST_DELAY = 1000; // 1 second
let lastRequestTime = 0;

// Retry configuration
const MAX_RETRIES = 3;
const RETRY_DELAY = 2000; // 2 seconds

function absoluteUrl(href) {
  if (!href) return null;
  try {
    return new URL(href, BASE_URL).toString();
  } catch {
    return href;
  }
}

// Rate limiting delay helper
async function rateLimit() {
  const now = Date.now();
  const timeSinceLastRequest = now - lastRequestTime;
  if (timeSinceLastRequest < MIN_REQUEST_DELAY) {
    await new Promise((res) =>
      setTimeout(res, MIN_REQUEST_DELAY - timeSinceLastRequest),
    );
  }
  lastRequestTime = Date.now();
}

// Retry wrapper with exponential backoff
async function retryWithBackoff(fn, retries = MAX_RETRIES) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      await rateLimit(); // Apply rate limiting before each request
      return await fn();
    } catch (error) {
      if (attempt === retries) {
        throw error;
      }
      const delay = RETRY_DELAY * Math.pow(2, attempt); // Exponential backoff
      console.log(
        `Request failed (attempt ${attempt + 1}/${retries + 1}), retrying in ${delay}ms...`,
      );
      await new Promise((res) => setTimeout(res, delay));
    }
  }
}

async function fetchHtml(url, options = {}) {
  const defaultHeaders = {
    'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    Referer: BASE_URL,
    Accept:
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    Connection: 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };

  return retryWithBackoff(async () => {
    try {
      const res = await axios.get(url, {
        headers: { ...defaultHeaders, ...options.headers },
        timeout: options.timeout || 30000, // 30 second default timeout
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

/**
 * Fetch manga list (e.g. home / latest / related) using .listupd .bs .bsx cards
 */
async function fetchHomeManga({ page = 1 } = {}) {
  const url = page === 1 ? BASE_URL : `${BASE_URL}/page/${page}/`;
  const html = await fetchHtml(url);
  const $ = cheerio.load(html);

  const results = [];

  $('.listupd .bs .bsx').each((_, el) => {
    const $card = $(el);
    const $a = $card.find('a').first();

    const link = absoluteUrl($a.attr('href'));
    const title = $card.find('.bigor .tt').text().trim();

    let cover =
      $card.find('.limit img').attr('data-src') ||
      $card.find('.limit img').attr('src') ||
      null;
    cover = cover ? absoluteUrl(cover) : null;

    const latestChapter = $card.find('.adds .epxs').text().trim();
    const rating = $card.find('.numscore').text().trim();

    if (!title || !link) return;

    results.push({
      source: 'asurascanz',
      title,
      url: link,
      cover,
      latestChapter,
      rating,
    });
  });

  return results;
}

/**
 * Fetch manga details + chapter list from a manga detail URL
 * Enhanced with better parsing and fallback selectors
 */
async function fetchMangaDetails(mangaUrl) {
  const url = absoluteUrl(mangaUrl);
  const html = await fetchHtml(url);
  const $ = cheerio.load(html);

  // Try multiple selectors for title
  const title =
    $('h1.entry-title').first().text().trim() ||
    $('h1').first().text().trim() ||
    $('.entry-title').first().text().trim() ||
    '';

  if (!title) {
    throw new Error('Could not extract manga title from page');
  }

  // Try multiple selectors for cover
  let cover =
    $('.info-left .thumb img').attr('src') ||
    $('.info-left .thumb img').attr('data-src') ||
    $('.info-left .thumb img').attr('data-lazy-src') ||
    $('.thumb img').first().attr('src') ||
    $('.thumb img').first().attr('data-src') ||
    null;
  cover = cover ? absoluteUrl(cover) : null;

  // Extract genres with fallback selectors
  const genres = [];
  $('.wd-full .mgen a, .mgen a, [class*="genre"] a').each((_, el) => {
    const g = $(el).text().trim();
    if (g && !genres.includes(g)) genres.push(g);
  });

  // Extract status with better pattern matching
  let status = null;
  $('.tsinfo .imptdt, .info-item').each((_, el) => {
    const label = $(el).text().trim().toLowerCase();
    if (/status/i.test(label)) {
      status =
        $(el).find('i').text().trim() ||
        $(el).text().replace(/status/i, '').trim() ||
        null;
    }
  });

  // Extract synopsis with fallback
  const synopsis =
    $('.entry-content.entry-content-single').text().trim() ||
    $('.entry-content').text().trim() ||
    $('.description').text().trim() ||
    '';

  // Extract chapters with improved parsing
  const chapters = [];
  $('#chapterlist li, .wp-manga-chapter a, [class*="chapter"] a').each(
    (_, el) => {
      const $el = $(el);
      const $a = $el.is('a') ? $el : $el.find('a').first();
      const link = absoluteUrl($a.attr('href'));

      if (!link) return;

      // Try multiple ways to extract chapter number
      const num =
        $el.attr('data-num') ||
        $el.find('[data-num]').attr('data-num') ||
        $a.attr('data-num') ||
        null;

      // Extract chapter name
      const name =
        $el.find('span.chapternum').text().trim() ||
        $a.text().trim() ||
        `Chapter ${num || ''}`.trim();

      // Extract date
      const date =
        $el.find('span.chapterdate').text().trim() ||
        $el.find('[class*="date"]').text().trim() ||
        '';

      chapters.push({
        name: name || `Chapter ${num || ''}`.trim(),
        url: link,
        number: num ? Number(num) : null,
        date,
      });
    },
  );

  // Sort chapters by number (ascending)
  chapters.sort((a, b) => {
    if (a.number == null && b.number == null) return 0;
    if (a.number == null) return 1;
    if (b.number == null) return -1;
    return a.number - b.number;
  });

  return {
    source: 'asurascanz',
    url,
    title,
    cover,
    status,
    genres,
    synopsis,
    chapters,
  };
}

/**
 * Fetch chapter pages (images) from a chapter URL.
 * Enhanced with multiple selector strategies and better error handling.
 */
async function fetchChapterPages(chapterUrl) {
  const url = absoluteUrl(chapterUrl);
  const html = await fetchHtml(url, { timeout: 45000 }); // Longer timeout for chapter pages
  const $ = cheerio.load(html);

  const pages = [];
  const seenUrls = new Set();
  let selectorUsed = null;

  // First, try to extract from ts_reader.run() JSON (most reliable for AsuraScanz)
  const tsReaderMatch = html.match(/ts_reader\.run\((\{[\s\S]*?\})\);/);
  if (tsReaderMatch) {
    try {
      const readerData = JSON.parse(tsReaderMatch[1]);
      if (readerData.sources && readerData.sources.length > 0) {
        const images = readerData.sources[0].images || [];
        images.forEach((imgUrl, i) => {
          if (imgUrl && !seenUrls.has(imgUrl)) {
            seenUrls.add(imgUrl);
            pages.push({
              index: i,
              imageUrl: imgUrl,
            });
          }
        });
        if (pages.length > 0) {
          selectorUsed = 'ts_reader_json';
        }
      }
    } catch (e) {
      console.warn('Failed to parse ts_reader JSON:', e.message);
    }
  }

  // Fallback to DOM selectors if JSON extraction failed
  if (pages.length === 0) {
    const selectorStrategies = [
      '#readerarea img',
      '.reading-content .page-break img',
      '.reading-content img',
      '.wp-manga-chapter-img',
      'div[id*="reader"] img',
      'div[class*="reader"] img',
      'div[class*="reading"] img',
    ];

    for (const sel of selectorStrategies) {
      const imgs = $(sel);
      if (imgs.length === 0) continue;

      imgs.each((i, el) => {
        // Try multiple attributes for image source
        let src =
          $(el).attr('data-src') ||
          $(el).attr('data-lazy-src') ||
          $(el).attr('src') ||
          $(el).attr('data-original');

        if (!src) return;
        
        // Skip placeholder SVGs
        if (src.startsWith('data:image/svg')) return;

        // Don't remove query params for asurascans.imagemanga.online URLs
        if (!src.includes('imagemanga.online')) {
          src = src.replace(/\?.*$/, '');
        }
        src = absoluteUrl(src);

        // Skip if already seen
        if (seenUrls.has(src)) return;
        seenUrls.add(src);

        pages.push({
          index: pages.length,
          imageUrl: src,
        });
      });

      if (pages.length > 0) {
        selectorUsed = sel;
        break;
      }
    }
  }

  // If no pages found, log warning but don't throw (might be a valid empty chapter)
  if (pages.length === 0) {
    console.warn(`No images found for chapter: ${url}`);
  }

  return {
    source: 'asurascanz',
    url,
    pages,
    selectorUsed,
  };
}

/**
 * Simple search implementation using ?s= query
 * Updated to match actual AsuraScanz search URL format
 * Supports fetching all pages of results
 */
async function searchManga(query, { page = 1, fetchAllPages = false } = {}) {
  const allResults = [];
  let currentPage = page;
  let hasMorePages = true;
  const maxPages = fetchAllPages ? 10 : 1; // Limit to 10 pages max to avoid infinite loops
  const seenUrls = new Set(); // Prevent duplicates

  while (hasMorePages && currentPage <= maxPages) {
    // Use the actual search URL format (without post_type parameter)
    let searchUrl = `${BASE_URL}/?s=${encodeURIComponent(query)}`;
    if (currentPage > 1) {
      searchUrl += `&page=${currentPage}`;
    }
    
    const html = await fetchHtml(searchUrl);
    const $ = cheerio.load(html);

    const pageResults = [];

    // Try multiple selectors to catch all results
    const selectors = [
      '.listupd .bs .bsx',  // Primary selector
      '.listupd .bsx',      // Fallback without .bs wrapper
      '.bsx',               // Most generic fallback
    ];

    let foundAny = false;

    for (const selector of selectors) {
      const cards = $(selector);
      if (cards.length > 0) {
        foundAny = true;
        
        cards.each((_, el) => {
          const $card = $(el);
          const $a = $card.find('a').first();

          const link = absoluteUrl($a.attr('href'));
          
          // Skip if we've already seen this URL
          if (!link || seenUrls.has(link)) {
            return;
          }
          
          // Title is in .bigor .tt
          const title = $card.find('.bigor .tt').text().trim() || 
                       $a.attr('title')?.trim() || 
                       '';

          // Cover image - try multiple attributes
          const $img = $card.find('.limit img').first();
          let cover =
            $img.attr('data-src') ||
            $img.attr('src') ||
            $img.attr('data-lazy-src') ||
            null;
          cover = cover ? absoluteUrl(cover) : null;

          // Latest chapter is in .adds .epxs
          const latestChapter = $card.find('.adds .epxs').text().trim();

          // Only add if we have both title and link
          if (title && link) {
            seenUrls.add(link);
            pageResults.push({
              source: 'asurascanz',
              title,
              url: link,
              cover,
              latestChapter,
            });
          }
        });
        
        break; // Found results with this selector, no need to try others
      }
    }

    // If no results found on this page, stop
    if (!foundAny || pageResults.length === 0) {
      hasMorePages = false;
      break;
    }

    allResults.push(...pageResults);

    // Check for pagination if fetchAllPages is true
    if (fetchAllPages) {
      // Check if there's a next page link
      const nextPageLink = $('.pagination a.next, .pagination .next, .pagination a[rel="next"]').first();
      const hasNextPage = nextPageLink.length > 0 && 
                         (nextPageLink.attr('href') || nextPageLink.text().toLowerCase().includes('next'));
      
      if (!hasNextPage) {
        // Also check for page numbers in pagination
        const pageNumbers = $('.pagination a, .pagination .page-numbers, .pagination .page').toArray();
        let maxPageNum = currentPage;
        
        pageNumbers.forEach((el) => {
          const text = $(el).text().trim();
          const num = parseInt(text, 10);
          if (!isNaN(num) && num > maxPageNum) {
            maxPageNum = num;
          }
          // Also check href for page numbers
          const href = $(el).attr('href');
          if (href) {
            const match = href.match(/[?&]page=(\d+)/);
            if (match) {
              const pageFromHref = parseInt(match[1], 10);
              if (!isNaN(pageFromHref) && pageFromHref > maxPageNum) {
                maxPageNum = pageFromHref;
              }
            }
          }
        });
        
        hasMorePages = currentPage < maxPageNum;
      } else {
        hasMorePages = true;
      }
      
      // Log pagination info for debugging
      if (currentPage === 1) {
        console.log(`Search "${query}": Found ${pageResults.length} results on page ${currentPage}, hasMorePages: ${hasMorePages}`);
      }
    } else {
      hasMorePages = false;
    }

    currentPage++;
    
    // Add a small delay between pages to be respectful
    if (hasMorePages && currentPage <= maxPages) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }

  console.log(`Search "${query}": Total results found: ${allResults.length} across ${currentPage - 1} page(s)`);
  return allResults;
}

module.exports = {
  BASE_URL,
  fetchHomeManga,
  fetchMangaDetails,
  fetchChapterPages,
  searchManga,
};


