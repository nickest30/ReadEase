import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';


class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() =>
      _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
  bool _audioEnabled = true;
  double _textSize = 1.0; // 0=small, 1=medium, 2=large

  @override
  Widget build(BuildContext context) {
    final student =
        ModalRoute.of(context)!.settings.arguments as Student;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: Color(0xFF2E3A3A)),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E3A3A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Avatar and display name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFF2BAFA0),
                      child: Text(
                        student.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      student.displayName,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E3A3A),
                      ),
                    ),
                    Text(
                      '@${student.username} · Grade ${student.gradeLevel}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Color(0xFF6B7878),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _SettingsTile(
                label: 'Audio',
                trailing: Switch(
                  value: _audioEnabled,
                  onChanged: (v) => setState(() => _audioEnabled = v),
                  activeThumbColor: const Color(0xFF2BAFA0),
                ),
              ),
              const SizedBox(height: 10),

              _SettingsTile(
                label: 'Text Size',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TextSizeButton(
                      label: 'S',
                      selected: _textSize == 0,
                      onTap: () => setState(() => _textSize = 0),
                    ),
                    const SizedBox(width: 6),
                    _TextSizeButton(
                      label: 'M',
                      selected: _textSize == 1,
                      onTap: () => setState(() => _textSize = 1),
                    ),
                    const SizedBox(width: 6),
                    _TextSizeButton(
                      label: 'L',
                      selected: _textSize == 2,
                      onTap: () => setState(() => _textSize = 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              _SettingsTile(
                label: 'Change PIN',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF6B7878),
                ),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    '/set-pin',
                    arguments: student,
                  );
                },
              ),
              const SizedBox(height: 10),

              _SettingsTile(
                label: 'Join a Class',
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF6B7878),
                ),
                onTap: () => _showJoinClassDialog(context, student),
              ),

              const Spacer(),

              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil(
                      (route) => route.isFirst,
                    );
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

  void _showJoinClassDialog(BuildContext context, Student student) {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Text(
          'Join a Class',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: 'Enter 6-character code',
            filled: true,
            fillColor: const Color(0xFFFCF0D9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9DCBE)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              final group = await DatabaseService.instance
                  .getClassGroupByJoinCode(code);
              if (!ctx.mounted) return;
              if (group == null) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Class not found.')),
                );
                return;
              }
              final alreadyEnrolled =
                  await DatabaseService.instance
                      .isStudentEnrolled(group.id!, student.id!);
              if (!ctx.mounted) return;
              if (alreadyEnrolled) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                      content: Text('Already enrolled in this class.')),
                );
                return;
              }
              await DatabaseService.instance
                  .enrollStudent(group.id!, student.id!);
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Joined ${group.className} successfully!'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2BAFA0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Join',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.label,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9DCBE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2E3A3A),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _TextSizeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TextSizeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2BAFA0) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? const Color(0xFF2BAFA0)
                : const Color(0xFFE9DCBE),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? Colors.white : const Color(0xFF6B7878),
            ),
          ),
        ),
      ),
    );
  }
}