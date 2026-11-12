import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
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
    final connectivity = context.read<ConnectivityProvider>();
    final parent = parentProvider.currentParent;
    final parentUid = authProvider.uid;

    if (parent == null || parentUid == null) {
      setState(() => _error = 'Not signed in as parent.');
      return;
    }

    if (!connectivity.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You need to be online to generate a link code.',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
    final isTablet = Responsive.isTablet(context);
    final imgSize = Responsive.imageSize(context, base: 140);

    Widget content = SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          IconButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pop();
            },
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

          Center(
            child: Image.asset(
              'assets/images/mascot/motter_base.png',
              width: imgSize,
              height: imgSize,
              fit: BoxFit.contain,
              cacheWidth: (imgSize * 2).toInt(),
              errorBuilder: (_, _, _) => Container(
                width: imgSize,
                height: imgSize,
                decoration: BoxDecoration(
                  color: AppColors.accentPurple.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.accentPurple,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.vpn_key_rounded,
                  size: imgSize * 0.4,
                  color: AppColors.accentPurple,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
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
                    height: Responsive.buttonHeight(context),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SfxService.tap();
                        _copyCode();
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'COPY CODE',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                          ),
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
            height: Responsive.buttonHeight(context),
            child: ElevatedButton.icon(
              onPressed: _generating
                  ? null
                  : () {
                      SfxService.tap();
                      _generate();
                    },
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
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _code == null ? 'GENERATE CODE' : 'GENERATE NEW CODE',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                  ),
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
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(child: content),
    );
  }
}