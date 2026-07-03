import 'package:flutter/material.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/shared/role_selection_screen.dart';
import 'screens/student/profile_list_screen.dart';
import 'screens/student/solo_signup_screen.dart';
import 'screens/student/set_pin_screen.dart';
import 'screens/student/pin_entry_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'screens/student/grade_selection_screen.dart';
import 'screens/student/difficulty_selection_screen.dart';
import 'screens/student/lesson_screen.dart';
import 'screens/student/quiz_screen.dart';
import 'screens/student/results_screen.dart';
import 'utils/seed_data.dart';
import 'screens/student/progress_dashboard_screen.dart';
import 'screens/student/badge_collection_screen.dart';
import 'screens/student/leaderboard_screen.dart';
import 'screens/student/student_settings_screen.dart';
import 'screens/parent/parent_welcome_screen.dart';
import 'screens/parent/parent_signup_screen.dart';
import 'screens/parent/parent_login_screen.dart';
import 'screens/parent/parent_dashboard_screen.dart';
import 'screens/parent/add_child_screen.dart';
import 'screens/parent/child_progress_screen.dart';
import 'screens/teacher/teacher_welcome_screen.dart';
import 'screens/teacher/teacher_signup_screen.dart';
import 'screens/teacher/teacher_login_screen.dart';
import 'screens/teacher/teacher_dashboard_screen.dart';
import 'screens/teacher/create_class_screen.dart';
import 'screens/teacher/class_overview_screen.dart';
import 'screens/teacher/teacher_student_progress_screen.dart';
import 'screens/teacher/class_analytics_screen.dart';
import 'screens/teacher/class_leaderboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  seedWordsIfEmpty();
  runApp(const ReadEaseApp());
}

class ReadEaseApp extends StatelessWidget {
  const ReadEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReadEase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2BAFA0),
        ),
        useMaterial3: true,
        fontFamily: 'Nunito',
      ),
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
        '/difficulty-selection': (context) => const DifficultySelectionScreen(),
        '/lesson': (context) => const LessonScreen(),
        '/quiz': (context) => const QuizScreen(),
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
        '/teacher-student-progress': (context) => const TeacherStudentProgressScreen(),
        '/class-analytics': (context) => const ClassAnalyticsScreen(),
        '/class-leaderboard': (context) => const ClassLeaderboardScreen(),
      },
    );
  }
}