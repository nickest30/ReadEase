import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/connectivity_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';

class LinkParentScreen extends StatefulWidget {
  const LinkParentScreen({super.key});

  @override
  State<LinkParentScreen> createState() => _LinkParentScreenState();
}

class _LinkParentScreenState extends State<LinkParentScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  bool _linking = false;
  String? _errorMessage;
  Map<String, dynamic>? _validated;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    SfxService.tap();
    
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters.');
      return;
    }

    if (!context.read<ConnectivityProvider>().isOnline) {
      setState(() => _errorMessage = 'You\'re offline. Try again with internet.');
      return;
    }

    setState(() {
      _verifying = true;
      _errorMessage = null;
      _validated = null;
    });

    try {
      final result = await FirestoreService.instance.validateLinkCode(code);
      if (!mounted) return;

      setState(() {
        _verifying = false;
        if (result == null) {
          _errorMessage = 'Invalid or expired code. Ask your parent for a new one.';
        } else {
          _validated = result;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _errorMessage = 'Connection error. Please try again.';
      });
    }
  }

  Future<void> _confirmLink() async {
    SfxService.tap();
    if (_validated == null) return;

    final student = context.read<StudentProvider>().currentStudent;
    if (student == null || student.firebaseUid == null) {
      setState(() => _errorMessage = 'Not signed in. Try again.');
      return;
    }

    setState(() {
      _linking = true;
      _errorMessage = null;
    });

    final parentUid = _validated!['parentUid'] as String;
    final parentName = _validated!['parentName'] as String;

    bool ok = false;
    try {
      ok = await FirestoreService.instance.linkStudentToParent(
        studentUid: student.firebaseUid!,
        parentUid: parentUid,
      );
    } catch (e) {
      debugPrint('linkStudentToParent failed: $e');
    }

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _linking = false;
        _errorMessage = 'Could not link. Check your internet.';
      });
      return;
    }

    // Update local DB
    await DatabaseService.instance.updateStudentParent(
      student.id!,
      parentUid,
      true,
    );

    if (!mounted) return;

    final refreshed =
        await DatabaseService.instance.getStudentById(student.id!);
    if (!mounted || refreshed == null) return;

    context.read<StudentProvider>().updateStudent(refreshed);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.accentTeal, size: 28),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Linked!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'You\'re now linked to $parentName.\n'
          'They can see your reading progress!',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Great!',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final student = context.watch<StudentProvider>().currentStudent;

    if (student == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return const SizedBox.shrink();
    }

    if (student.isLinked) {
      return Scaffold(
        backgroundColor: AppColors.studentBg,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: AppColors.accentTeal,
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    'Already Linked',
                    style: AppText.h2,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your progress is already shared with your parent.',
                    style: AppText.caption,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                  const Text('Link to Parent', style: AppText.h1),
                  const SizedBox(height: 2),
                  const Text(
                    'Enter the code from your parent',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Center(
                    child: Image.asset(
                      'assets/images/mascot/motter_waving.png',
                      width: 140,
                      height: 140,
                      cacheWidth: 280,
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
                          Icons.family_restroom_rounded,
                          size: 60,
                          color: AppColors.accentPurple,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Parent Code',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return newValue.copyWith(text: newValue.text.toUpperCase());
                      }),
                    ],
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'ABC123',
                      hintStyle: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 6,
                        color: AppColors.textMuted.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        borderSide:
                            const BorderSide(color: AppColors.accentTeal, width: 2),
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textCoral,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (_validated != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        border: Border.all(
                          color: AppColors.accentTeal,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.family_restroom_rounded,
                            size: 40,
                            color: AppColors.accentTeal,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            _validated!['parentName'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Will be able to see your progress',
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _verifying
                          ? null
                          : _validated != null
                              ? _confirmLink
                              : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentTeal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: (_verifying || _linking)
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _validated != null ? 'LINK NOW' : 'VERIFY CODE',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}