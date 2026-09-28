import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';

class GenerateLinkCodeScreen extends StatefulWidget {
  const GenerateLinkCodeScreen({super.key});

  @override
  State<GenerateLinkCodeScreen> createState() =>
      _GenerateLinkCodeScreenState();
}

class _GenerateLinkCodeScreenState extends State<GenerateLinkCodeScreen> {
  String? _code;
  DateTime? _expiresAt;
  bool _generating = false;
  String? _error;

  Future<void> _generate() async {
    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();
    final parent = parentProvider.currentParent;
    final parentUid = authProvider.uid;

    if (parent == null || parentUid == null) {
      setState(() => _error = 'Not signed in as parent.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    final code = await FirestoreService.instance.generateLinkCode(
      parentUid: parentUid,
      parentName: parent.fullName,
    );

    if (!mounted) return;

    setState(() {
      _generating = false;
      if (code == null) {
        _error = 'Could not generate code. Check your internet.';
      } else {
        _code = code;
        _expiresAt = DateTime.now().add(const Duration(hours: 24));
      }
    });
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Code copied!',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _timeRemaining() {
    if (_expiresAt == null) return '';
    final now = DateTime.now();
    if (now.isAfter(_expiresAt!)) return 'Expired';
    final diff = _expiresAt!.difference(now);
    if (diff.inHours >= 1) return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    return '${diff.inMinutes} minutes left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: AppSpacing.sm),

              const Text('Link Code', style: AppText.h1),
              const SizedBox(height: 2),
              const Text(
                'Share this code with your child',
                style: AppText.caption,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Motter
              Center(
                child: Image.asset(
                  'assets/images/mascot/motter_base.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppColors.accentPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accentPurple,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      size: 60,
                      color: AppColors.accentPurple,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // How it works
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'How it works',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      '1. Generate a code below\n'
                      '2. Give it to your child\n'
                      '3. Child enters it in their app\n'
                      '4. You can now see their progress',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: AppColors.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Code display
              if (_code != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(
                      color: AppColors.accentPurple,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPurple.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR CODE',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _code!,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPurple,
                          letterSpacing: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _timeRemaining(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text(
                            'COPY CODE',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (_error != null) ...[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textCoral,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: _generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _code == null ? 'GENERATE CODE' : 'GENERATE NEW CODE',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}