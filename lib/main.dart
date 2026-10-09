import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'utils/color_blind_filter.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/student_provider.dart';
import 'providers/parent_provider.dart';
import 'providers/teacher_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/connectivity_provider.dart';

// Services
import 'services/content_importer.dart';
import 'services/database_service.dart';
import 'services/sync_service.dart';

// Screens
import 'screens/shared/splash_screen.dart';
import 'screens/shared/role_selection_screen.dart';
import 'screens/student/profile_list_screen.dart';
import 'screens/student/solo_signup_screen.dart';
import 'screens/student/set_pin_screen.dart';
import 'screens/student/pin_entry_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/grade_selection_screen.dart';
import 'screens/student/difficulty_selection_screen.dart';
import 'screens/student/results_screen.dart';
import 'screens/student/progress_dashboard_screen.dart';
import 'screens/student/badge_collection_screen.dart';
import 'screens/student/leaderboard_screen.dart';
import 'screens/student/student_settings_screen.dart';
import 'screens/student/student_signin_screen.dart';
import 'screens/student/edit_profile_screen.dart';
import 'screens/student/change_pin_screen.dart';
import 'screens/student/join_class_screen.dart';
import 'screens/student/link_parent_screen.dart';
import 'screens/student/lesson_play_screen.dart';
import 'screens/student/quiz_play_screen.dart';
import 'screens/student/my_dictionary_screen.dart';

import 'screens/parent/parent_welcome_screen.dart';
import 'screens/parent/parent_signup_screen.dart';
import 'screens/parent/parent_login_screen.dart';
import 'screens/parent/parent_dashboard_screen.dart';
import 'screens/parent/add_child_screen.dart';
import 'screens/parent/child_progress_screen.dart';
import 'screens/parent/generate_link_code_screen.dart';

import 'screens/teacher/teacher_welcome_screen.dart';
import 'screens/teacher/teacher_signup_screen.dart';
import 'screens/teacher/teacher_login_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/create_class_screen.dart';
import 'screens/teacher/class_overview_screen.dart';
import 'screens/teacher/teacher_student_progress_screen.dart';
import 'screens/teacher/class_analytics_screen.dart';
import 'screens/teacher/class_leaderboard_screen.dart';
import 'screens/games/memory_match_screen.dart';
import 'screens/games/bubble_pop_screen.dart';
import 'screens/games/drag_drop_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Import bundled JSON content into SQLite
  await ContentImporter.instance.importAllGrades();

  // Housekeeping — prune stale login/PIN attempts (>24h old)
  try {
    await DatabaseService.instance.pruneOldAttempts();
  } catch (e) {
    debugPrint('⚠️ pruneOldAttempts failed (non-blocking): $e');
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();

  runApp(ReadEaseApp(settingsProvider: settingsProvider));
}

class ReadEaseApp extends StatefulWidget {
  final SettingsProvider settingsProvider;

  const ReadEaseApp({super.key, required this.settingsProvider});

  @override
  State<ReadEaseApp> createState() => _ReadEaseAppState();
}

class _ReadEaseAppState extends State<ReadEaseApp> {
  bool _syncWired = false;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => ParentProvider()),
        ChangeNotifierProvider(create: (_) => TeacherProvider()),
        ChangeNotifierProvider.value(value: widget.settingsProvider),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          if (!_syncWired) {
            _wireConnectivitySync(context);
            _syncWired = true;
          }

          return MaterialApp(
            title: 'ReadEase',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.accentTeal,
              ),
              useMaterial3: true,
              fontFamily: 'Nunito',
              scaffoldBackgroundColor: AppColors.introBg,
            ),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settings.textScale),
                ),
                child: ColorBlindFilter(
                  mode: settings.colorBlindMode,
                  child: child!,
                ),
              );
            },
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/role-selection': (context) => const RoleSelectionScreen(),
              '/student-profile-list': (context) => const ProfileListScreen(),
              '/solo-signup': (context) => const SoloSignupScreen(),
              '/set-pin': (context) => const SetPinScreen(),
              '/pin-entry': (context) => const PinEntryScreen(),
              '/student-home': (context) => const StudentHomeScreen(),
              '/grade-selection': (context) => const GradeSelectionScreen(),
              '/difficulty-selection': (context) =>
                  const DifficultySelectionScreen(),
              '/results': (context) => const ResultsScreen(),
              '/progress': (context) => const ProgressDashboardScreen(),
              '/badges': (context) => const BadgeCollectionScreen(),
              '/leaderboard': (context) => const LeaderboardScreen(),
              '/settings': (context) => const StudentSettingsScreen(),
              '/parent-welcome': (context) => const ParentWelcomeScreen(),
              '/parent-signup': (context) => const ParentSignupScreen(),
              '/parent-login': (context) => const ParentLoginScreen(),
              '/parent-dashboard': (context) => const ParentDashboardScreen(),
              '/add-child': (context) => const AddChildScreen(),
              '/child-progress': (context) => const ChildProgressScreen(),
              '/teacher-welcome': (context) => const TeacherWelcomeScreen(),
              '/teacher-signup': (context) => const TeacherSignupScreen(),
              '/teacher-login': (context) => const TeacherLoginScreen(),
              '/teacher-dashboard': (context) => const TeacherDashboardScreen(),
              '/create-class': (context) => const CreateClassScreen(),
              '/class-overview': (context) => const ClassOverviewScreen(),
              '/teacher-student-progress': (context) =>
                  const TeacherStudentProgressScreen(),
              '/class-analytics': (context) => const ClassAnalyticsScreen(),
              '/class-leaderboard': (context) => const ClassLeaderboardScreen(),
              '/student-signin': (context) => const StudentSignInScreen(),
              '/edit-profile': (context) => const EditProfileScreen(),
              '/change-pin': (context) => const ChangePinScreen(),
              '/join-class': (context) => const JoinClassScreen(),
              '/generate-link-code': (context) =>
                  const GenerateLinkCodeScreen(),
              '/link-parent': (context) => const LinkParentScreen(),
              '/lesson-play': (context) => const LessonPlayScreen(),
              '/quiz-play': (context) => const QuizPlayScreen(),
              '/my-dictionary': (context) => const MyDictionaryScreen(),
              '/memory-match': (context) => const MemoryMatchScreen(),
              '/bubble-pop': (context) => const BubblePopScreen(),
              '/drag-drop': (context) => const DragDropScreen(),
            },
          );
        },
      ),
    );
  }

  /// Wire ConnectivityProvider.onWentOnline → SyncService.syncAll.
  /// Called once on first build after providers are mounted.
  void _wireConnectivitySync(BuildContext context) {
    final connectivity = context.read<ConnectivityProvider>();
    final studentProvider = context.read<StudentProvider>();
    final authProvider = context.read<AuthProvider>();

    connectivity.onWentOnline = () {
      final student = studentProvider.currentStudent;
      if (student == null) return;
      debugPrint('🔄 Connectivity restored — triggering sync');
      SyncService.instance.syncAll(
        student: student,
        connectivity: connectivity,
        authProvider: authProvider,
      );
    };
  }
}