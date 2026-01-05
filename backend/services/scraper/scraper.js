const axios = require('axios');
const cheerio = require('cheerio');
const puppeteer = require('puppeteer');

class ScraperEngine {
  constructor(sourceConfig) {
    this.config = sourceConfig;
    this.browser = null;
  }

  async init() {
    if (this.config.config.requiresJS) {
      this.browser = await puppeteer.launch({
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      });
    }
  }

  async close() {
    if (this.browser) {
      await this.browser.close();
    }
  }

  async fetchPage(url) {
    try {
      if (this.config.config.requiresJS) {
        const page = await this.browser.newPage();
        await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36');
        await page.goto(url, { waitUntil: 'networkidle2' });
        const content = await page.content();
        await page.close();
        return content;
      } else {
        const response = await axios.get(url, {
          headers: this.config.config.headers || {},
        });
        return response.data;
      }
    } catch (error) {
      throw new Error(`Failed to fetch page: ${error.message}`);
    }
  }

  async scrapeMangaList(url) {
    const html = await this.fetchPage(url);
    const $ = cheerio.load(html);
    const mangaList = [];

    $(this.config.selectors.mangaItem).each((index, element) => {
      const $item = $(element);
      const title = $item.find(this.config.selectors.mangaTitle).text().trim();
      const cover = $item.find(this.config.selectors.mangaCover).attr('src') || 
                    $item.find(this.config.selectors.mangaCover).attr('data-src');
      const link = $item.find('a').attr('href');

      if (title) {
        mangaList.push({
          title,
          cover: cover ? new URL(cover, this.config.baseUrl).href : null,
          link: link ? new URL(link, this.config.baseUrl).href : null,
        });
      }
    });

    return mangaList;
  }

  async scrapeMangaDetails(url) {
    const html = await this.fetchPage(url);
    const $ = cheerio.load(html);

    const title = $(this.config.selectors.mangaTitle).first().text().trim();
    const description = $(this.config.selectors.mangaDescription).text().trim();
    const cover = $(this.config.selectors.mangaCover).attr('src') || 
                   $(this.config.selectors.mangaCover).attr('data-src');
    const genres = [];
    $(this.config.selectors.mangaGenres).each((index, element) => {
      genres.push($(element).text().trim());
    });

    return {
      title,
      description,
      cover: cover ? new URL(cover, this.config.baseUrl).href : null,
      genres,
    };
  }

  async scrapeChapters(url) {
    const html = await this.fetchPage(url);
    const $ = cheerio.load(html);
    const chapters = [];

    $(this.config.selectors.chapterItem).each((index, element) => {
      const $item = $(element);
      const number = parseInt($item.find(this.config.selectors.chapterNumber).text().trim()) || index + 1;
      const title = $item.find(this.config.selectors.chapterTitle).text().trim();
      const link = $item.find('a').attr('href');

      chapters.push({
        number,
        title,
        link: link ? new URL(link, this.config.baseUrl).href : null,
      });
    });

    return chapters;
  }

  async scrapePages(url) {
    const html = await this.fetchPage(url);
    const $ = cheerio.load(html);
    const pages = [];

    $(this.config.selectors.pageImage).each((index, element) => {
      const $img = $(element);
      const src = $img.attr('src') || $img.attr('data-src') || $img.attr('data-url');
      
      if (src) {
        pages.push(new URL(src, this.config.baseUrl).href);
      }
    });

    return pages;
  }
}

module.exports = ScraperEngine;

