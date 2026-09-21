import 'package:flutter/material.dart';

/// ReadEase design system.
class AppColors {
  AppColors._();

  // ── Role backgrounds ─────────────────────────────
  static const introBg = Color(0xFFFDE8C8);
  static const studentBg = Color(0xFFD4EFDF);
  static const parentBg = Color(0xFFD6EEF8);
  static const teacherBg = Color(0xFFF8F0FD);

  // ── Surfaces & borders ───────────────────────────
  static const surface = Color(0xFFFFF8F0);
  static const border = Color(0xFFE8DFD5);

  // ── Text ─────────────────────────────────────────
  static const textPrimary = Color(0xFF505050);
  static const textMuted = Color(0xFF8A8A8A);

  // ── Accents ──────────────────────────────────────
  static const accentTeal = Color(0xFF2EC4B6);
  static const accentGreen = Color(0xFF6BCB77);
  static const accentYellow = Color(0xFFFFD93D);
  static const accentOrange = Color(0xFFF4A261);
  static const accentCoral = Color(0xFFFF6B6B);
  static const accentPurple = Color(0xFF9B6B9E);

  // ── Text-safe variants ───────────────────────────
  static const textTeal = Color(0xFF1A8780);
  static const textGreen = Color(0xFF3A8C4A);
  static const textYellow = Color(0xFFB8860B);
  static const textOrange = Color(0xFFB85F1F);
  static const textCoral = Color(0xFFC42B2B);
  static const textPurple = Color(0xFF6B3F6E);
}

/// Typography scale.
class AppText {
  AppText._();

  static const display = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const h1 = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  static const h2 = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodyBold = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}

/// Corner radii.
class AppRadius {
  AppRadius._();

  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

/// Spacing scale.
class AppSpacing {
  AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

class AppColorsCB {
  AppColorsCB._();
  static const safeGreen = Color(0xFF2B6CB0);   
  static const safeCoral = Color(0xFFE07B39);  
  static const safeTeal = Color(0xFF2BAFA0);   
  static const safeYellow = Color(0xFFE8A93B); 
  static const safePurple = Color(0xFF6B3F8C);  
  static const safeOrange = Color(0xFFB85F1F);  

  static const triTeal = Color(0xFF9B6B9E);     
  static const triGreen = Color(0xFF6BCB77);    
  static const triYellow = Color(0xFFE8A93B);  
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get strong => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];
}