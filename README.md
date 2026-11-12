# ReadEase

A gamified learning aid application for Filipino elementary learners (Grades 1 to 6) who experience difficulty with reading.

ReadEase is a capstone project for the Bachelor of Science in Information Technology program at STI College Global City.

## Overview

ReadEase is an offline-first Android application built with Flutter. It combines audio-visual word lessons, sentence-by-sentence passages with comprehension questions for Grades 4 to 6, and eight interactive mini-games. The application supports three roles, each with its own dedicated portal:

- **Learners** practice reading through lessons, games, and pronunciation practice.
- **Parents or guardians** monitor their children's progress from a centralized dashboard.
- **Teachers** create class groups, monitor student progress, and view class analytics.

All core learning features work without an internet connection. The application is designed for Android 8.0 (Oreo) and above.

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile framework | Flutter 3.41.6, Dart 3.11.4 |
| Local database | SQLite via `sqflite`, schema version 23 |
| Cloud backend | Firebase Authentication and Cloud Firestore |
| State management | Provider |
| Audio playback | audioplayers |
| Secure storage | flutter_secure_storage with encryptedSharedPreferences |
| Speech recognition | speech_to_text and permission_handler |
| Network detection | connectivity_plus |
| Settings persistence | shared_preferences |

## Project Structure
lib/
├── main.dart # App entry point, routing, provider setup
├── models/ # Data models (Student, Parent, Teacher, Word, Badge)
├── providers/ # ChangeNotifier state management
├── screens/
│ ├── parent/ # Parent portal screens
│ ├── teacher/ # Teacher portal screens
│ ├── student/ # Learner portal screens
│ ├── shared/ # Cross-role screens (splash, role selection, auth, OTP)
│ └── games/ # Eight mini-game screens
├── services/ # Database, auth, sync, content importer, BGM, SFX
├── utils/ # Theme, validators, helpers
└── widgets/ # Reusable UI components (info button, PIN dots, etc.)

assets/
├── audio/
│ ├── bgm/ # Background music tracks
│ ├── sfx/ # Sound effects
│ ├── words/ # Word pronunciation audio
│ ├── cues/ # Lesson cue audio
│ ├── sentences/ # Sample sentence audio
│ ├── passages/ # Passage sentence audio
│ └── questions/ # Comprehension question stem audio
├── data/ # Lesson content JSON (grade1.json through grade6.json)
├── docs/ # Schema documentation and project notes
├── fonts/ # Nunito font family
└── images/
├── avatars/ # 12 preset avatar images
├── badge/ # Badge emblems for all grade and difficulty tiers
├── mascot/ # Yse, Motter, and Groo mascot poses
├── passages/ # Passage illustrations
└── words/ # Word images



## Setup

ReadEase requires the following to run locally:

- Flutter SDK 3.41.6 or later
- Dart SDK 3.11.4 or later
- Android Studio with an emulator running Android 8.0 (Oreo) or higher
- A Firebase project configured for Android (the `google-services.json` file must be placed in `android/app/`)

### Steps

```bash
# 1. Clone the repository
git clone https://github.com/nickest30/ReadEase.git
cd ReadEase

# 2. Fetch Flutter dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run


The application imports all content JSON files on first launch. This takes 1 to 3 seconds on most devices. Once complete, the app can be used fully offline.

Content Pipeline
Lesson content is bundled as six JSON files in assets/data/:

File	Grade	Words	Passages
grade1.json	Grade 1	23	None
grade2.json	Grade 2	36	None
grade3.json	Grade 3	39	None
grade4.json	Grade 4	39	3
grade5.json	Grade 5	42	3
grade6.json	Grade 6	42	3
On first launch, the ContentImporter service reads each JSON file and inserts the content into SQLite. The importer is idempotent. Re-importing the same content does not duplicate rows and does not lose user progress. When a JSON file's content_version field is updated, the importer detects the change and re-imports only that grade.

Evaluation
ReadEase was evaluated using the ISO/IEC 25010 software product quality model on four characteristics:

Functional Suitability: whether lessons, games, badges, and leaderboards work correctly for all user types

Performance Efficiency: whether the application responds within acceptable time limits on entry-level Android devices

Interaction Capability: whether the application is easy to navigate and appropriate for young learners

Reliability: whether the application behaves consistently during offline use, session resumption, and local data storage

Evaluation respondents were learners (n = 100), parents or guardians (n = 10), teachers (n = 6), and IT experts (n = 5). The full evaluation results are documented in Chapter 4 of the capstone manuscript.

Documentation
Document	Location
Capstone manuscript	Submitted separately
Database schema (v23)	assets/docs/schema.md
User's Guide	Appendix E of the capstone manuscript
Prompt Glossary	Appendix of the capstone manuscript
Source code excerpts	Appendix B of the capstone manuscript
Team
Kevin V. Agapay

Margarette B. Cipriano

Nikcol F. Estabaya

Chricielle Jhobeth M. Gapay

Institution: STI College Global City, Bachelor of Science in Information Technology
Adviser: Ms. Leny Z. Laya
Project Type: Capstone Project (Capstone 2)

License
This project is submitted in partial fulfillment of the requirements for the degree Bachelor of Science in Information Technology at STI College Global City. The source code and content are the property of the researchers and the institution.
