import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/parent_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/error_state.dart';
import '../../widgets/email_verification_banner.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> with WidgetsBindingObserver {
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
      if (parentFirebaseUid != null) {
        try {
          final cloudDocs = await FirestoreService.instance
              .getChildrenOfParent(parentFirebaseUid);

          cloudChildren = cloudDocs.map((doc) {
            return Student(
              id: null, // cloud-only, no local ID yet
              username: (doc['username'] ?? '') as String,
              passwordHash: '',
              displayName: (doc['displayName'] ?? 'Unknown') as String,
              gradeLevel: (doc['gradeLevel'] ?? 0) as int,
              isLinked: true,
              parentId: parent.id,
              totalPoints: (doc['totalPoints'] ?? 0) as int,
              createdAt: DateTime.now().toIso8601String(),
              firebaseUid: (doc['uid'] ?? '') as String,
            );
          }).toList();
        } catch (e) {
          // Cloud fetch failed but local may still have data — log and continue.
          debugPrint('🔥 Cloud children load failed: $e');
        }
      }

      if (!mounted) return;

      // Merge — dedupe by firebaseUid
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
      debugPrint('👨‍👩‍👧 Load children ERROR: $e');
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
    if (parent.emailVerified) return; // already verified, nothing to do

    final authProvider = context.read<AuthProvider>();
    final verified = await authProvider.checkEmailVerified();
    if (!verified || !mounted) return;

    // Update local + cloud
    await DatabaseService.instance.markParentEmailVerified(parent.id!);
    await FirestoreService.instance
        .markEmailVerified(parent.firebaseUid!, 'parent');

    // Refresh provider so the banner disappears
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: AppColors.textMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
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

    context.read<AuthProvider>().signOut();
    context.read<ParentProvider>().logout();

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/parent-welcome',
      ModalRoute.withName('/role-selection'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parent = context.watch<ParentProvider>().currentParent;

    if (parent == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/parent-welcome',
            ModalRoute.withName('/role-selection'),
          );
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.parentBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.parentBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              _buildHeader(parent.fullName),
              const SizedBox(height: AppSpacing.md),

              // Email verification banner (only shows if not verified)
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
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────

  Widget _buildHeader(String fullName) {
    final firstName = fullName.split(' ').first;
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
          width: 70,
          height: 70,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Container(
            width: 70,
            height: 70,
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
              color: AppColors.accentPurple,
              size: 34,
            ),
          ),
        ),
      ],
    );
  }

  // ── Body: loading / error / empty / grid ─────────────────────────

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
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 0.95,
        ),
        itemCount: _children.length,
        itemBuilder: (context, index) {
          final child = _children[index];
          return _ChildCard(
            child: child,
            onTap: () => Navigator.of(context).pushNamed(
              '/child-progress',
              arguments: {'child': child},
            ),
          );
        },
      ),
    );
  }

  // ── Bottom actions ───────────────────────────────────────────────

  Widget _buildActions() {
    final canAddMore = _children.length < 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canAddMore) ...[
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/generate-link-code'),
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text(
                'Link Code for Your Kids',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
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
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).pushNamed('/add-child');
                _loadChildren();
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Child',
                style: TextStyle(
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
          const SizedBox(height: AppSpacing.sm),
        ],

        SizedBox(
          height: 50,
          child: OutlinedButton(
            onPressed: _handleLogout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textCoral,
              side: const BorderSide(color: AppColors.accentCoral),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
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
        ),
      ],
    );
  }

  // ── Empty state ──────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Image.asset(
            'assets/images/mascot/motter_gentle.png',
            width: 160,
            height: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: AppColors.accentPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentPurple,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_add_alt_rounded,
                size: 72,
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
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).pushNamed('/add-child');
                _loadChildren();
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text(
                'Add Your First Child',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
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

// ─────────────────────────────────────────────────────────
// _ChildCard
// ─────────────────────────────────────────────────────────

class _ChildCard extends StatelessWidget {
  final Student child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = child.displayName.isNotEmpty
        ? child.displayName[0].toUpperCase()
        : '?';

    return InkWell(
      onTap: onTap,
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
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.accentPurple,
                shape: BoxShape.circle,
              ),
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
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
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
            Text(
              'Grade ${child.gradeLevel}',
              style: AppText.caption,
            ),
            const SizedBox(height: 4),
            Text(
              '${child.totalPoints} pts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textYellow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}