import 'package:flutter/material.dart';
import '../../models/parent.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  List<Student> _children = [];
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadChildren();
    }
  }

  Future<void> _loadChildren() async {
    final parent =
        ModalRoute.of(context)!.settings.arguments as Parent;
    final children = await DatabaseService.instance
        .getChildrenOfParent(parent.id!);
    if (!mounted) return;
    setState(() {
      _children = children;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parent =
        ModalRoute.of(context)!.settings.arguments as Parent;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Hello, ${parent.fullName.split(' ').first}!',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const Text(
                'My Children',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _children.isEmpty
                        ? const Center(
                            child: Text(
                              'No children added yet.\nTap "Add Child" to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 14,
                                color: Color(0xFF6B7878),
                              ),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.1,
                            ),
                            itemCount: _children.length,
                            itemBuilder: (context, index) {
                              final child = _children[index];
                              return _ChildCard(
                                child: child,
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    '/child-progress',
                                    arguments: {
                                      'parent': parent,
                                      'child': child,
                                    },
                                  );
                                },
                              );
                            },
                          ),
              ),

              if (_children.length < 4) ...[
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).pushNamed(
                        '/add-child',
                        arguments: parent,
                      );
                      _loadChildren(); // refresh on return
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
                      backgroundColor: const Color(0xFF8B5FBF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6F61),
                    side: const BorderSide(color: Color(0xFFFF6F61)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  final Student child;
  final VoidCallback onTap;

  const _ChildCard({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFF8B5FBF),
              child: Text(
                child.displayName[0].toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              child.displayName,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF2E3A3A),
              ),
            ),
            Text(
              'Grade ${child.gradeLevel}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: Color(0xFF6B7878),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${child.totalPoints} pts',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE8A93B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}