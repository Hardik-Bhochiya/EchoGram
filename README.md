# EchoGram

> **Ask your community. Know your place.**

EchoGram is a location-based social communication platform built with Flutter and Dart. It is designed to help people connect with others who live, study, or have experience in a particular region.

The platform focuses on helping newcomers, especially college students and people moving to a new city, get useful local information by asking questions and communicating with members of their region-specific communities.

## 📌 Problem Statement

When students join a new college or people move to a new city, they often do not know about the local culture, rules, food, sports facilities, important places, communities, or everyday practices.

Finding reliable information can require asking multiple people or searching through unrelated platforms.

EchoGram aims to provide a dedicated platform where users can:

- Join communities based on their college, city, locality, or region.
- Ask questions related to that specific community.
- Get answers from people who live or have experience there.
- Post questions anonymously or reveal their identity.
- Communicate with community members in real time.

## 🎯 Objectives

- Build a region-based social communication platform.
- Help newcomers understand their new college, city, or locality.
- Provide community-specific discussions and information.
- Support anonymous and public questions.
- Enable real-time communication between users.
- Create a growing knowledge base for different communities.

## ✨ Planned Features

### 🔐 Authentication
- User registration and login
- Secure authentication
- User profile management
- Future support for social/college authentication

### 📍 Region-Based Communities
- Discover communities based on location
- College and campus communities
- City and locality communities
- Join and leave communities

### ❓ Community Questions
- Ask questions within a specific community
- Public or anonymous posting
- Reply to questions
- Like/helpful responses
- Community discussions

### 💬 Real-Time Communication
- One-to-one messaging
- Community/group chat
- Real-time messages using Socket.IO
- Online/offline status
- Typing indicators

### 🔔 Notifications
- New replies
- New messages
- Community activity
- Other important updates

### 👤 User Profiles
- User profile
- Profile picture
- Joined communities
- Community contribution/reputation

### 📸 Media Sharing
- Image sharing
- Media attachments in conversations

## 🏗️ Application Architecture

```text
                    NearTalk
                       │
          ┌────────────┴────────────┐
          │                         │
     Flutter App               Backend Server
          │                         │
     Flutter + Dart          Node.js + Express
          │                         │
          │                  ┌──────┴──────┐
          │                  │             │
          │               REST API      Socket.IO
          │                  │             │
          └──────────────────┴─────────────┘
                             │
                         MongoDB
REST API

REST APIs will be used for operations such as:

Authentication
User profiles
Community management
Joining communities
Creating questions
Fetching questions
Managing user data
Socket.IO

Socket.IO will be used for real-time functionality such as:

Real-time messaging
Group chat
Typing indicators
Online status
Real-time replies
Chat notifications
🛠️ Technology Stack
Frontend
Flutter
Dart
Material Design / Material 3
Android Studio
Backend
Node.js
Express.js
Socket.IO
Database
MongoDB
APIs & Communication
REST API
WebSocket / Socket.IO
Development Tools
Android Studio
Git
GitHub
Postman
MongoDB Compass
📱 Initial Flutter Screens

The initial application will include:

Splash Screen
     ↓
Authentication
     ├── Login
     └── Sign Up
     ↓
Home
     ├── Current Region
     ├── My Communities
     ├── Nearby Communities
     └── Ask a Question
     ↓
Community
     ├── Questions
     ├── Discussions
     └── Community Chat
     ↓
Chat
     ├── One-to-One Chat
     └── Group Chat
     ↓
Profile
📂 Planned Project Structure
neartalk/
│
├── android/
├── ios/
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── models/
│   │
│   ├── screens/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── community/
│   │   ├── chat/
│   │   └── profile/
│   │
│   ├── widgets/
│   │
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── socket_service.dart
│   │   └── auth_service.dart
│   │
│   ├── providers/
│   │
│   ├── utils/
│   │
│   └── theme/
│
├── assets/
│   ├── images/
│   └── icons/
│
├── test/
│
├── pubspec.yaml
└── README.md
## 🚀 Development Roadmap

### Phase 1 — Flutter UI
- [x] Project setup & Material 3 architecture
- [x] Theme and reusable components (Cards, Badges, Chips, Vote Buttons)
- [x] Authentication UI (Login, Sign-Up, Guest exploration)
- [x] Home screen & Region Switcher
- [x] Community discovery & Detail screen
- [x] Question & Discussion screen (with Anonymous posting support)
- [x] Real-time Chat UI & simulated interactions
- [x] Profile UI with reputation badges & Dark/Light theme switch
Phase 2 — Backend
 Node.js setup
 Express.js API
 MongoDB integration
 User authentication API
 Community APIs
 Question and reply APIs
 Profile APIs
Phase 3 — Real-Time Communication
 Socket.IO integration
 One-to-one messaging
 Group chat
 Online/offline status
 Typing indicator
 Real-time notifications
Phase 4 — Location & Community
 Location detection
 Region-based community discovery
 College communities
 City/locality communities
 Community joining system
Phase 5 — Advanced Features
 Anonymous questions
 Community reputation
 Media sharing
 Community moderation
 Events
 Map integration
 Voice messages
 Video calling
🔒 Privacy & Safety

NearTalk will aim to provide a safe community environment through:

Authenticated user accounts
Anonymous question posting
Community moderation
Report functionality
Blocking users
Appropriate access controls

Anonymous posting will hide the user's identity from other community members while maintaining an authenticated account internally for platform security and moderation.

🌱 Future Vision

NearTalk aims to become a community-driven platform where every college, city, locality, and region can develop its own knowledge base.

A newcomer should be able to join a community and quickly discover:

📚 Academic information
🍴 Food and canteens
🏠 Accommodation and hostels
⚽ Sports facilities
🎉 Events and culture
📍 Important local places
💡 Tips from experienced members
📊 Project Status

🚧 Under Development

The project is currently in the initial Flutter UI and architecture phase.

👨‍💻 Development

Built with ❤️ using Flutter, Dart, Node.js, Express.js, Socket.IO, and MongoDB.

NearTalk — Ask your community. Know your place.


### One change I'd strongly recommend

For your actual implementation, don't add every dependency immediately. Start with the Flutter side and add packages as you need them.

Your likely Flutter dependencies later will include:

- `http` → REST API communication
- `socket_io_client` → real-time Socket.IO communication
- `provider` or `riverpod` → state management
- `shared_preferences` → local session/preferences
- `geolocator` → device location
- `permission_handler` → location permissions
- `image_picker` → profile/media images
- `cached_network_image` → efficient network images

For the backend:

- `express`
- `mongoose`
- `socket.io`
- `jsonwebtoken`
- `bcryptjs`
- `cors`
- `dotenv`
- `multer` (when you implement media uploads)

**Don't install all of these now.** For the Lab 5 UI, you can start with essentially Flutter/Dart + the standard Material widgets. Then we'll add packages as each feature is implemented.

Also, the README's **Phase 1 checkboxes should be updated as you actually build each feature**—that m
