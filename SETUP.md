# Setup Guide - ChapterOne Backend & MongoDB

This guide will help you set up the backend server and MongoDB database for the ChapterOne Manga Reader application.

## Prerequisites

- **Node.js** (v18 or higher) - [Download](https://nodejs.org/)
- **npm** (comes with Node.js) or **yarn**
- **MongoDB** (v6.0 or higher) - Choose one:
  - MongoDB Community Server (local installation)
  - MongoDB Atlas (cloud - recommended for beginners)

## Option 1: MongoDB Atlas Setup (Cloud - Recommended)

MongoDB Atlas is a cloud-hosted MongoDB service that's easy to set up and doesn't require local installation.

### Step 1: Create MongoDB Atlas Account

1. Go to [MongoDB Atlas](https://www.mongodb.com/cloud/atlas/register)
2. Sign up for a free account
3. Verify your email address

### Step 2: Create a Cluster

1. After logging in, click **"Build a Database"**
2. Choose **"M0 Free"** tier (free forever)
3. Select a cloud provider and region (choose closest to you)
4. Click **"Create"** (cluster creation takes 3-5 minutes)

### Step 3: Create Database User

1. In the **"Database Access"** section, click **"Add New Database User"**
2. Choose **"Password"** authentication
3. Enter a username and password (save these credentials!)
4. Set user privileges to **"Atlas Admin"** or **"Read and write to any database"**
5. Click **"Add User"**

### Step 4: Configure Network Access

1. Go to **"Network Access"** section
2. Click **"Add IP Address"**
3. For development, click **"Allow Access from Anywhere"** (adds `0.0.0.0/0`)
   - ⚠️ **Note**: For production, use specific IP addresses only
4. Click **"Confirm"**

### Step 5: Get Connection String

1. Go to **"Database"** section
2. Click **"Connect"** on your cluster
3. Choose **"Connect your application"**
4. Copy the connection string (looks like: `mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority`)
5. Replace `<username>` and `<password>` with your database user credentials

## Option 2: Local MongoDB Setup

### Windows

1. Download MongoDB Community Server from [MongoDB Download Center](https://www.mongodb.com/try/download/community)
2. Run the installer
3. Choose **"Complete"** installation
4. Install MongoDB as a Windows Service (recommended)
5. Install MongoDB Compass (GUI tool - optional but helpful)
6. MongoDB will start automatically on port `27017`

### macOS

Using Homebrew:
```bash
brew tap mongodb/brew
brew install mongodb-community
brew services start mongodb-community
```

### Linux (Ubuntu/Debian)

```bash
# Import MongoDB public GPG key
wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list

# Update package list
sudo apt-get update

# Install MongoDB
sudo apt-get install -y mongodb-org

# Start MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

### Verify Local MongoDB Installation

```bash
# Check if MongoDB is running
mongosh --version

# Connect to MongoDB
mongosh
```

If connected successfully, you'll see the MongoDB shell prompt.

## Backend Setup

### Step 1: Navigate to Backend Directory

```bash
cd backend
```

### Step 2: Install Dependencies

```bash
npm install
```

This will install all required packages including:
- Express.js
- Mongoose (MongoDB ODM)
- JWT authentication
- Web scraping tools (Puppeteer, Cheerio)
- And other dependencies

### Step 3: Configure Environment Variables

1. Copy the example environment file:
   ```bash
   # Windows
   copy env.example .env
   
   # macOS/Linux
   cp env.example .env
   ```

2. Open `.env` file and configure the following:

   **For MongoDB Atlas:**
   ```env
   MONGODB_URI=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/chapterone?retryWrites=true&w=majority
   ```

   **For Local MongoDB:**
   ```env
   MONGODB_URI=mongodb://localhost:27017/chapterone
   ```

   **Complete .env file example:**
   ```env
   # Server Configuration
   PORT=3000
   NODE_ENV=development

   # MongoDB
   MONGODB_URI=mongodb://localhost:27017/chapterone
   # OR for Atlas:
   # MONGODB_URI=mongodb+srv://username:password@cluster0.xxxxx.mongodb.net/chapterone?retryWrites=true&w=majority

   # JWT
   JWT_SECRET=your-super-secret-jwt-key-change-this-in-production
   JWT_EXPIRES_IN=7d
   JWT_REFRESH_SECRET=your-super-secret-refresh-key-change-this-too
   JWT_REFRESH_EXPIRES_IN=30d

   # Redis (for Bull queue - optional for now)
   REDIS_HOST=localhost
   REDIS_PORT=6379

   # File Storage
   UPLOAD_DIR=./uploads
   MAX_FILE_SIZE=10485760

   # CORS
   ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
   ```

   ⚠️ **Important**: 
   - Change `JWT_SECRET` and `JWT_REFRESH_SECRET` to strong, random strings
   - Never commit `.env` file to version control
   - For production, use environment-specific secrets

### Step 4: Create Uploads Directory

```bash
# Windows
mkdir uploads

# macOS/Linux
mkdir -p uploads
```

This directory will store uploaded images and manga covers.

### Step 5: Start the Backend Server

**Development mode (with auto-reload):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

You should see:
```
Connected to MongoDB
Server running on port 3000
```

### Step 6: Verify Backend is Running

1. Open your browser or use curl:
   ```bash
   curl http://localhost:3000/health
   ```

2. You should receive:
   ```json
   {
     "status": "ok",
     "timestamp": "2024-01-01T00:00:00.000Z"
   }
   ```

## Troubleshooting

### MongoDB Connection Issues

**Problem**: `MongoServerError: Authentication failed`

**Solutions**:
- Verify username and password in connection string
- Check if database user has correct permissions
- For Atlas: Ensure IP address is whitelisted

**Problem**: `MongooseServerSelectionError: connect ECONNREFUSED`

**Solutions**:
- Verify MongoDB is running: `mongosh` (local) or check Atlas dashboard
- Check connection string is correct
- For local: Ensure MongoDB service is started
- For Atlas: Check network access settings

**Problem**: `MongoNetworkError: getaddrinfo ENOTFOUND`

**Solutions**:
- Verify connection string format
- Check internet connection (for Atlas)
- Ensure cluster name is correct

### Backend Server Issues

**Problem**: `Port 3000 already in use`

**Solutions**:
- Change `PORT` in `.env` file to another port (e.g., `3001`)
- Or stop the process using port 3000:
  ```bash
  # Windows
  netstat -ano | findstr :3000
  taskkill /PID <PID> /F
  
  # macOS/Linux
  lsof -ti:3000 | xargs kill -9
  ```

**Problem**: `Cannot find module 'xxx'`

**Solutions**:
- Run `npm install` again
- Delete `node_modules` and `package-lock.json`, then run `npm install`
- Check Node.js version: `node --version` (should be v18+)

**Problem**: `Error: EACCES: permission denied`

**Solutions**:
- On Linux/macOS, you might need `sudo` for some operations
- Check file permissions for `uploads` directory
- Ensure `.env` file is readable

## Database Initialization

The database will be created automatically when you first run the server. However, you can manually create collections if needed:

### Using MongoDB Compass (GUI)

1. Download [MongoDB Compass](https://www.mongodb.com/products/compass)
2. Connect using your connection string
3. Create database named `chapterone`
4. Collections will be created automatically when data is inserted

### Using MongoDB Shell

```bash
# Connect to MongoDB
mongosh

# Or for Atlas:
mongosh "mongodb+srv://cluster0.xxxxx.mongodb.net/chapterone" --username <username>

# Switch to chapterone database
use chapterone

# Collections will be created automatically when you insert data
```

## Creating Admin User

After the server is running, you can create an admin user through the API:

```bash
# Register a user
curl -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "admin123",
    "username": "admin"
  }'
```

Then manually update the user role in MongoDB:

```javascript
// In MongoDB shell or Compass
use chapterone
db.users.updateOne(
  { email: "admin@example.com" },
  { $set: { role: "admin" } }
)
```

## Next Steps

1. ✅ Backend is running on `http://localhost:3000`
2. ✅ MongoDB is connected
3. ✅ API endpoints are available at `http://localhost:3000/api`
4. 🔄 Configure Flutter app to connect to backend
5. 🔄 Test API endpoints using Postman or curl

## Useful Commands

```bash
# Check MongoDB status (local)
# Windows
sc query MongoDB

# macOS/Linux
sudo systemctl status mongod

# View MongoDB logs (local)
# Windows: Check Windows Event Viewer
# macOS/Linux
sudo tail -f /var/log/mongodb/mongod.log

# Stop MongoDB (local)
# macOS/Linux
sudo systemctl stop mongod

# Restart MongoDB (local)
# macOS/Linux
sudo systemctl restart mongod
```

## Additional Resources

- [MongoDB Documentation](https://docs.mongodb.com/)
- [Mongoose Documentation](https://mongoosejs.com/docs/)
- [Express.js Documentation](https://expressjs.com/)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Verify all environment variables are set correctly
3. Check MongoDB connection status
4. Review server logs for error messages
5. Ensure all dependencies are installed correctly

