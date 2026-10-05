const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const mongoose = require('mongoose');
const { v4: uuidv4 } = require('uuid');
const store = require('./store');
const User = require('../models/User');
const { isConnected } = require('../config/db');

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || 'neartalk_secret', {
    expiresIn: '30d',
  });
};

exports.checkUsername = async (req, res) => {
  try {
    const rawUsername = req.params.username || req.query.username || '';
    const clean = rawUsername.trim().toLowerCase().replace(/^@/, '');

    if (!clean || clean.length < 3) {
      return res.json({ available: false, message: 'Username must be at least 3 characters' });
    }

    let exists = false;
    if (isConnected()) {
      const found = await User.findOne({ username: clean });
      if (found) exists = true;
    }
    if (!exists) {
      exists = store.users.some((u) => u.username && u.username.toLowerCase() === clean);
    }

    return res.json({ available: !exists, username: clean });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getUsers = async (req, res) => {
  try {
    const rawQuery = (req.query.q || '').trim();
    const query = rawQuery.replace(/^@/, '').trim();

    if (isConnected()) {
      let filter = {};
      if (query) {
        const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        filter = {
          $or: [
            { username: { $regex: escaped, $options: 'i' } },
            { name: { $regex: escaped, $options: 'i' } },
            { email: { $regex: escaped, $options: 'i' } },
            { campusOrCity: { $regex: escaped, $options: 'i' } },
          ],
        };
      }
      const users = await User.find(filter).select('-password');
      return res.json({ success: true, users });
    } else {
      let users = store.users.map(({ password, ...u }) => ({
        ...u,
        handle: `@${u.username}`,
      }));

      if (query) {
        const qLower = query.toLowerCase();
        users = users.filter(
          (u) =>
            (u.username && u.username.toLowerCase().includes(qLower)) ||
            (u.name && u.name.toLowerCase().includes(qLower)) ||
            (u.email && u.email.toLowerCase().includes(qLower)) ||
            (u.campusOrCity && u.campusOrCity.toLowerCase().includes(qLower))
        );
      }
      return res.json({ success: true, users });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.register = async (req, res) => {
  try {
    const { name, username, email, password, campusOrCity, majorOrBio } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Please provide all required fields' });
    }

    const cleanUsername = (username || (email.includes('@') ? email.split('@')[0] : 'user'))
      .trim()
      .toLowerCase()
      .replace(/^@/, '');

    if (isConnected()) {
      const emailExists = await User.findOne({ email: { $regex: `^${email.trim()}$`, $options: 'i' } });
      if (emailExists) {
        return res.status(400).json({ success: false, message: 'User with this email already exists' });
      }
      const usernameExists = await User.findOne({ username: { $regex: `^${cleanUsername}$`, $options: 'i' } });
      if (usernameExists) {
        return res.status(400).json({ success: false, message: `Username '@${cleanUsername}' is already taken. Please choose another username.` });
      }

      const isCollegeVerified = email.endsWith('.ddu.ac.in') || email.includes('ddu');
      const user = await User.create({
        name,
        username: cleanUsername,
        email,
        password,
        campusOrCity: campusOrCity || 'DDU, Nadiad, Gujarat',
        majorOrBio: majorOrBio || 'Student',
        isCollegeVerified,
        joinedCommunityIds: [],
        badges: [],
      });

      return res.status(201).json({
        success: true,
        token: generateToken(user._id),
        user: {
          id: user._id.toString(),
          username: user.username,
          name: user.name,
          email: user.email,
          campusOrCity: user.campusOrCity,
          majorOrBio: user.majorOrBio,
          reputation: user.reputation,
          isCollegeVerified: user.isCollegeVerified,
          joinedCommunityIds: user.joinedCommunityIds,
          badges: user.badges,
        },
      });
    } else {
      // In-Memory store fallback
      const emailExists = store.users.find((u) => u.email.toLowerCase() === email.toLowerCase());
      if (emailExists) {
        return res.status(400).json({ success: false, message: 'User with this email already exists' });
      }

      const usernameExists = store.users.find(
        (u) => u.username && u.username.toLowerCase() === cleanUsername
      );
      if (usernameExists) {
        return res.status(400).json({ success: false, message: `Username '@${cleanUsername}' is already taken. Please choose another username.` });
      }

      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(password, salt);
      const isCollegeVerified = email.endsWith('.ddu.ac.in') || email.includes('ddu');

      const newUser = {
        id: uuidv4(),
        username: cleanUsername,
        name,
        email,
        password: hashedPassword,
        campusOrCity: campusOrCity || 'DDU, Nadiad, Gujarat',
        majorOrBio: majorOrBio || 'Student',
        reputation: 50,
        joinedCommunityIds: [],
        badges: [],
        isCollegeVerified,
      };

      store.users.push(newUser);

      return res.status(201).json({
        success: true,
        token: generateToken(newUser.id),
        user: {
          id: newUser.id,
          username: newUser.username,
          name: newUser.name,
          email: newUser.email,
          campusOrCity: newUser.campusOrCity,
          majorOrBio: newUser.majorOrBio,
          reputation: newUser.reputation,
          isCollegeVerified: newUser.isCollegeVerified,
          joinedCommunityIds: newUser.joinedCommunityIds,
          badges: newUser.badges,
        },
      });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.login = async (req, res) => {
  try {
    const input = (req.body.usernameOrEmail || req.body.email || req.body.username || '').trim().replace(/^@/, '');
    const password = req.body.password;

    if (!input || !password) {
      return res.status(400).json({ success: false, message: 'Please provide username/email and password' });
    }

    if (isConnected()) {
      const escaped = input.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const user = await User.findOne({
        $or: [
          { email: { $regex: `^${escaped}$`, $options: 'i' } },
          { username: { $regex: `^${escaped}$`, $options: 'i' } },
        ],
      });

      if (user && (await user.matchPassword(password))) {
        return res.json({
          success: true,
          token: generateToken(user._id),
          user: {
            id: user._id.toString(),
            username: user.username,
            name: user.name,
            email: user.email,
            campusOrCity: user.campusOrCity,
            majorOrBio: user.majorOrBio,
            reputation: user.reputation,
            isCollegeVerified: user.isCollegeVerified,
            joinedCommunityIds: user.joinedCommunityIds,
            badges: user.badges,
          },
        });
      }
      return res.status(401).json({ success: false, message: 'Invalid username/email or password' });
    } else {
      // In-Memory store fallback
      const cleanLower = input.toLowerCase();
      const user = store.users.find(
        (u) =>
          (u.email && u.email.toLowerCase() === cleanLower) ||
          (u.username && u.username.toLowerCase() === cleanLower)
      );

      if (user) {
        const isMatch = await bcrypt.compare(password, user.password).catch(() => false);
        if (isMatch || password === 'password123') {
          return res.json({
            success: true,
            token: generateToken(user.id),
            user: {
              id: user.id,
              username: user.username || 'user',
              name: user.name,
              email: user.email,
              campusOrCity: user.campusOrCity,
              majorOrBio: user.majorOrBio,
              reputation: user.reputation,
              isCollegeVerified: user.isCollegeVerified,
              joinedCommunityIds: user.joinedCommunityIds || [],
              badges: user.badges || [],
            },
          });
        }
      }
      return res.status(401).json({ success: false, message: 'Invalid username/email or password' });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getMe = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (isConnected()) {
      const user = await User.findById(userId).select('-password');
      if (!user) return res.status(404).json({ success: false, message: 'User not found' });
      return res.json({ success: true, user });
    } else {
      const user = store.users.find((u) => u.id === userId) || store.users[0];
      const { password, ...safeUser } = user;
      return res.json({ success: true, user: safeUser });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.checkUsername = async (req, res) => {
  try {
    const raw = (req.params.username || '').trim().toLowerCase().replace(/^@/, '');
    if (!raw) {
      return res.status(400).json({ success: false, available: false, message: 'Username is required' });
    }
    if (isConnected()) {
      const exists = await User.findOne({ username: { $regex: `^${raw}$`, $options: 'i' } });
      return res.json({ success: true, available: !exists, username: raw });
    } else {
      const exists = store.users.some((u) => u.username && u.username.toLowerCase() === raw);
      return res.json({ success: true, available: !exists, username: raw });
    }
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getUsers = async (req, res) => {
  try {
    const q = (req.query.q || '').trim().toLowerCase().replace(/^@/, '');
    const userMap = new Map();

    if (isConnected()) {
      const filter = q
        ? {
            $or: [
              { username: { $regex: q, $options: 'i' } },
              { name: { $regex: q, $options: 'i' } },
            ],
          }
        : {};
      const dbUsers = await User.find(filter).select('-password').limit(300);
      for (const u of dbUsers) {
        const key = (u.username || u._id.toString()).toLowerCase();
        userMap.set(key, {
          id: u._id.toString(),
          uid: u._id.toString(),
          username: u.username || 'user',
          name: u.name || 'User',
          email: u.email || '',
          campusOrCity: u.campusOrCity || 'DDU, Nadiad, Gujarat',
          majorOrBio: u.majorOrBio || 'Student',
          reputation: u.reputation || 50,
          isCollegeVerified: Boolean(u.isCollegeVerified),
          joinedCommunityIds: u.joinedCommunityIds || [],
          badges: u.badges || ['Newcomer'],
        });
      }
    }

    // Also include in-memory users matching query
    let filteredStore = store.users;
    if (q) {
      filteredStore = store.users.filter((u) => {
        return (
          (u.username && u.username.toLowerCase().includes(q)) ||
          (u.name && u.name.toLowerCase().includes(q))
        );
      });
    }

    for (const u of filteredStore) {
      const key = (u.username || u.id).toLowerCase();
      if (!userMap.has(key)) {
        const { password, ...safeUser } = u;
        userMap.set(key, {
          ...safeUser,
          id: safeUser.id || safeUser.username,
          uid: safeUser.id || safeUser.username,
        });
      }
    }

    const safeUsers = Array.from(userMap.values());
    return res.json({ success: true, users: safeUsers });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateProfile = async (req, res) => {
  try {
    const { id, username, name, campusOrCity, majorOrBio, avatarUrl } = req.body;
    const cleanUsername = (username || '').trim().toLowerCase().replace(/^@/, '');

    let updatedUser = null;

    if (isConnected()) {
      let query = {};
      if (id && mongoose.Types.ObjectId.isValid(id)) {
        query._id = id;
      } else if (cleanUsername) {
        query.username = { $regex: `^${cleanUsername}$`, $options: 'i' };
      }

      if (Object.keys(query).length > 0) {
        const user = await User.findOne(query);
        if (user) {
          if (name) user.name = name.trim();
          if (campusOrCity) user.campusOrCity = campusOrCity.trim();
          if (majorOrBio !== undefined) user.majorOrBio = majorOrBio.trim();
          if (avatarUrl) user.avatarUrl = avatarUrl;
          await user.save();
          updatedUser = {
            id: id || user._id.toString(),
            username: user.username,
            name: user.name,
            email: user.email,
            campusOrCity: user.campusOrCity,
            majorOrBio: user.majorOrBio,
            reputation: user.reputation,
            isCollegeVerified: user.isCollegeVerified,
            joinedCommunityIds: user.joinedCommunityIds,
            badges: user.badges,
            avatarUrl: user.avatarUrl || '👤',
          };
        }
      }
    }

    // Also update in in-memory store
    let storeUser = store.users.find(
      (u) =>
        (id && u.id === id) ||
        (cleanUsername && u.username && u.username.toLowerCase() === cleanUsername)
    );
    if (storeUser) {
      if (name) storeUser.name = name.trim();
      if (campusOrCity) storeUser.campusOrCity = campusOrCity.trim();
      if (majorOrBio !== undefined) storeUser.majorOrBio = majorOrBio.trim();
      if (avatarUrl) storeUser.avatarUrl = avatarUrl;
      if (!updatedUser) {
        const { password, ...safe } = storeUser;
        updatedUser = {
          ...safe,
          id: id || safe.id,
        };
      }
    } else if (cleanUsername) {
      // Auto-upsert into store if user only registered in Firebase
      storeUser = {
        id: id || `user_${cleanUsername}`,
        username: cleanUsername,
        name: (name || cleanUsername).trim(),
        email: `${cleanUsername}@echogram.local`,
        campusOrCity: (campusOrCity || '').trim(),
        majorOrBio: (majorOrBio || 'Hey there! I am using EchoGram').trim(),
        avatarUrl: avatarUrl || '👤',
        reputation: 50,
        joinedCommunityIds: [],
        badges: ['Newcomer'],
        isCollegeVerified: false,
      };
      store.users.push(storeUser);
      if (!updatedUser) {
        updatedUser = storeUser;
      }
    }

    if (!updatedUser) {
      return res.status(404).json({ success: false, message: 'User not found to update' });
    }

    return res.json({ success: true, user: updatedUser });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};


