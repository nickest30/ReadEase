import 'package:flutter/material.dart';
import '../../models/student.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final student = ModalRoute.of(context)!.settings.arguments as Student;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(0xFF2BAFA0),
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${student.displayName}!',
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E3A3A),
                          ),
                        ),
                        const Text(
                          'What do you want to do today?',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Color(0xFF6B7878),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              _HomeCard(
                icon: Icons.menu_book_rounded,
                label: 'Start Learning',
                sublabel: 'Pick a grade and lesson',
                color: const Color(0xFFFF6F61),
                onTap: () {
                  // Will connect to Grade Selection screen soon
                },
              ),
              const SizedBox(height: 14),
              _HomeCard(
                icon: Icons.emoji_events_rounded,
                label: 'My Badges',
                sublabel: 'See what you earned',
                color: const Color(0xFFE8A93B),
                onTap: () {},
              ),
              const SizedBox(height: 14),
              _HomeCard(
                icon: Icons.bar_chart_rounded,
                label: 'Progress',
                sublabel: 'Track your journey',
                color: const Color(0xFF2BAFA0),
                onTap: () {},
              ),
              const SizedBox(height: 14),
              _HomeCard(
                icon: Icons.leaderboard_rounded,
                label: 'Leaderboard',
                sublabel: 'See your ranking',
                color: const Color(0xFF8B5FBF),
                onTap: () {},
              ),
              const SizedBox(height: 14),
              _HomeCard(
                icon: Icons.settings_rounded,
                label: 'Settings',
                sublabel: 'Edit profile and audio',
                color: const Color(0xFF6B7878),
                onTap: () {},
              ),

              const Spacer(),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F61),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save & Exit',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF2E3A3A),
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: Color(0xFF6B7878),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color),
          ],
        ),
      ),
    );
  }
}