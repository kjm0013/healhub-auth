const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const sqlite3 = require('sqlite3').verbose();
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3001;
const JWT_SECRET = process.env.JWT_SECRET || 'healthhub_secret_2024';

// Middleware
app.use(cors());
app.use(express.json());

// Database setup
const db = new sqlite3.Database('healthhub.db');

// Create tables
db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT UNIQUE,
    apple_user_id TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    apple_transaction_id TEXT UNIQUE,
    product_id TEXT,
    status TEXT DEFAULT 'active',
    expires_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
  )`);
});

// Apple receipt validation
const validateReceipt = async (receiptData) => {
  try {
    const response = await axios.post('https://sandbox.itunes.apple.com/verifyReceipt', {
      'receipt-data': receiptData,
      'password': process.env.APPLE_SHARED_SECRET || 'your_shared_secret' // Replace with actual shared secret
    });
    return response.data;
  } catch (error) {
    throw new Error('Receipt validation failed');
  }
};

// Routes
app.post('/api/auth/apple', async (req, res) => {
  try {
    const { appleUserId, email, receiptData } = req.body;
    
    // Find or create user
    db.get('SELECT * FROM users WHERE apple_user_id = ?', [appleUserId], async (err, user) => {
      if (err) return res.status(500).json({ error: 'Database error' });
      
      if (!user) {
        // Create new user
        db.run('INSERT INTO users (email, apple_user_id) VALUES (?, ?)', 
          [email, appleUserId], function(err) {
            if (err) return res.status(500).json({ error: 'User creation failed' });
            user = { id: this.lastID, email, apple_user_id: appleUserId };
            handleSubscription(user, receiptData, res);
          });
      } else {
        handleSubscription(user, receiptData, res);
      }
    });
  } catch (error) {
    res.status(500).json({ error: 'Authentication failed' });
  }
});

const handleSubscription = async (user, receiptData, res) => {
  try {
    if (receiptData) {
      const validation = await validateReceipt(receiptData);
      
      if (validation.status === 0) {
        const receipt = validation.receipt.in_app[0];
        const expiresAt = new Date(parseInt(receipt.expires_date_ms));
        
        // Store subscription
        db.run(`INSERT OR REPLACE INTO subscriptions 
          (user_id, apple_transaction_id, product_id, expires_at) 
          VALUES (?, ?, ?, ?)`,
          [user.id, receipt.transaction_id, receipt.product_id, expiresAt],
          function(err) {
            if (err) console.error('Subscription storage error:', err);
          });
      }
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ success: true, token, user });
  } catch (error) {
    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });
    res.json({ success: true, token, user });
  }
};

app.get('/api/subscription/status', (req, res) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'No token' });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    
    db.get(`SELECT * FROM subscriptions 
      WHERE user_id = ? AND status = 'active' AND expires_at > datetime('now')`,
      [decoded.userId], (err, subscription) => {
        if (err) return res.status(500).json({ error: 'Database error' });
        
        res.json({
          isActive: !!subscription,
          subscription
        });
      });
  } catch (error) {
    res.status(401).json({ error: 'Invalid token' });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(PORT, () => {
  console.log(`🚀 HealthHub Auth Server running on port ${PORT}`);
});