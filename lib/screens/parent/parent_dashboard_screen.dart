import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/sfx_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/avatar_helper.dart';
import '../../widgets/email_verification_banner.dart';
import '../../widgets/error_state.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen>
    with WidgetsBindingObserver {
  List<Student> _children = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren();
      _checkEmailVerification();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification();
    }
  }

  Future<void> _loadChildren() async {
    final parent = context.read<ParentProvider>().currentParent;
    final authProvider = context.read<AuthProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    if (parent == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Please sign in again.';
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final localChildren =
          await DatabaseService.instance.getChildrenOfParent(parent.id!);

      final parentFirebaseUid = authProvider.uid;

      List<Student> cloudChildren = [];
      if (parentFirebaseUid != null && connectivity.isOnline) {
        try {
          final cloudDocs = await FirestoreService.instance
              .getChildrenOfParent(parentFirebaseUid);

          cloudChildren = cloudDocs.map((doc) {
            return Student(
              id: null,
              username: (doc['username'] ?? '') as String,
              passwordHash: '',
              displayName: (doc['displayName'] ?? 'Unknown') as String,
              gradeLevel: (doc['gradeLevel'] ?? 0) as int,
              isLinked: true,
              parentId: parent.id,
              totalPoints: (doc['totalPoints'] ?? 0) as int,
              createdAt: DateTime.now().toIso8601String(),
              firebaseUid: (doc['uid'] ?? '') as String,
              avatarIndex: (doc['avatarIndex'] as int?) ?? 1,
            );
          }).toList();
        } catch (e) {
          debugPrint('Cloud children load failed: $e');
        }
      }

      if (!mounted) return;

      final Map<String, Student> merged = {};
      for (final c in localChildren) {
        final key = c.firebaseUid ?? 'local-${c.id}';
        merged[key] = c;
      }
      for (final c in cloudChildren) {
        final key = c.firebaseUid ?? 'cloud-${c.displayName}';
        if (!merged.containsKey(key)) {
          merged[key] = c;
        }
      }

      setState(() {
        _children = merged.values.toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Load children ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'We couldn\'t load your children right now.';
      });
    }
  }

  Future<void> _checkEmailVerification() async {
    final parent = context.read<ParentProvider>().currentParent;
    if (parent == null || parent.firebaseUid == null) return;
    if (parent.emailVerified) return;

    final authProvider = context.read<AuthProvider>();
    final verified = await authProvider.checkEmailVerified();
    if (!verified || !mounted) return;

    await DatabaseService.instance.markParentEmailVerified(parent.id!);
    await FirestoreService.instance
        .markEmailVerified(parent.firebaseUid!, 'parent');

    final updated = await DatabaseService.instance.getParentById(parent.id!);
    if (updated != null && mounted) {
      context.read<ParentProvider>().setParent(updated);
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'You can log back in anytime with your username and password.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(false);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final parentProvider = context.read<ParentProvider>();

    // Await the sign out to prevent race conditions
    await authProvider.signOut();
    parentProvider.logout();

    if (!mounted) return;
    
    // Clear the entire stack to prevent black screens on pop
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/role-selection',
      (route) => false,
    );
  }

  Future<void> _deleteChild(Student child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.accentCoral,
              size: 26,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Delete ${child.displayName}?',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This will permanently remove the child profile, reading '
          'progress, badges, points, and weak-word history from this '
          'device and the cloud.\n\n'
          'This cannot be undone.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(false);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              SfxService.tap();
              Navigator.of(ctx).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (child.firebaseUid != null && child.firebaseUid!.isNotEmpty) {
      try {
        await FirestoreService.instance
            .deleteStudentCascade(child.firebaseUid!);
      } catch (e) {
        debugPrint('cascade failed (continuing): $e');
      }
    }

    if (child.id != null) {
      await DatabaseService.instance.deleteStudent(child.id!);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${child.displayName} removed.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    await _loadChildren();
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>().currentParent;

    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/role-selection',
            (route) => false,
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.parentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isTablet = Responsive.isTablet(context);

    Widget content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.horizontalPadding(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _buildHeader(parent.fullName),
          const SizedBox(height: AppSpacing.md),

          if (parent.firebaseUid != null && !parent.emailVerified)
            EmailVerificationBanner(
              accentColor: AppColors.accentPurple,
              role: 'parent',
            ),

          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildBody()),
          const SizedBox(height: AppSpacing.md),
          _buildActions(),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );

    if (isTablet) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(child: content),
    );
  }

  Widget _buildHeader(String fullName) {
    final firstName = fullName.split(' ').first;
    final imgSize = Responsive.imageSize(context, base: 70);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $firstName!', style: AppText.h2),
              const SizedBox(height: 2),
              const Text('My Children', style: AppText.caption),
            ],
          ),
        ),
        Image.asset(
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
              Icons.family_restroom_rounded,
              color: AppColors.accentPurple,
              size: imgSize * 0.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPurple),
      );
    }

    if (_error != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ErrorState(
          title: 'Can\'t load children',
          message: _error,
          onRetry: _loadChildren,
        ),
      );
    }

    if (_children.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadChildren,
      color: AppColors.accentPurple,
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          if (constraints.maxWidth > 600) crossAxisCount = 3;
          if (constraints.maxWidth > 800) crossAxisCount = 4;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.95,
            ),
            itemCount: _children.length,
            itemBuilder: (context, index) {
              final child = _children[index];
              return _ChildCard(
                child: child,
                onTap: () {
                  SfxService.tap();
                  Navigator.of(context).pushNamed(
                    '/child-progress',
                    arguments: {'child': child},
                  );
                },
                onLongPress: () {
                  SfxService.tap();
                  _deleteChild(child);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    final canAddMore = _children.length < 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAddMore) ...[
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: OutlinedButton.icon(
              onPressed: () {
                SfxService.tap();
                Navigator.of(context).pushNamed('/generate-link-code');
              },
              icon: const Icon(Icons.qr_code_rounded),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Link Code for Your Kids',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentPurple,
                side: const BorderSide(
                  color: AppColors.accentPurple,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          SizedBox(
            height: Responsive.buttonHeight(context),
            child: ElevatedButton.icon(
              onPressed: () async {
                SfxService.tap();
                await Navigator.of(context).pushNamed('/add-child');
                _loadChildren();
              },
              icon: const Icon(Icons.add),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Add Child',
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
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        SizedBox(
          height: Responsive.buttonHeight(context),
          child: OutlinedButton.icon(
            onPressed: () {
              SfxService.tap();
              Navigator.of(context).pushNamed('/parent-settings');
            },
            icon: const Icon(Icons.settings_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Settings',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentPurple,
              side: const BorderSide(color: AppColors.accentPurple),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        SizedBox(
          height: Responsive.buttonHeight(context),
          child: OutlinedButton(
            onPressed: () {
              SfxService.tap();
              _handleLogout();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textCoral,
              side: const BorderSide(color: AppColors.accentCoral),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Log Out',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    final imgSize = Responsive.imageSize(context, base: 160);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Image.asset(
            'assets/images/mascot/motter_gentle.png',
            width: imgSize,
            height: imgSize,
            fit: BoxFit.contain,
            cacheWidth: (imgSize * 2).toInt(),
            errorBuilder: (_, _, _) => Container(
              width: imgSize,
              height: imgSize,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPurple,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.person_add_alt_rounded,
                size: imgSize * 0.45,
                color: AppColors.accentPurple,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'No children added yet',
            style: AppText.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Add your first child profile to start '
              'tracking their reading progress.',
              style: AppText.caption,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: Responsive.buttonHeight(context),
            child: ElevatedButton.icon(
              onPressed: () async {
                SfxService.tap();
                await Navigator.of(context).pushNamed('/add-child');
                _loadChildren();
              },
              icon: const Icon(Icons.add, size: 20),
              label: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Add Your First Child',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final Student child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ChildCard({
    required this.child,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPurple.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Image.asset(
                  avatarAssetPath(child.avatarIndex),
                  fit: BoxFit.cover,
                  cacheWidth: 150,
                  errorBuilder: (_, _, _) {
                    final initial = child.displayName.isNotEmpty
                        ? child.displayName[0].toUpperCase()
                        : '?';
                    return Container(
                      color: AppColors.accentPurple,
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                child.displayName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Grade ${child.gradeLevel}',
                style: AppText.caption,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${child.totalPoints} pts',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textYellow,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}