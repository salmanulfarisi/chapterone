const admin = require('firebase-admin');
const axios = require('axios');
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');

class FirebaseStorageService {
  constructor() {
    this._bucket = null;
    this._initialized = false;
  }

  /**
   * Initialize Firebase Storage (lazy initialization)
   */
  _initialize() {
    if (this._initialized) {
      return this._bucket !== null;
    }

    this._initialized = true;

    try {
      // Check if Firebase Admin is initialized
      const apps = admin.apps;
      if (apps.length === 0) {
        // Check for required environment variables
        const hasServiceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
        const hasCredentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
        const hasStorageBucket = process.env.FIREBASE_STORAGE_BUCKET;

        if (!hasStorageBucket) {
          console.error('❌ FIREBASE_STORAGE_BUCKET environment variable is required but not set.');
          console.error('   Please set FIREBASE_STORAGE_BUCKET in your .env file (e.g., chapterone-ca208.appspot.com)');
          this._bucket = null;
          return false;
        }

        // Try to initialize Firebase Admin if not already initialized
        if (hasServiceAccountKey) {
          try {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_KEY);
            admin.initializeApp({
              credential: admin.credential.cert(serviceAccount),
              storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
            });
            console.log('✅ Firebase Admin initialized using FIREBASE_SERVICE_ACCOUNT_KEY');
          } catch (parseError) {
            console.error('❌ Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY:', parseError.message);
            console.error('   Make sure FIREBASE_SERVICE_ACCOUNT_KEY is valid JSON');
            this._bucket = null;
            return false;
          }
        } else if (hasCredentialsPath) {
          try {
            admin.initializeApp({
              credential: admin.credential.applicationDefault(),
              storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
            });
            console.log('✅ Firebase Admin initialized using GOOGLE_APPLICATION_CREDENTIALS');
          } catch (credError) {
            console.error('❌ Failed to initialize Firebase Admin with GOOGLE_APPLICATION_CREDENTIALS:', credError.message);
            console.error(`   Check if the file exists at: ${process.env.GOOGLE_APPLICATION_CREDENTIALS}`);
            this._bucket = null;
            return false;
          }
        } else {
          console.error('❌ Firebase Admin not initialized. Firebase Storage will not be available.');
          console.error('   Required: Set either FIREBASE_SERVICE_ACCOUNT_KEY or GOOGLE_APPLICATION_CREDENTIALS in .env');
          console.error('   Option 1: FIREBASE_SERVICE_ACCOUNT_KEY=<JSON string of service account>');
          console.error('   Option 2: GOOGLE_APPLICATION_CREDENTIALS=<path to service account JSON file>');
          console.error('   Also required: FIREBASE_STORAGE_BUCKET=<your-storage-bucket-name>');
          this._bucket = null;
          return false;
        }
      }

      this._bucket = admin.storage().bucket();
      console.log(`✅ Firebase Storage initialized with bucket: ${this._bucket.name}`);
      return true;
    } catch (error) {
      console.error('❌ Firebase Storage initialization error:', error.message);
      console.error('   Stack:', error.stack);
      this._bucket = null;
      return false;
    }
  }

  /**
   * Get the storage bucket (lazy initialization)
   */
  get bucket() {
    if (!this._initialized) {
      this._initialize();
    }
    return this._bucket;
  }

  /**
   * Check if Firebase Storage is configured
   */
  isConfigured() {
    if (!this._initialized) {
      this._initialize();
    }
    return this._bucket !== null;
  }

  /**
   * Download and optimize an image, then upload to Firebase Storage
   * @param {string} imageUrl - Original image URL
   * @param {string} mangaFolder - Manga folder name (ID or title slug)
   * @param {number} chapterNumber - Chapter number
   * @param {number} pageIndex - Page index (0-based)
   * @returns {Promise<Object>} Object with firebaseUrl, storagePath, and size
   */
  async downloadAndOptimizeImage(imageUrl, mangaFolder, chapterNumber, pageIndex) {
    if (!this.isConfigured()) {
      throw new Error('Firebase Storage is not configured');
    }

    try {
      console.log(`Downloading image ${pageIndex + 1} from: ${imageUrl}`);

      // Download image with retry logic
      let response;
      let retries = 3;
      let lastError;
      
      while (retries > 0) {
        try {
          response = await axios.get(imageUrl, {
            responseType: 'arraybuffer',
            timeout: 30000,
            maxRedirects: 5,
            validateStatus: (status) => status >= 200 && status < 400,
            headers: {
              'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.9',
              'Referer': 'https://hotcomics.io/',
              'Origin': 'https://hotcomics.io',
            },
          });
          break; // Success, exit retry loop
        } catch (error) {
          lastError = error;
          retries--;
          if (retries > 0) {
            console.warn(`Retry ${3 - retries}/3 for image download...`);
            await new Promise(resolve => setTimeout(resolve, 1000 * (3 - retries))); // Exponential backoff
          }
        }
      }
      
      if (!response) {
        const errorMsg = lastError?.response 
          ? `HTTP ${lastError.response.status}: ${lastError.response.statusText} for URL: ${imageUrl}`
          : lastError?.message || 'Unknown error';
        throw new Error(`Failed to download image after 3 retries: ${errorMsg}`);
      }

      const originalSize = response.data.length;
      console.log(`Original image size: ${(originalSize / 1024).toFixed(2)} KB`);

      // Optimize with sharp
      let optimized;
      try {
        // Try to determine image format
        const image = sharp(response.data);
        const metadata = await image.metadata();

        // Resize if too large (max width 1920px, maintain aspect ratio)
        let processed = image.resize(1920, null, {
          withoutEnlargement: true,
          fit: 'inside',
        });

        // Convert to JPEG with quality optimization
        if (metadata.format === 'png' || metadata.format === 'webp') {
          optimized = await processed
            .jpeg({ quality: 85, progressive: true })
            .toBuffer();
        } else {
          // Keep original format but optimize
          optimized = await processed
            .jpeg({ quality: 85, progressive: true })
            .toBuffer();
        }

        const optimizedSize = optimized.length;
        const savings = ((1 - optimizedSize / originalSize) * 100).toFixed(1);
        console.log(
          `Optimized image size: ${(optimizedSize / 1024).toFixed(2)} KB (${savings}% reduction)`,
        );
      } catch (sharpError) {
        console.warn('Sharp optimization failed, using original:', sharpError.message);
        optimized = Buffer.from(response.data);
      }

      // Upload to Firebase Storage - use mangaFolder (can be ID or title slug)
      const fileName = `manga/${mangaFolder}/ch${chapterNumber}/page_${String(pageIndex + 1).padStart(3, '0')}.jpg`;
      const file = this.bucket.file(fileName);

      await file.save(optimized, {
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000', // 1 year cache
        },
        public: true, // Make publicly accessible
      });

      // Get public URL
      const publicUrl = `https://storage.googleapis.com/${this.bucket.name}/${fileName}`;

      console.log(`✅ Uploaded to Firebase Storage: ${fileName}`);

      return {
        firebaseUrl: publicUrl,
        storagePath: fileName,
        size: optimized.length,
        originalSize: originalSize,
      };
    } catch (error) {
      console.error(`Error downloading/optimizing image ${pageIndex + 1}:`, error.message);
      throw error;
    }
  }

  /**
   * Upload all chapter images to Firebase Storage
   * @param {string} mangaFolder - Manga folder name (ID or title slug)
   * @param {number} chapterNumber - Chapter number
   * @param {Array<string>} imageUrls - Array of image URLs
   * @returns {Promise<Array<string>>} Array of Firebase Storage URLs
   */
  async uploadChapterImages(mangaFolder, chapterNumber, imageUrls) {
    if (!this.isConfigured() || !this.bucket) {
      throw new Error('Firebase Storage is not configured');
    }

    const uploadedImages = [];
    const totalPages = imageUrls.length;

    console.log(
      `Starting upload of ${totalPages} images for manga folder "${mangaFolder}", chapter ${chapterNumber}`,
    );

    for (let i = 0; i < imageUrls.length; i++) {
      try {
        const result = await this.downloadAndOptimizeImage(
          imageUrls[i],
          mangaFolder,
          chapterNumber,
          i,
        );
        uploadedImages.push(result.firebaseUrl);

        console.log(`Progress: ${i + 1}/${totalPages} pages uploaded`);

        // Rate limiting - delay between uploads
        if (i < imageUrls.length - 1) {
          await new Promise((resolve) => setTimeout(resolve, 500));
        }
      } catch (error) {
        console.error(`Failed to upload page ${i + 1}:`, error.message);
        // For hotcomics, we must use Firebase Storage, so throw error instead of fallback
        throw new Error(`Failed to upload page ${i + 1} to Firebase Storage: ${error.message}`);
      }
    }

    console.log(
      `✅ Completed upload: ${uploadedImages.length}/${totalPages} pages uploaded successfully`,
    );

    return uploadedImages;
  }

  /**
   * Delete chapter images from Firebase Storage
   * @param {string} mangaId - Manga ID
   * @param {number} chapterNumber - Chapter number
   */
  async deleteChapterImages(mangaId, chapterNumber) {
    if (!this.isConfigured() || !this.bucket) {
      throw new Error('Firebase Storage is not configured');
    }

    try {
      const prefix = `manga/${mangaId}/ch${chapterNumber}/`;
      const [files] = await this.bucket.getFiles({ prefix });

      await Promise.all(files.map((file) => file.delete()));
      console.log(`Deleted ${files.length} files from ${prefix}`);
    } catch (error) {
      console.error('Error deleting chapter images:', error);
      throw error;
    }
  }
}

module.exports = new FirebaseStorageService();

