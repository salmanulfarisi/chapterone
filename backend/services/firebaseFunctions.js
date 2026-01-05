const axios = require('axios');

/**
 * Call Firebase Cloud Function to send notifications
 * This service acts as a bridge between the backend and Firebase Functions
 */
class FirebaseFunctionsService {
  constructor() {
    // Firebase Functions URL - should be set in environment variables
    // Format: https://<region>-<project-id>.cloudfunctions.net
    this.baseUrl = process.env.FIREBASE_FUNCTIONS_URL || '';
    // API key is optional - Firebase HTTP functions don't require it by default
    this.apiKey = process.env.FIREBASE_FUNCTIONS_API_KEY || '';
  }

  /**
   * Check if Firebase Functions are configured
   * Only baseUrl is required, API key is optional
   */
  isConfigured() {
    return !!this.baseUrl;
  }

  /**
   * Call Firebase Function
   */
  async callFunction(functionName, data) {
    if (!this.isConfigured()) {
      console.warn('Firebase Functions not configured. Set FIREBASE_FUNCTIONS_URL in .env');
      console.warn('Example: FIREBASE_FUNCTIONS_URL=https://us-central1-chapterone-ca208.cloudfunctions.net');
      return { success: false, error: 'Firebase Functions not configured' };
    }

    try {
      // Remove trailing slash from baseUrl if present
      const baseUrl = this.baseUrl.replace(/\/$/, '');
      const url = `${baseUrl}/${functionName}`;
      
      console.log(`Calling Firebase Function: ${url}`);
      console.log(`Function name: ${functionName}`);
      console.log(`Base URL: ${baseUrl}`);
      
      const headers = {
        'Content-Type': 'application/json',
      };
      
      // Add API key to headers if provided (optional)
      if (this.apiKey && this.apiKey !== 'your-api-key-here' && this.apiKey.trim() !== '') {
        headers['x-api-key'] = this.apiKey;
      }
      
      const response = await axios.post(url, { data }, {
        headers,
        timeout: 30000, // 30 second timeout
      });

      return {
        success: true,
        data: response.data,
      };
    } catch (error) {
      console.error(`Error calling Firebase Function ${functionName}:`, error.message);
      console.error(`Full URL attempted: ${this.baseUrl.replace(/\/$/, '')}/${functionName}`);
      
      if (error.response) {
        console.error('Response status:', error.response.status);
        console.error('Response headers:', error.response.headers);
        console.error('Response data:', JSON.stringify(error.response.data, null, 2));
      } else if (error.request) {
        console.error('No response received. Request details:', {
          url: error.config?.url,
          method: error.config?.method,
        });
      }
      
      // Provide more helpful error message
      let errorMessage = error.message;
      if (error.response?.status === 404) {
        errorMessage = `Function '${functionName}' not found. Please verify:\n` +
          `1. The function is deployed: firebase deploy --only functions\n` +
          `2. The function name matches exactly: ${functionName}\n` +
          `3. The base URL is correct: ${this.baseUrl}`;
      } else if (error.response?.status === 500) {
        errorMessage = `Function '${functionName}' returned an error. Check Firebase Functions logs.`;
      }
      
      return {
        success: false,
        error: errorMessage,
        details: error.response?.data,
      };
    }
  }

  /**
   * Send notification to a single user
   */
  async sendNotification(userId, token, title, body, data = {}) {
    return await this.callFunction('sendNotification', {
      userId,
      token,
      title,
      body,
      data,
    });
  }

  /**
   * Send bulk notifications to multiple users
   */
  async sendBulkNotifications(tokens, title, body, data = {}) {
    return await this.callFunction('sendBulkNotifications', {
      tokens,
      title,
      body,
      data,
    });
  }

  /**
   * Notify users about new chapter
   */
  async notifyNewChapter(tokens, mangaId, chapterNumber, mangaTitle) {
    return await this.callFunction('notifyNewChapter', {
      tokens,
      mangaId,
      chapterNumber,
      mangaTitle,
    });
  }

  /**
   * Notify users about new manga
   */
  async notifyNewManga(tokens, mangaId, mangaTitle, genres = []) {
    return await this.callFunction('notifyNewManga', {
      tokens,
      mangaId,
      mangaTitle,
      genres,
    });
  }

  /**
   * Test Firebase Functions configuration
   * Returns configuration status for debugging
   */
  getConfig() {
    return {
      baseUrl: this.baseUrl,
      hasApiKey: !!this.apiKey && this.apiKey !== 'your-api-key-here' && this.apiKey.trim() !== '',
      isConfigured: this.isConfigured(),
      expectedUrl: this.baseUrl ? `${this.baseUrl.replace(/\/$/, '')}/sendNotification` : 'Not configured',
    };
  }
}

// Export singleton instance
const firebaseFunctionsService = new FirebaseFunctionsService();
module.exports = firebaseFunctionsService;

