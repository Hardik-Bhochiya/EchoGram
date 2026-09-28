const express = require('express');
const router = express.Router();
const { getCommunities, getCommunityById, toggleJoin, createCommunity, deleteCommunity } = require('../controllers/community.controller');

router.get('/', getCommunities);
router.post('/', createCommunity);
router.get('/:id', getCommunityById);
router.post('/:id/join', toggleJoin);
router.delete('/:id', deleteCommunity);

module.exports = router;

