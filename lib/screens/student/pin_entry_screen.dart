import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../models/student.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _enteredPin = '';
  int _attemptsRemaining = 5;
  bool _isLocked = false;

  void _onDigitPressed(String digit, Student student) {
    if (_isLocked) return;

    setState(() {
      if (_enteredPin.length < 4) _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin(student);
    }
  }

  void _onBackspace() {
    if (_isLocked) return;
    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  void _verifyPin(Student student) {
    final isCorrect = BCrypt.checkpw(_enteredPin, student.pinHash ?? '');

    if (isCorrect) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/student-home',
        (route) => false,
        arguments: student,
      );
    } else {
      setState(() {
        _attemptsRemaining--;
        _enteredPin = '';
        if (_attemptsRemaining <= 0) {
          _isLocked = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = ModalRoute.of(context)!.settings.arguments as Student;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF2BAFA0),
                child: Icon(Icons.person, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                student.displayName,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),

              if (_isLocked) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF0D9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8A93B)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'PROFILE LOCKED',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8B5FBF),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Too many incorrect attempts.\nFull login is required to regain access.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Color(0xFF6B7878),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2BAFA0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Back to Profiles',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  '$_attemptsRemaining attempts remaining',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Color(0xFF6B7878),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final filled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? const Color(0xFF2BAFA0)
                            : const Color(0xFFE9DCBE),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),

                _NumberPad(
                  onDigit: (digit) => _onDigitPressed(digit, student),
                  onBackspace: _onBackspace,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _NumberPad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final layout = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      children: layout.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) {
              return const SizedBox(width: 72, height: 60);
            }
            return Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                width: 60,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    if (key == '⌫') {
                      onBackspace();
                    } else {
                      onDigit(key);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF2E3A3A),
                    elevation: 1,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    key,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}