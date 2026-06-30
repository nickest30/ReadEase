import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    // Controls the loading bar animation over 2.5 seconds
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Start the animation immediately
    _controller.forward();

    // Navigate to Role Selection after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/role-selection');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo placeholder — we'll replace this with
              // the real ReadEase logo image later
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2BAFA0),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'RE',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // App name
              const Text(
                'ReadEase',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),

              const SizedBox(height: 8),

              // Tagline
              const Text(
                'Read at your own ease.',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7878),
                ),
              ),

              const SizedBox(height: 48),

              // Animated loading bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progressAnimation.value,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFE9DCBE),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2BAFA0),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}