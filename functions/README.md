# Firebase Functions Setup for Notifications

This directory contains Firebase Cloud Functions for the ChapterOne notification system.

## Features

- **Smart Scheduling**: Notifications are sent during user's active hours
- **Digest Notifications**: Daily/weekly summaries of updates
- **Personalized Notifications**: Based on user preferences and per-manga settings

## Setup

1. **Install Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Functions**:
   ```bash
   firebase init functions
   ```
   - Select JavaScript
   - Install dependencies

4. **Install Dependencies**:
   ```bash
   cd functions
   npm install
   ```

5. **Configure Environment Variables**:
   
   For Firebase Functions v7, set environment variables using:
   ```bash
   firebase functions:secrets:set API_BASE_URL
   ```
   Or set it as a regular environment variable during deployment.
   
   Alternatively, you can set it in your `.env` file for local development or use the default value (`http://localhost:3000/api`).

6. **Deploy**:
   ```bash
   firebase deploy --only functions
   ```

## Required Backend Endpoints

The functions require these additional endpoints in your backend:

- `GET /api/notifications/digest-users` - Get users with digest enabled
- `GET /api/notifications/active-hour-users?hour=X` - Get users active at hour X
- `GET /api/notifications/digest-content?userId=X` - Get digest content for user
- `GET /api/notifications/pending?userId=X` - Get pending notifications
- `POST /api/notifications/mark-digest-sent` - Mark notifications as sent in digest
- `PUT /api/notifications/:id/mark-sent` - Mark notification as sent

## Scheduling

- **Daily Digest**: Runs at 6 PM UTC (configurable per user)
- **Active Hours Check**: Runs every hour to check for pending notifications

## Notes

- Functions use UTC timezone
- Adjust scheduled times based on your user base timezone
- Consider using Cloud Tasks for more complex scheduling

