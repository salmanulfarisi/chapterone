# ChapterOne - Manga Reader

A comprehensive manga reader application with advanced scraper and admin panel, built with Flutter and Node.js.

## Features

- 📚 Manga reading with multiple reading modes
- 🔍 Advanced search and filtering
- 📖 Reading history and bookmarks
- 👥 User profiles and social features
- 🔔 Push notifications
- 🤖 Advanced web scraper
- 👨‍💼 Admin panel (web and in-app)
- 🎨 Netflix-inspired dark theme
- ✨ Smooth animations

## Tech Stack

### Frontend
- Flutter (Cross-platform)
- Riverpod (State Management)
- GoRouter (Navigation)
- Dio (HTTP Client)
- Hive (Local Storage)

### Backend
- Node.js + Express
- MongoDB + Mongoose
- JWT Authentication
- Puppeteer/Cheerio (Web Scraping)
- Bull (Job Queue)

## Setup

### Frontend

1. Install Flutter dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```

### Backend

📖 **For detailed backend and MongoDB setup instructions, see [SETUP.md](SETUP.md)**

Quick start:

1. Install dependencies:
```bash
cd backend
npm install
```

2. Configure environment:
```bash
# Copy example env file
cp env.example .env

# Edit .env and set your MongoDB connection string
# For local: MONGODB_URI=mongodb://localhost:27017/chapterone
# For Atlas: MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/chapterone
```

3. Start MongoDB (local) or use MongoDB Atlas (cloud)

4. Run the server:
```bash
npm run dev
```

For complete setup instructions including MongoDB installation, connection configuration, and troubleshooting, please refer to [SETUP.md](SETUP.md).

## Project Structure

```
chapterone/
├── lib/                    # Flutter app source
│   ├── core/              # Core utilities, theme, constants
│   ├── features/          # Feature modules
│   ├── models/            # Data models
│   ├── services/          # API, storage, notifications
│   └── widgets/           # Reusable widgets
├── backend/                # Node.js backend
│   ├── models/            # MongoDB schemas
│   ├── routes/            # API routes
│   ├── middleware/        # Auth, validation
│   └── services/          # Business logic
└── admin/                 # Admin panel (web)
```

## API Endpoints

### Auth
- `POST /api/auth/register` - Register user
- `POST /api/auth/login` - Login
- `GET /api/auth/me` - Get current user
- `POST /api/auth/refresh` - Refresh token

### Manga
- `GET /api/manga` - List manga (with pagination)
- `GET /api/manga/:id` - Get manga details
- `GET /api/manga/:id/chapters` - Get chapters

### Admin
- `POST /api/admin/manga` - Create manga
- `PUT /api/admin/manga/:id` - Update manga
- `GET /api/admin/scraper/sources` - List scraper sources
- `POST /api/admin/scraper/jobs` - Create scraping job

## License

MIT
