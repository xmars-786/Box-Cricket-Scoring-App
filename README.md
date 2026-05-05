# 🏏 Apna Score

<p align="center">
  <img src="assets/images/app_icon_new.png" alt="Apna Score Logo" width="150">
</p>

<p align="center">
  <b>The Ultimate Box Cricket Scoring Companion.</b><br>
  Real-time updates, tournament tracking, and professional scorecards—all in your pocket.
</p>

---

## 🚀 Overview

**Apna Score** is a high-performance Flutter application designed for local cricket enthusiasts, tournament organizers, and scorers. It brings the professional feel of international cricket scoring to your local box cricket matches. With seamless Firebase integration, every run, wicket, and boundary is synced in real-time.

## ✨ Core Features

### 🏆 Advanced Tournament Management
- **Versatile Formats**: Support for League (Round Robin) and Knockout (Elimination) tournament styles.
- **Live Leaderboards**: Real-time updated points table with automatic Net Run Rate (NRR) calculation.
- **Hall of Heroes**: Automatic tracking for **Player of the Tournament**, **Best Batsman**, and **Best Bowler**.
- **Team Registry**: Manage multiple teams with detailed squad lists and performance history.

### ⚡ Professional Scoring Engine
- **Ball-by-Ball Precision**: Intuitive scoring interface for recording every run, wicket, and extra.
- **Custom Rule Engine**: Support for Box Cricket rules like *Last Player Standing* and *Limited Overs per Player*.
- **Real-time Sync**: Every ball is instantly synced across all devices using Firebase Cloud Firestore.
- **Smart Validation**: Built-in rules to prevent scoring errors and ensure data integrity.

### 📊 In-depth Analytics & History
- **Interactive Scorecards**: Detailed breakdown of every innings, including strike rates and economy.
- **Partnership Tracking**: Visualize key batting partnerships and their impact on the match.
- **Match Archive**: A permanent digital record of every match played, with quick-access history.
- **Player Profiles**: Comprehensive stats for every player, tracking career progress and milestones.

### 📄 Professional Reporting & Sharing
- **PDF Report Engine**: Generate professional-grade tournament summaries and match scorecards.
- **Intelligent Filtering**: Clean reports that automatically handle team deletions and data changes.
- **Instant Sharing**: Share live match links or final result cards directly to WhatsApp, Instagram, and more.

### 🎨 Premium Experience
- **Adaptive Themes**: Seamless transition between sleek Dark Mode and clean Light Mode.
- **Ultra-Fast Performance**: Parallel data fetching architecture for zero-lag leaderboard loading.
- **Modern Design**: High-end typography (Outfit/Inter) and smooth micro-animations for a premium feel.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (v3.7.2+)
- **Backend**: [Firebase](https://firebase.google.com/)
  - 🔥 **Cloud Firestore**: Real-time database for live score syncing.
  - 🔑 **Firebase Auth**: Secure user authentication and management.
- **State Management**: [GetX](https://pub.dev/packages/get)
- **UI & UX**:
  - **Google Fonts**: Outfit & Inter for a modern typography feel.
  - **Lottie**: Smooth vector animations for an interactive experience.
  - **Shimmer**: Elegant loading states.
- **Key Plugins**:
  - `share_plus`: For social sharing.
  - `pdf` & `printing`: For high-quality document generation.
  - `connectivity_plus`: To handle offline/online states.

## 📁 Project Structure

```text
lib/
├── core/                   # App Foundation & Shared Resources
│   ├── constants/          # Configuration, API keys, and app strings
│   ├── controllers/        # Global GetX controllers (State Management)
│   ├── models/             # Data models and Firebase serialization
│   ├── routes/             # App navigation and route definitions
│   ├── services/           # External services (PDF, Cloud, Firebase)
│   ├── theme/              # Styling, colors, and layout tokens
│   └── utils/              # UI helpers and business logic utilities
├── features/               # Domain-driven Feature Modules
│   ├── auth/               # User authentication & lifecycle
│   ├── home/               # Dashboard and navigation hub
│   ├── scoring/            # Live ball-by-ball scoring logic
│   ├── tournament/         # Competition management & bracket logic
│   ├── match/              # Fixture setup and individual match views
│   ├── team/               # Squad management and player rosters
│   ├── history/            # Past match archives and logs
│   ├── scorecard/          # Statistical visualizations & exports
│   └── admin/              # Management tools and approvals
├── app.dart                # Main application widget & configuration
└── main.dart               # Entry point & dependency injection
```

## ⚙️ Getting Started

### Prerequisites

- Flutter SDK (latest stable version recommended).
- Firebase project configured for Android/iOS.

### Installation

1. **Clone the Repo:**

   ```bash
   git clone https://github.com/mohammad2425/apna_score_app.git
   ```

2. **Fetch Dependencies:**

   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   - Add your `google-services.json` to `android/app/`.
   - Add your `GoogleService-Info.plist` to `ios/Runner/`.

4. **Launch:**
   ```bash
   flutter run
   ```

---

## 🎨 Design Philosophy

Apna Score follows a **Premium & Clean** design aesthetic:

- **Responsive Layouts**: Optimized for both small and large screen devices.
- **Dynamic Themes**: Fully functional Dark and Light modes.
- **Active UI**: Smooth shimmers and smart loading states for a seamless data experience.
- **Micro-interactions**: Subtle animations that make the app feel alive.

## 🆕 Latest Updates (v2.1)

- **🚀 Performance Overhaul**: Implemented parallel data fetching for all statistical modules, reducing leaderboard load times by over 80%.
- **📄 Advanced PDF Engine**: New robust PDF generation with intelligent filtering that gracefully handles team modifications and historical data.
- **✨ Active Loading System**: Introduced a custom shimmer and skeleton loading system to ensure a smooth, flicker-free user experience.
- **🏆 Hall of Heroes**: Refined Player of the Tournament (POT) algorithm for more accurate performance tracking.

## 🗺️ Roadmap

- [ ] **Live Commentary**: AI-powered text commentary for live matches.
- [ ] **Auction Module**: Built-in player auction system for tournament organizers.
- [ ] **Player Career Deep-Dive**: Advanced graphical representation of player performance over time.
- [ ] **Global Community**: Discover and join local tournaments in your area.

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

## 👨‍💻 Credits

Developed with ❤️ by **Mammu**.


<p align="center">
  <b>Empowering local cricket with professional tools.</b>
</p>
