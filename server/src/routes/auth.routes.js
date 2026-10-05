const express = require('express');
const router = express.Router();
const { register, login, getMe, checkUsername, getUsers, updateProfile } = require('../controllers/auth.controller');

router.post('/register', register);
router.post('/login', login);
router.get('/me', getMe);
router.get('/check-username/:username', checkUsername);
router.get('/users', getUsers);
router.put('/profile', updateProfile);
router.post('/profile', updateProfile);

module.exports = router;
