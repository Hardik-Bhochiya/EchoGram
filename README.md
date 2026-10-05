# EchoGram 💬

> **Fast, modern, real-time messaging and chat application for daily communication.**

EchoGram is a feature-rich, cross-platform chat and messaging application built with **Flutter**, **Node.js**, **Express**, **Socket.IO**, **Firebase**, and **MongoDB**. Designed for seamless daily communication, EchoGram enables friends, teams, and communities to connect instantly via one-on-one direct messages and group conversations.

---

## ✨ Features

### 💬 1-on-1 Direct Messaging
- **Instant Messaging**: Real-time communication powered by WebSockets via Socket.IO.
- **Message Status**: Live sent, delivered, and read receipt indicators.
- **Rich Message Actions**: Edit sent messages, delete for everyone, and react with likes and dislikes.
- **Chat Persistence**: Full offline capability and real-time Cloud Firestore synchronization.
- **Unread Counters**: Live badges for unread conversations.

### 👥 Groups & Communities
- **Group Chats**: Create and join topic-based group chats (Tech, Sports, Gaming, Friends, Hobbies, etc.).
- **Group Rules & Management**: Customizable group rules, member lists, and creator moderation tools.
- **Community Channels**: Discover shared public interest communities and connect with like-minded people.

### 🔍 User Discovery & Contacts
- **Unique Usernames**: Connect using `@username` handles.
- **Instant Search**: Search people by handle or display name.
- **Friend Requests**: Send, accept, or decline friend requests with live pending request alerts.
- **Contact Management**: Keep a personal contacts list for quick messaging.

### 👤 Profile & Personalization
- **Custom Profiles**: Display name, username handle, customizable bio/status, and avatar selections.
- **Verified Badges**: Distinct verified badges for trusted users.
- **Dark Theme**: Premium GitHub Dark aesthetic with high contrast and smooth micro-interactions.

### 🔔 Real-Time Notifications
- Live push/in-app notifications for incoming messages, friend requests, and group activities.

---

## 🏗️ Architecture

```text
                           EchoGram Client
                     (Flutter Web / Android / iOS)
                                │
          ┌─────────────────────┴─────────────────────┐
          │                                           │
          ▼                                           ▼
   Firebase Firestore                           Node.js Backend
   (User profiles, messages,                    (REST API & Socket.IO)
    friendships, real-time sync)                      │
                                                      ▼
                                                   MongoDB
                                              (Data Persistence)
```

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>=3.6.0`
- **Node.js**: `>=18.0.0`
- **npm**: `>=9.0.0`
- **MongoDB** (optional; in-memory store automatically activates if local MongoDB is not running)

### 1. Backend Server Setup

```bash
cd server
npm install
npm run dev
```

The server starts at `http://localhost:5000` with:
- **REST API**: `http://localhost:5000/api`
- **Socket.IO**: `http://localhost:5000/chat`
- **Health Check**: `http://localhost:5000/api/health`

### 2. Flutter Client Setup

```bash
# In the project root directory
flutter pub get

# Run on Chrome
flutter run -d chrome --web-port 5050

# Run on Edge (for dual-user testing)
flutter run -d edge --web-port 5051

# Run on Android
flutter run -d android
```

---

## 🧪 Testing

Run the automated test suite:

```bash
# Run unit & widget tests
flutter test

# Run static analysis
flutter analyze
```

---

## 📱 Technology Stack

| Layer | Technologies |
|---|---|
| **Frontend Framework** | Flutter (Dart 3.6+) |
| **State Management** | Provider |
| **Styling & Design** | Custom Design System (GitHub Dark Theme, Glassmorphism) |
| **Backend Server** | Node.js, Express.js |
| **Real-Time Engine** | Socket.IO |
| **Databases** | Cloud Firestore, MongoDB, SharedPreferences (Local Cache) |
| **Authentication** | Firebase Auth + JWT Token Fallback |

---

## 📄 License
This project is open source and available under the [MIT License](LICENSE).
