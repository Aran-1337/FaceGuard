# FaceGuard 🛡️

A cross-platform mobile application built with **Flutter & Dart** that provides secure user authentication through real-time face recognition, powered by a containerized **Python ML backend**.

---

## 📱 Overview

FaceGuard allows users to register and authenticate using their face instead of traditional passwords. The app captures a live image via the device camera, sends it to a Python backend for recognition, and grants or denies access based on the result. An admin panel allows managing registered users and monitoring activity.

> 🚧 **Status: In Progress** — Core features are functional; admin panel and accuracy improvements are actively being developed.

---

## ✨ Features

- 📷 Real-time face detection using **Google ML Kit**
- 🔐 Face-based user authentication
- ☁️ Firebase Authentication & Firestore for user data management
- 🗄️ Firebase Storage for storing face images
- 🐍 Python ML backend for face recognition processing
- 🐳 Dockerized backend for easy and consistent deployment
- 🗺️ Location-aware features using Geolocator & Flutter Map
- 📊 Analytics dashboard with FL Chart
- 🌍 Multi-language support (Localization)
- 🖼️ Admin panel for user management (HTML/CSS)

---

## 🧰 Tech Stack

### Mobile (Flutter)
| Package | Purpose |
|---|---|
| `flutter` + `dart` | Core framework |
| `firebase_core` + `firebase_auth` | Authentication |
| `cloud_firestore` | Database |
| `firebase_storage` | Image storage |
| `google_mlkit_face_detection` | On-device face detection |
| `camera` | Live camera feed |
| `image_picker` | Image selection |
| `http` | REST API calls to Python backend |
| `provider` | State management |
| `flutter_map` + `geolocator` | Maps & location |
| `fl_chart` | Charts & analytics |
| `google_fonts` | Typography |
| `shared_preferences` | Local storage |
| `permission_handler` | Runtime permissions |
| `cached_network_image` | Optimized image loading |
| `flutter_svg` | SVG assets |

### Backend (Python)
| Technology | Purpose |
|---|---|
| `Python 3.10` | Backend language |
| `Flask` + `Gunicorn` | Web server & REST API |
| `dlib` / face_recognition | Face recognition model |
| `OpenBLAS` + `LAPACK` | ML computation optimization |
| `Docker` | Containerized deployment |

---

## 🏗️ Project Architecture

```
FaceGuard/
├── lib/                  # Flutter app source code
│   ├── ai/               # AI model files
│   └── ...               # Screens, widgets, services
├── backend/              # Python ML backend
│   ├── server.py         # Flask API server
│   └── requirements.txt  # Python dependencies
├── assets/               # Images, icons, fonts
├── android/              # Android platform files
├── ios/                  # iOS platform files
├── web/                  # Web platform files
└── Dockerfile            # Docker config for backend
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Python 3.10+
- Docker (for running the backend)
- Firebase project with Firestore, Auth & Storage enabled

### 1. Clone the repository
```bash
git clone https://github.com/Aran-1337/FaceGuard.git
cd FaceGuard
```

### 2. Run the Flutter app
```bash
flutter pub get
flutter run
```

### 3. Run the Python backend with Docker
```bash
docker build -t faceguard-backend .
docker run -p 5000:5000 faceguard-backend
```

---

## 🔧 Configuration

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication**, **Firestore**, and **Storage**
3. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
4. Place them in the appropriate platform directories

---

## 📋 Roadmap

- [x] Real-time face detection with ML Kit
- [x] Firebase integration (Auth, Firestore, Storage)
- [x] Python backend with Docker support
- [ ] Improve face recognition accuracy
- [ ] Complete admin panel
- [ ] Add liveness detection (anti-spoofing)
- [ ] Push notifications

---

## 👨‍💻 Author

**Abdelrahman Abdelglil**
Junior Flutter Developer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue)](https://linkedin.com/in/abdelrahman-abdelglil)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black)](https://github.com/Aran-1337)

---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
