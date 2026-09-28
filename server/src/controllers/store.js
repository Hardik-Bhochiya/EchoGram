const { v4: uuidv4 } = require('uuid');

class InMemoryStore {
  constructor() {
    this.users = [];

    // Zero Readymade Groups - Users create their own communities with location spots
    this.communities = [];

    // Zero Dummy Questions
    this.questions = [];

    this.rooms = [];

    this.messages = {};

    this.friendRequests = [];

    this.friends = {}; // username -> Set of friend usernames
  }
}

const store = new InMemoryStore();
module.exports = store;
