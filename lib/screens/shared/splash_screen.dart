import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

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

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward();

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
      backgroundColor: AppColors.introBg,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Yse mascot — waving pose
              const _YseImage(
                assetPath: 'assets/images/mascot/yse_wave.png',
                size: 180,
                fallbackIcon: Icons.menu_book_rounded,
              ),
              const SizedBox(height: AppSpacing.xl),

              // App name
              const Text('ReadEase', style: AppText.display),
              const SizedBox(height: AppSpacing.sm),

              // Tagline
              const Text(
                'Read at your own ease.',
                style: AppText.body,
              ),

              const SizedBox(height: AppSpacing.xxxl),

              // Animated loading bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 8,
                        backgroundColor: AppColors.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.accentTeal,
                        ),
                      ),
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

/// Reusable Yse image with a graceful fallback if the asset is missing.
/// Use this EVERYWHERE Yse appears.
class _YseImage extends StatelessWidget {
  final String assetPath;
  final double size;
  final IconData fallbackIcon;

  const _YseImage({
    required this.assetPath,
    required this.size,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback: rounded container with icon
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(color: AppColors.border, width: 2),
          ),
          child: Center(
            child: Icon(
              fallbackIcon,
              size: size * 0.5,
              color: AppColors.accentTeal,
            ),
          ),
        );
      },
    );
  }
}