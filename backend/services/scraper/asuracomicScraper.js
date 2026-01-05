const axios = require('axios');
const cheerio = require('cheerio');
const { URL } = require('url');

// Special scraper for https://asuracomic.net (AsuraComic)

const BASE_URL = 'https://asuracomic.net';

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
 * Search manga on AsuraComic
 */
async function searchManga(query, { page = 1, fetchAllPages = false } = {}) {
  const allResults = [];
  let currentPage = page;
  let hasMorePages = true;
  const maxPages = fetchAllPages ? 10 : 1;
  const seenUrls = new Set();

  while (hasMorePages && currentPage <= maxPages) {
    // New AsuraComic search URL format: /series?name=query&page=1
    let searchUrl = `${BASE_URL}/series?name=${encodeURIComponent(query)}`;
    if (currentPage > 1) {
      searchUrl += `&page=${currentPage}`;
    }
    
    const html = await fetchHtml(searchUrl);
    const $ = cheerio.load(html);

    const pageResults = [];

    // New layout: grid of manga cards with <a href="series/...">
    // Each card structure: <a href="series/slug"><div class="w-full..."><div><div class="flex h-[250px]..."><img></div></div><span class="...">Title</span></a>
    $('a[href^="series/"]').each((_, el) => {
      const $a = $(el);
      const href = $a.attr('href');
      const link = absoluteUrl(href);
      
      if (!link || seenUrls.has(link) || !href.match(/^series\/[a-z0-9-]+$/i)) {
        return;
      }

      // Get the title from span inside the card
      const title = $a.find('span.block, span.font-medium').first().text().trim() ||
                   $a.find('span').last().text().trim() ||
                   '';

      // Get cover image
      const $img = $a.find('img').first();
      let cover = $img.attr('src') || $img.attr('data-src') || null;
      cover = cover ? absoluteUrl(cover) : null;

      // Get status if available
      const status = $a.find('span.status, span.bg-blue-700, span.bg-green-700').text().trim() || '';

      if (title && link) {
        seenUrls.add(link);
        pageResults.push({
          source: 'asuracomic',
          title,
          url: link,
          cover,
          status,
          latestChapter: '',
        });
      }
    });

    // Fallback to old selectors if new ones don't work
    if (pageResults.length === 0) {
      const oldSelectors = ['.listupd .bsx', '.bsx', '.manga-item'];
      for (const selector of oldSelectors) {
        $(selector).each((_, el) => {
          const $card = $(el);
          const $a = $card.find('a').first();
          const link = absoluteUrl($a.attr('href'));
          
          if (!link || seenUrls.has(link)) return;
          
          const title = $card.find('.tt').text().trim() || $a.attr('title')?.trim() || '';
          const $img = $card.find('img').first();
          let cover = $img.attr('src') || $img.attr('data-src') || null;
          cover = cover ? absoluteUrl(cover) : null;

          if (title && link) {
            seenUrls.add(link);
            pageResults.push({
              source: 'asuracomic',
              title,
              url: link,
              cover,
              latestChapter: '',
            });
          }
        });
        if (pageResults.length > 0) break;
      }
    }

    if (pageResults.length === 0) {
      hasMorePages = false;
      break;
    }

    allResults.push(...pageResults);

    if (fetchAllPages) {
      const nextPageLink = $('.pagination a.next, .pagination .next, .pagination a[rel="next"]').first();
      const hasNextPage = nextPageLink.length > 0 && 
                         (nextPageLink.attr('href') || nextPageLink.text().toLowerCase().includes('next'));
      
      if (!hasNextPage) {
        const pageNumbers = $('.pagination a, .pagination .page-numbers, .pagination .page').toArray();
        let maxPageNum = currentPage;
        
        pageNumbers.forEach((el) => {
          const text = $(el).text().trim();
          const num = parseInt(text, 10);
          if (!isNaN(num) && num > maxPageNum) {
            maxPageNum = num;
          }
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
    } else {
      hasMorePages = false;
    }

    currentPage++;
    
    if (hasMorePages && currentPage <= maxPages) {
      await new Promise(resolve => setTimeout(resolve, 500));
    }
  }

  console.log(`Search "${query}": Total results found: ${allResults.length} across ${currentPage - 1} page(s)`);
  return allResults;
}

/**
 * Fetch manga details + chapter list from a manga detail URL
 */
async function fetchMangaDetails(mangaUrl) {
  const url = absoluteUrl(mangaUrl);
  const html = await fetchHtml(url);
  const $ = cheerio.load(html);

  // New AsuraComic layout (React/Tailwind based)
  // Title: span.text-xl.font-bold
  let title =
    $('span.text-xl.font-bold').first().text().trim() ||
    $('h1.entry-title').first().text().trim() ||
    $('h1').first().text().trim() ||
    $('.entry-title').first().text().trim() ||
    '';

  if (!title) {
    throw new Error('Could not extract manga title from page');
  }

  // Cover: img with alt="poster" in the left sidebar
  let cover =
    $('img[alt="poster"]').attr('src') ||
    $('.info-left .thumb img').attr('src') ||
    $('.thumb img').first().attr('src') ||
    null;
  cover = cover ? absoluteUrl(cover) : null;

  // Extract genres from buttons in the genres section
  const genres = [];
  // New layout: buttons inside "Genres" section
  $('h3:contains("Genres")').parent().find('button').each((_, el) => {
    const g = $(el).text().trim();
    if (g && !genres.includes(g)) genres.push(g);
  });
  // Fallback to old selectors
  if (genres.length === 0) {
    $('.wd-full .mgen a, .mgen a, [class*="genre"] a').each((_, el) => {
      const g = $(el).text().trim();
      if (g && !genres.includes(g)) genres.push(g);
    });
  }

  // Extract status from the Status info box
  let status = null;
  // New layout: look for Status label in bg-[#343434] divs
  $('div.bg-\\[\\#343434\\]').each((_, el) => {
    const $el = $(el);
    const labelText = $el.find('h3').first().text().trim().toLowerCase();
    if (labelText === 'status') {
      status = $el.find('h3').last().text().trim() || null;
    }
  });
  // Fallback
  if (!status) {
    $('.tsinfo .imptdt, .info-item').each((_, el) => {
      const label = $(el).text().trim().toLowerCase();
      if (/status/i.test(label)) {
        status = $(el).find('i').text().trim() || $(el).text().replace(/status/i, '').trim() || null;
      }
    });
  }

  // Extract synopsis from the Synopsis section
  let synopsis = '';
  // New layout: text after "Synopsis" h3, inside span with text-[#A2A2A2]
  const synopsisSpan = $('h3:contains("Synopsis")').parent().find('span.text-\\[\\#A2A2A2\\]');
  if (synopsisSpan.length > 0) {
    synopsis = synopsisSpan.text().trim();
  }
  // Fallback
  if (!synopsis) {
    synopsis =
      $('.entry-content.entry-content-single').text().trim() ||
      $('.entry-content').text().trim() ||
      $('.description').text().trim() ||
      '';
  }

  // Extract type (Manhwa, Manga, etc.)
  let type = null;
  $('div.bg-\\[\\#343434\\]').each((_, el) => {
    const $el = $(el);
    const labelText = $el.find('h3').first().text().trim().toLowerCase();
    if (labelText === 'type') {
      type = $el.find('h3').last().text().trim() || null;
    }
  });

  // Extract rating
  let rating = null;
  const ratingText = $('span.ml-1.text-xs').first().text().trim();
  if (ratingText && !isNaN(parseFloat(ratingText))) {
    rating = parseFloat(ratingText);
  }

  // Extract author/artist (from grid section)
  let author = null;
  let artist = null;
  $('h3.text-\\[\\#D9D9D9\\]').each((_, el) => {
    const label = $(el).text().trim().toLowerCase();
    const value = $(el).next('h3').text().trim();
    if (label === 'author' && value !== '_') {
      author = value;
    }
    if (label === 'artist' && value !== '_') {
      artist = value;
    }
  });

  // Extract chapters - need to look for chapter list elements
  const chapters = [];
  // Try multiple selectors for chapter list
  const chapterSelectors = [
    '#chapterlist li',
    '.wp-manga-chapter a',
    '[class*="chapter-list"] a',
    'a[href*="/chapter"]',
  ];

  for (const selector of chapterSelectors) {
    $(selector).each((_, el) => {
      const $el = $(el);
      const $a = $el.is('a') ? $el : $el.find('a').first();
      let href = $a.attr('href');
      
      if (!href || !href.includes('chapter')) return;
      
      // Fix relative URLs - ensure /series/ prefix for AsuraComic chapter URLs
      // e.g., "kidnapped-dragons-a227defd/chapter/1" -> "/series/kidnapped-dragons-a227defd/chapter/1"
      if (!href.startsWith('http') && !href.startsWith('/series/')) {
        href = `/series/${href.replace(/^\//, '')}`;
      }
      const link = absoluteUrl(href);

      if (!link) return;

      // Extract chapter number from URL or text
      const chapterMatch = link.match(/chapter[\/]?(\d+(?:\.\d+)?)/i) ||
                          $a.text().match(/chapter\s*(\d+(?:\.\d+)?)/i);
      const num = chapterMatch ? parseFloat(chapterMatch[1]) : null;

      // Get raw text and clean it up
      let rawName = $el.find('span.chapternum').text().trim() || $a.text().trim();
      
      // Remove date patterns from chapter name (e.g., "Chapter 2December 9th 2025")
      // Match common date formats: "December 9th 2025", "Dec 9, 2025", etc.
      const datePattern = /(January|February|March|April|May|June|July|August|September|October|November|December)\s*\d{1,2}(st|nd|rd|th)?\s*,?\s*\d{4}/gi;
      const extractedDate = rawName.match(datePattern);
      const date = extractedDate ? extractedDate[0] : '';
      
      // Clean the name by removing the date and labels like "First Chapter", "New Chapter"
      let name = rawName
        .replace(datePattern, '')
        .replace(/^(First Chapter|New Chapter|Latest Chapter)/i, '')
        .trim();
      
      // If name is empty or just whitespace, use Chapter number
      if (!name || name.toLowerCase() === 'chapter') {
        name = `Chapter ${num || ''}`.trim();
      }

      // Avoid duplicates
      const exists = chapters.some(ch => ch.url === link);
      if (!exists) {
        chapters.push({
          name,
          url: link,
          number: num,
          date,
        });
      }
    });

    if (chapters.length > 0) break;
  }

  // Sort chapters by number (ascending)
  chapters.sort((a, b) => {
    if (a.number == null && b.number == null) return 0;
    if (a.number == null) return 1;
    if (b.number == null) return -1;
    return a.number - b.number;
  });

  return {
    source: 'asuracomic',
    url,
    title,
    cover,
    status,
    type,
    rating,
    author,
    artist,
    genres,
    synopsis,
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
  let selectorUsed = null;
  const seenUrls = new Set();

  // Extract manga cover URL to exclude it from chapter pages
  const coverUrl = $('img[alt="poster"]').attr('src') || '';
  const coverFilename = coverUrl.split('/').pop()?.split('?')[0] || '';

  // Helper to check if URL is likely a cover image (not chapter page)
  const isCoverImage = (src) => {
    if (!src) return false;
    const filename = src.split('/').pop()?.split('?')[0] || '';
    // Skip if it matches cover filename or contains poster/cover keywords
    if (coverFilename && filename === coverFilename) return true;
    if (/poster|cover|thumb/i.test(src)) return true;
    return false;
  };

  // New AsuraComic: Images are embedded in Next.js RSC payload as escaped JSON
  // Try multiple patterns to extract image URLs
  // Pattern 1: Escaped JSON with order and url
  const jsonPatterns = [
    // Pattern: \"order\":N,\"url\":\"https://gg.asuracomic.net/...\"
    /\\"order\\":(\d+),\\"url\\":\\"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"\\]+)\\"/gi,
    // Pattern: \"url\":\"https://...\",\"order\":N
    /\\"url\\":\\"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"\\]+)\\",\\"order\\":(\d+)/gi,
    // Pattern: \"imageUrl\":\"https://...\"
    /\\"imageUrl\\":\\"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"\\]+)\\"/gi,
    // Pattern: unescaped JSON (if HTML is not escaped)
    /"order":(\d+),"url":"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"]+)"/gi,
    /"url":"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"]+)","order":(\d+)/gi,
  ];

  // Try all patterns and collect all images
  for (const pattern of jsonPatterns) {
    let match;
    // Reset regex lastIndex for global patterns
    pattern.lastIndex = 0;
    while ((match = pattern.exec(html)) !== null) {
      let order, imageUrl;
      
      // Handle different pattern formats
      if (match[1] && match[2]) {
        // Pattern with order first, then url
        if (match[1].startsWith('http')) {
          imageUrl = match[1];
          order = parseInt(match[2], 10);
        } else {
          order = parseInt(match[1], 10);
          imageUrl = match[2];
        }
      } else if (match[1]) {
        // Pattern with only url
        imageUrl = match[1];
        order = null; // Will be set based on index later
      } else {
        continue;
      }

      // Clean up URL (remove escape sequences)
      imageUrl = imageUrl.replace(/\\\//g, '/').replace(/\\"/g, '"').replace(/\\u([0-9a-fA-F]{4})/g, (m, code) => String.fromCharCode(parseInt(code, 16)));
      
      if (!imageUrl || !imageUrl.startsWith('http')) continue;
      if (seenUrls.has(imageUrl) || isCoverImage(imageUrl)) continue;
      
      // Accept all images from gg.asuracomic.net (they should be chapter images)
      if (imageUrl.includes('gg.asuracomic.net')) {
        seenUrls.add(imageUrl);
        pages.push({
          index: order !== null ? order - 1 : pages.length,
          imageUrl,
        });
      }
    }
  }

  if (pages.length > 0) {
    selectorUsed = 'json-embedded';
    // Sort by order and re-index
    pages.sort((a, b) => a.index - b.index);
    pages.forEach((p, i) => p.index = i);
  }

  // Try extracting from script tags that might contain JSON data
  if (pages.length === 0) {
    $('script').each((_, el) => {
      const scriptContent = $(el).html() || '';
      if (!scriptContent.includes('gg.asuracomic.net')) return;
      
      // Try to find JSON.parse or similar patterns
      const scriptPatterns = [
        /(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"'\s\)]+)/gi,
        /"url"\s*:\s*"(https:\/\/gg\.asuracomic\.net\/storage\/media\/[^"]+)"/gi,
      ];
      
      for (const pattern of scriptPatterns) {
        // Reset regex lastIndex
        pattern.lastIndex = 0;
        let match;
        while ((match = pattern.exec(scriptContent)) !== null) {
          const imageUrl = match[1];
          if (!imageUrl || seenUrls.has(imageUrl) || isCoverImage(imageUrl)) continue;
          // Accept all images from gg.asuracomic.net
          if (imageUrl.includes('gg.asuracomic.net')) {
            seenUrls.add(imageUrl);
            pages.push({
              index: pages.length,
              imageUrl,
            });
          }
        }
      }
    });
    
    if (pages.length > 0) {
      selectorUsed = 'script-tag-extraction';
      // Sort by URL to maintain order if possible
      pages.sort((a, b) => {
        const aMatch = a.imageUrl.match(/(\d+)(?:-optimized)?\.(webp|jpg|png)/);
        const bMatch = b.imageUrl.match(/(\d+)(?:-optimized)?\.(webp|jpg|png)/);
        if (aMatch && bMatch) {
          return parseInt(aMatch[1], 10) - parseInt(bMatch[1], 10);
        }
        return a.imageUrl.localeCompare(b.imageUrl);
      });
      pages.forEach((p, i) => p.index = i);
    }
  }

  // Fallback to DOM selectors if JSON extraction failed
  if (pages.length === 0) {
    const selectorStrategies = [
      // New AsuraComic layout: images in div.center containers (chapter pages only)
      'div.center img[src*="chapters"]',
      'div.mx-auto img[src*="chapters"]',
      'img[alt^="chapter page"]',
      // Try all images from gg.asuracomic.net
      'img[src*="gg.asuracomic.net"]',
      'img[data-src*="gg.asuracomic.net"]',
      // Older selectors
      '.reading-content .page-break img',
      '#readerarea img',
      '.reading-content img',
      '.wp-manga-chapter-img',
      'div[id*="reader"] img',
      'div[class*="reader"] img',
      'div[class*="reading"] img',
      '.chapter-images img',
      // Last resort: any image
      'img',
    ];

    for (const sel of selectorStrategies) {
      const imgs = $(sel);
      if (imgs.length === 0) continue;

      imgs.each((i, el) => {
        let src =
          $(el).attr('data-src') ||
          $(el).attr('data-lazy-src') ||
          $(el).attr('src') ||
          $(el).attr('data-original');

        if (!src || isCoverImage(src)) return;

        src = src.replace(/\?.*$/, '');
        src = absoluteUrl(src);

        if (!/\.(jpg|jpeg|png|gif|webp|bmp)(\?|$)/i.test(src)) {
          return;
        }

        // For AsuraComic, accept all images from gg.asuracomic.net
        // These are chapter images
        if (src.includes('gg.asuracomic.net')) {
          // Accept it
        } else if (src.includes('asuracomic.net') && !src.includes('gg.asuracomic.net')) {
          // Skip non-gg.asuracomic.net images if we already have pages from gg.asuracomic.net
          if (pages.length > 0 && pages.some(p => p.imageUrl.includes('gg.asuracomic.net'))) {
            return;
          }
        }

        if (!seenUrls.has(src)) {
          seenUrls.add(src);
          pages.push({
            index: pages.length,
            imageUrl: src,
          });
        }
      });

      if (pages.length > 0) {
        selectorUsed = sel;
        break;
      }
    }
  }

  if (pages.length === 0) {
    console.warn(`No images found for chapter: ${url}`);
    console.warn(`HTML length: ${html.length}, Selectors tried: ${selectorUsed || 'none'}`);
    // Log a sample of the HTML to help debug
    const sampleHtml = html.substring(0, 2000);
    console.warn(`HTML sample (first 2000 chars): ${sampleHtml}`);
  } else {
    console.log(`Found ${pages.length} images for chapter: ${url} (method: ${selectorUsed || 'unknown'})`);
  }

  return {
    source: 'asuracomic',
    url,
    pages,
    selectorUsed,
  };
}

module.exports = {
  BASE_URL,
  searchManga,
  fetchMangaDetails,
  fetchChapterPages,
};
