import 'package:flutter/material.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2BAFA0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      'RE',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Welcome text
              const Center(
                child: Text(
                  'Welcome to ReadEase!',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E3A3A),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              const Center(
                child: Text(
                  'A reading companion that helps kids\nlearn words, earn badges, and\nbuild confidence.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7878),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // LEARNER button
              _RoleButton(
                label: 'LEARNER',
                color: const Color(0xFF2BAFA0),
                onTap: () {
                  Navigator.of(context).pushNamed('/student-profile-list');
                },
              ),

              const SizedBox(height: 14),

              // PARENT button
              _RoleButton(
                label: 'PARENT',
                color: const Color(0xFF8B5FBF),
                onTap: () {
                  Navigator.of(context).pushNamed('/parent-welcome');
                },
              ),

              const SizedBox(height: 14),

              // TEACHER button
              _RoleButton(
                label: 'TEACHER',
                color: const Color(0xFFE8A93B),
                onTap: () {
                  Navigator.of(context).pushNamed('/teacher-welcome');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable role button widget — private to this file
class _RoleButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RoleButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: color.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}