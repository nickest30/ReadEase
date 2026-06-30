import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;

  void _onDigitPressed(String digit) {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.length < 4) _pin += digit;
        if (_pin.length == 4) _isConfirming = true;
      } else {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) _verifyAndSave();
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = "PINs don't match. Try again.";
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      return;
    }

    final student = ModalRoute.of(context)!.settings.arguments as Student;
    final hashedPin = BCrypt.hashpw(_pin, BCrypt.gensalt());

    await DatabaseService.instance.updatePin(student.id!, hashedPin);

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/student-home',
      (route) => false,
      arguments: student,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Set Your PIN',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3A3A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Choose a 4-digit PIN for quick access',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: Color(0xFF6B7878),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < currentPin.length;
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

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFFF6F61),
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              _NumberPad(
                onDigit: _onDigitPressed,
                onBackspace: _onBackspace,
              ),
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