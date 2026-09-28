require('dotenv').config();
const express = require('express');
const http = require('http');
const path = require('path');
const fs = require('fs');
const cors = require('cors');
const { Server } = require('socket.io');
const { connectDB } = require('./config/db');
const registerChatSocket = require('./sockets/chat.socket');

const authRoutes = require('./routes/auth.routes');
const communityRoutes = require('./routes/community.routes');
const questionRoutes = require('./routes/question.routes');
const chatRoutes = require('./routes/chat.routes');
const friendRoutes = require('./routes/friend.routes');

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO with permissive CORS for mobile / web
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
  },
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Connect Database (with automatic graceful fallback)
connectDB();

// Register WebSockets
registerChatSocket(io);

// Health Check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    service: 'NearTalk API & Socket.IO Server',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    campus: 'DDU, Nadiad, Gujarat',
  });
});

// Mount Routes
app.use('/api/auth', authRoutes);
app.use('/api/communities', communityRoutes);
app.use('/api/questions', questionRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/friends', friendRoutes);

// Serve Flutter Web app if built
const flutterWebDir = path.join(__dirname, '../../build/web');
if (fs.existsSync(flutterWebDir)) {
  app.use(express.static(flutterWebDir));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/socket.io')) {
      return next();
    }
    res.sendFile(path.join(flutterWebDir, 'index.html'));
  });
}

// 404 Handler
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route ${req.originalUrl} not found` });
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Server Error]', err);
  res.status(500).json({ success: false, message: err.message || 'Internal Server Error' });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`=========================================`);
  console.log(` NearTalk Backend Server Running!`);
  console.log(` REST API: http://localhost:${PORT}/api`);
  console.log(` Socket.IO: http://localhost:${PORT}/chat`);
  console.log(` Campus Context: DDU, Nadiad, Gujarat`);
  console.log(`=========================================`);
});
