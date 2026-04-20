# 📘 YugenManga

YugenManga is a high-performance, offline-online manga reader for Android. Built with a modern **'Manga-Noir'** aesthetic, it provides a premium reading experience inspired by Tachiyomi, featuring glassmorphism UI elements and deep customization.

## Getting Started

### Prerequisites
- Flutter SDK
- Firebase project configuration (Google Sign-In & Auth)

### Installation
1. Clone the repository.
2. Run `flutter pub get`.
3. Ensure your `google-services.json` is placed in `android/app/`.
4. Build the APK: `flutter build apk --release`.

## ✨ Key Features

### 🎨 Premium Design
- **Manga-Noir Aesthetic**: A sleek, modern dark theme with deep purple accents and glassmorphism elements.
- **Glassmorphism UI**: Modern frosted-glass effects on login and detail screens.
- **Fluid Animations**: Custom fade and slide transitions for a polished feel.
- **Theming**: Support for custom accent colors and Material Design 3.

### 📖 Reading & Library
- **Advanced Reader**: Multiple reading modes, page transitions (Slide Up, Slide Right, Fade), and full-screen immersive mode.
- **Offline Support**: Download entire chapters for reading without an internet connection.
- **MangaDex Integration**: Powered by the MangaDex API for a vast library of high-quality content.
- **Statistics**: Track your reading habits with detailed statistics and activity heatmaps.

### 📥 Download & Cache Management
- **Hidden Cache**: Downloads are stored in a hidden `.manga_cache` directory, keeping your gallery clean from manga pages.
- **Smart Queue**: Sequential download manager with pause/resume functionality.
- **Batch Downloads**: Easily download the next 10, 50, or all chapters in one tap.

### 🔐 Security & Privacy
- **Privacy-First**: Local storage of sensitive data and profile picture caching for instant access.

## 🛠️ Built With
- **Flutter**: Cross-platform UI framework.
- **Firebase**: Authentication and secure user data sync.
- **SQLite**: Local database for library management and offline state.
- **MangaDex API**: The primary source for manga metadata and images.

## Contributing
Pull requests are welcome! Feel free to open an issue for bugs or feature suggestions.

## License
This project is licensed under the MIT License.
