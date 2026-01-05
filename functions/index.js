/**
 * Firebase Functions for ChapterOne Notification System
 *
 * This file contains Cloud Functions for:
 * - Smart notification scheduling based on user active hours
 * - Digest notifications (daily/weekly)
 * - Personalized notifications based on preferences
 *
 * Setup:
 * 1. Install Firebase CLI: npm install -g firebase-tools
 * 2. Login: firebase login
 * 3. Initialize: firebase init functions
 * 4. Deploy: firebase deploy --only functions
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// Define environment parameter for API base URL
// Using process.env as fallback for compatibility
const API_BASE_URL = process.env.API_BASE_URL || "http://localhost:3000/api";

/**
 * Scheduled function to send digest notifications
 * Runs daily at specified times
 */
exports.sendDailyDigest = onSchedule(
    {
      schedule: "0 18 * * *", // 6 PM daily
      timeZone: "UTC",
      region: "us-central1",
      memory: "256MiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      try {
        // Get all users with digest enabled
        const response = await axios.get(`${API_BASE_URL}/notifications/digest-users`);
        const users = response.data.users;

        for (const user of users) {
          if (user.digestTime === 18) { // Match the scheduled time
            await sendDigestNotification(user);
          }
        }

        return null;
      } catch (error) {
        console.error("Error sending daily digest:", error);
        return null;
      }
    },
);

/**
 * Scheduled function to check and send notifications during active hours
 * Runs every hour
 */
exports.checkActiveHours = onSchedule(
    {
      schedule: "0 * * * *", // Every hour
      timeZone: "UTC",
      region: "us-central1",
      memory: "256MiB",
      timeoutSeconds: 540,
    },
    async (event) => {
      try {
        const currentHour = new Date().getUTCHours();

        // Get users with active hours matching current hour
        const response = await axios.get(
            `${API_BASE_URL}/notifications/active-hour-users?hour=${currentHour}`,
        );
        const users = response.data.users;

        for (const user of users) {
          await sendPendingNotifications(user);
        }

        return null;
      } catch (error) {
        console.error("Error checking active hours notifications:", error);
        return null;
      }
    },
);

/**
 * HTTP function to schedule digest for a user
 */
exports.scheduleDigest = onRequest(
    {
      region: "us-central1",
      memory: "256MiB",
      timeoutSeconds: 60,
    },
    async (req, res) => {
      try {
        const {userId, scheduledTime, frequency} = req.body;

        // Create a scheduled task for this user's digest
        // This is a simplified version - in production, use Cloud Tasks or similar
        const scheduleTime = new Date(scheduledTime);

        // Store in Firestore for scheduled execution
        await admin.firestore().collection("scheduled_digests").add({
          userId,
          scheduledTime: scheduleTime,
          frequency,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        res.json({success: true, message: "Digest scheduled"});
      } catch (error) {
        console.error("Error scheduling digest:", error);
        res.status(500).json({error: "Failed to schedule digest"});
      }
    });

/**
 * Helper function to send digest notification
 * @param {Object} user - User object with userId, fcmToken, and digest preferences
 */
async function sendDigestNotification(user) {
  try {
    // Get user's pending notifications for digest
    const response = await axios.get(
        `${API_BASE_URL}/notifications/digest-content?userId=${user.userId}`,
    );
    const digestContent = response.data;

    if (digestContent.notifications.length === 0) {
      return; // No content to send
    }

    // Build digest message
    const title = digestContent.frequency === "daily" ?
      "Your Daily Manga Digest" :
      "Your Weekly Manga Digest";

    const body =
        `You have ${digestContent.notifications.length} new updates: ` +
        `${digestContent.summary}`;

    // Send notification via FCM
    const message = {
      notification: {
        title,
        body,
      },
      data: {
        type: "digest",
        frequency: digestContent.frequency,
      },
      token: user.fcmToken,
    };

    await admin.messaging().send(message);

    // Mark notifications as sent in digest
    await axios.post(`${API_BASE_URL}/notifications/mark-digest-sent`, {
      userId: user.userId,
      notificationIds: digestContent.notifications.map((n) => n.id),
    });

    console.log(`Digest sent to user ${user.userId}`);
  } catch (error) {
    console.error(`Error sending digest to user ${user.userId}:`, error);
  }
}

/**
 * Helper function to send pending notifications during active hours
 * @param {Object} user - User object with userId, fcmToken, and mangaSettings
 */
async function sendPendingNotifications(user) {
  try {
    // Get pending notifications for user
    const response = await axios.get(
        `${API_BASE_URL}/notifications/pending?userId=${user.userId}`,
    );
    const pendingNotifications = response.data.notifications;

    for (const notification of pendingNotifications) {
      // Check if notification should be sent immediately or in digest
      const mangaSettings = user.mangaSettings && user.mangaSettings[notification.mangaId];

      if (mangaSettings && !mangaSettings.immediate) {
        continue; // Skip, will be sent in digest
      }

      // Send notification
      const message = {
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: {
          type: notification.type,
          mangaId: notification.mangaId || "",
          chapterId: notification.chapterId || "",
        },
        token: user.fcmToken,
      };

      await admin.messaging().send(message);

      // Mark as sent
      await axios.put(
          `${API_BASE_URL}/notifications/${notification.id}/mark-sent`,
      );
    }
  } catch (error) {
    console.error(`Error sending pending notifications to user ${user.userId}:`, error);
  }
}
