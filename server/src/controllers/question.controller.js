const { v4: uuidv4 } = require('uuid');
const store = require('./store');
const { Question } = require('../models/Question');
const { isConnected } = require('../config/db');

exports.getQuestions = async (req, res) => {
  try {
    const { communityId, search, tag, sort } = req.query;

    let list = [...store.questions];

    if (communityId) {
      list = list.filter((q) => q.communityId === communityId);
    }
    if (tag && tag !== 'All') {
      list = list.filter((q) => q.tags.includes(tag));
    }
    if (search) {
      const s = search.toLowerCase();
      list = list.filter(
        (q) =>
          q.title.toLowerCase().includes(s) ||
          q.content.toLowerCase().includes(s) ||
          q.tags.some((t) => t.toLowerCase().includes(s))
      );
    }

    if (sort === 'Most Helpful') {
      list.sort((a, b) => b.upvotes - a.upvotes);
    } else if (sort === 'Unanswered') {
      list = list.filter((q) => !q.replies || q.replies.length === 0);
    } else {
      list.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    }

    return res.json({ success: true, count: list.length, data: list });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.getQuestionById = async (req, res) => {
  try {
    const { id } = req.params;
    const question = store.questions.find((q) => q.id === id);
    if (!question) return res.status(404).json({ success: false, message: 'Question not found' });
    question.views = (question.views || 0) + 1;
    return res.json({ success: true, data: question });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.createQuestion = async (req, res) => {
  try {
    const {
      title,
      content,
      communityId,
      communityName,
      regionId,
      regionName,
      isAnonymous,
      tags,
      authorName,
      authorId,
    } = req.body;

    if (!title || !communityId) {
      return res.status(400).json({ success: false, message: 'Title and Community are required' });
    }

    const newQuestion = {
      id: uuidv4(),
      title,
      content: content || '',
      communityId,
      communityName: communityName || 'DDU Students',
      regionId: regionId || 'region-ddu',
      regionName: regionName || 'DDU, Nadiad, Gujarat',
      authorId: authorId || 'user',
      authorName: isAnonymous ? 'Anonymous' : (authorName || 'Member'),
      isAnonymous: Boolean(isAnonymous),
      anonymousPseudonym: isAnonymous ? 'Anonymous' : null,
      tags: tags || ['DDU', 'General'],
      upvotes: 1,
      views: 1,
      createdAt: new Date().toISOString(),
      replies: [],
      isUpvotedByMe: true,
      isBookmarked: false,
      isResolved: false,
    };

    store.questions.unshift(newQuestion);

    // Update community question count
    const comm = store.communities.find((c) => c.id === communityId);
    if (comm) comm.questionCount = (comm.questionCount || 0) + 1;

    return res.status(201).json({ success: true, data: newQuestion });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.toggleUpvote = async (req, res) => {
  try {
    const { id } = req.params;
    const question = store.questions.find((q) => q.id === id);
    if (!question) return res.status(404).json({ success: false, message: 'Question not found' });

    question.isUpvotedByMe = !question.isUpvotedByMe;
    question.upvotes = question.isUpvotedByMe ? question.upvotes + 1 : Math.max(0, question.upvotes - 1);

    return res.json({ success: true, data: question });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.toggleBookmark = async (req, res) => {
  try {
    const { id } = req.params;
    const question = store.questions.find((q) => q.id === id);
    if (!question) return res.status(404).json({ success: false, message: 'Question not found' });

    question.isBookmarked = !question.isBookmarked;
    return res.json({ success: true, data: question });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

exports.addReply = async (req, res) => {
  try {
    const { id } = req.params;
    const { content, isAnonymous, authorName, authorId } = req.body;

    if (!content) {
      return res.status(400).json({ success: false, message: 'Reply content is required' });
    }

    const question = store.questions.find((q) => q.id === id);
    if (!question) return res.status(404).json({ success: false, message: 'Question not found' });

    const newReply = {
      id: uuidv4(),
      questionId: id,
      content,
      authorId: authorId || 'user',
      authorName: isAnonymous ? 'Anonymous' : (authorName || 'Member'),
      isAnonymous: Boolean(isAnonymous),
      anonymousPseudonym: isAnonymous ? 'Anonymous' : null,
      upvotes: 0,
      createdAt: new Date().toISOString(),
      isAccepted: false,
    };

    if (!question.replies) question.replies = [];
    question.replies.push(newReply);

    return res.status(201).json({ success: true, data: newReply });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
