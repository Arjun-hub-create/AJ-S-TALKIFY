# Create directory structure
New-Item -ItemType Directory -Force -Path "client\styles"
New-Item -ItemType Directory -Force -Path "client\js"
New-Item -ItemType Directory -Force -Path "server\models"

Write-Host "✅ Folder structure created successfully!"

# Create server.js
$serverJS = @"
require('dotenv').config();
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const mongoose = require('mongoose');
const path = require('path');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: \"*\",
    methods: [\"GET\", \"POST\"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../client')));

// MongoDB Connection
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb+srv://arjunmarjun74_db_user:aGlhyjbCobrxQu87@clusteraj.uqfj2vb.mongodb.net/ajs_wave?retryWrites=true&w=majority&appName=ClusterAJ';

mongoose.connect(MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('✅ Connected to MongoDB Atlas - ClusterAJ'))
.catch(err => console.error('❌ MongoDB connection error:', err));

// Message Schema
const messageSchema = new mongoose.Schema({
  username: { type: String, required: true },
  room: { type: String, required: true },
  message: { type: String, required: true },
  timestamp: { type: Date, default: Date.now }
});

const Message = mongoose.model('Message', messageSchema);

// User Schema
const userSchema = new mongoose.Schema({
  username: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true,
    minlength: 3,
    maxlength: 20
  },
  email: { 
    type: String, 
    required: true, 
    unique: true,
    trim: true,
    lowercase: true
  },
  password: { 
    type: String, 
    required: true,
    minlength: 6
  },
  avatar: { type: String },
  isOnline: { type: Boolean, default: false },
  lastSeen: { type: Date, default: Date.now }
}, {
  timestamps: true
});

userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 12);
  next();
});

userSchema.pre('save', function(next) {
  if (!this.avatar) {
    this.avatar = this.username.charAt(0).toUpperCase();
  }
  next();
});

const User = mongoose.model('User', userSchema);

// JWT Secret
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-here';

// Store active users and rooms
const users = {};
const roomUsers = {};

// Auth Routes
app.post('/api/auth/signup', async (req, res) => {
  try {
    const { username, email, password } = req.body;

    const existingUser = await User.findOne({ 
      \$or: [{ email }, { username }] 
    });
    
    if (existingUser) {
      return res.status(400).json({ 
        error: 'User with this email or username already exists' 
      });
    }

    const user = new User({ username, email, password });
    await user.save();

    const token = jwt.sign(
      { userId: user._id, username: user.username }, 
      JWT_SECRET, 
      { expiresIn: '7d' }
    );

    res.status(201).json({
      message: 'User created successfully',
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        avatar: user.avatar
      }
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    user.isOnline = true;
    user.lastSeen = new Date();
    await user.save();

    const token = jwt.sign(
      { userId: user._id, username: user.username }, 
      JWT_SECRET, 
      { expiresIn: '7d' }
    );

    res.json({
      message: 'Login successful',
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        avatar: user.avatar
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Socket.io connection handling
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('joinRoom', async ({ username, room }) => {
    try {
      socket.join(room);
      
      users[socket.id] = { 
        id: socket.id, 
        username: username, 
        room
      };
      
      if (!roomUsers[room]) {
        roomUsers[room] = [];
      }
      roomUsers[room].push(users[socket.id]);
      
      socket.emit('message', {
        username: 'AJ\'S WAVE Bot',
        message: \`Welcome to \${room}, \${username}!\`,
        time: new Date().toLocaleTimeString()
      });
      
      socket.broadcast.to(room).emit('message', {
        username: 'AJ\'S WAVE Bot',
        message: \`\${username} has joined the chat\`,
        time: new Date().toLocaleTimeString()
      });
      
      io.to(room).emit('roomUsers', {
        room,
        users: roomUsers[room]
      });
      
      const messages = await Message.find({ room })
        .sort({ timestamp: -1 })
        .limit(50)
        .exec();
      
      messages.reverse().forEach(msg => {
        socket.emit('message', {
          username: msg.username,
          message: msg.message,
          time: new Date(msg.timestamp).toLocaleTimeString()
        });
      });
      
      console.log(\`\${username} joined room: \${room}\`);
    } catch (error) {
      console.error('Error joining room:', error);
    }
  });

  socket.on('chatMessage', async (data) => {
    try {
      const user = users[socket.id];
      if (!user) return;
      
      const message = new Message({
        username: data.username,
        room: data.room,
        message: data.message
      });
      
      await message.save();
      console.log(\`💾 Message saved to MongoDB Atlas - ClusterAJ\`);
      
      io.to(data.room).emit('message', {
        username: data.username,
        message: data.message,
        time: new Date().toLocaleTimeString()
      });
    } catch (error) {
      console.error('Error saving message:', error);
    }
  });

  socket.on('disconnect', () => {
    const user = users[socket.id];
    if (user) {
      const { username, room } = user;
      
      if (roomUsers[room]) {
        roomUsers[room] = roomUsers[room].filter(u => u.id !== socket.id);
        
        io.to(room).emit('message', {
          username: 'AJ\'S WAVE Bot',
          message: \`\${username} has left the chat\`,
          time: new Date().toLocaleTimeString()
        });
        
        io.to(room).emit('roomUsers', {
          room,
          users: roomUsers[room]
        });
      }
      
      delete users[socket.id];
      console.log(\`\${username} disconnected from room: \${room}\`);
    }
  });
});

app.get('/api/messages/:room', async (req, res) => {
  try {
    const { room } = req.params;
    const messages = await Message.find({ room })
      .sort({ timestamp: -1 })
      .limit(100)
      .exec();
    
    res.json(messages);
  } catch (error) {
    console.error('Error fetching messages:', error);
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

app.get('/api/rooms', (req, res) => {
  const rooms = Object.keys(roomUsers);
  res.json(rooms);
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../client/index.html'));
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(\`🌊 AJ'S WAVE server running on port \${PORT}\`);
  console.log(\`📊 MongoDB: Connected to ClusterAJ - ajs_wave database\`);
});
"@

Set-Content -Path "server\server.js" -Value $serverJS
Write-Host "✅ server.js created!"

# Create package.json
$packageJson = @"
{
  "name": "ajs-wave-server",
  "version": "1.0.0",
  "description": "Real-time chat application with modern animations",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "socket.io": "^4.7.2",
    "mongoose": "^7.4.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "keywords": [
    "chat",
    "real-time",
    "websockets",
    "mongodb",
    "express",
    "authentication"
  ],
  "author": "AJ",
  "license": "MIT"
}
"@

Set-Content -Path "server\package.json" -Value $packageJson
Write-Host "✅ package.json created!"

# Create .env file
$envFile = @"
MONGODB_URI=mongodb+srv://arjunmarjun74_db_user:aGlhyjbCobrxQu87@clusteraj.uqfj2vb.mongodb.net/ajs_wave?retryWrites=true&w=majority&appName=ClusterAJ
JWT_SECRET=your-super-secret-jwt-key-here-make-it-very-long-and-secure
PORT=3000
"@

Set-Content -Path "server\.env" -Value $envFile
Write-Host "✅ .env file created!"

Write-Host "🎉 Setup complete! Now run these commands:"
Write-Host "1. cd server"
Write-Host "2. npm install"
Write-Host "3. node server.js"