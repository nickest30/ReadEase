import 'package:flutter/material.dart';
import 'package:bcrypt/bcrypt.dart';
import '../../models/parent.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _pinController = TextEditingController();
  int _selectedGrade = 1;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleAddChild() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pinController.text.length != 4) {
      setState(() => _errorMessage = 'PIN must be exactly 4 digits.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final parent =
          ModalRoute.of(context)!.settings.arguments as Parent;

      final existing = await DatabaseService.instance
          .getStudentByUsername(_usernameController.text.trim());

      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'That username is already taken.';
          _isSubmitting = false;
        });
        return;
      }

      final hashedPassword = BCrypt.hashpw(
        _passwordController.text,
        BCrypt.gensalt(),
      );
      final hashedPin = BCrypt.hashpw(
        _pinController.text,
        BCrypt.gensalt(),
      );

      final newChild = Student(
        username: _usernameController.text.trim(),
        passwordHash: hashedPassword,
        displayName: _displayNameController.text.trim(),
        gradeLevel: _selectedGrade,
        pinHash: hashedPin,
        isLinked: true,
        parentId: parent.id,
        createdAt: DateTime.now().toIso8601String(),
      );

      await DatabaseService.instance.insertLinkedStudent(newChild);

      if (!mounted) return;
      Navigator.of(context).pop(); // return to dashboard
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF0D9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 28, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back,
                      color: Color(0xFF2E3A3A)),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add Child Profile',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E3A3A),
                  ),
                ),
                const SizedBox(height: 20),

                _label('Display Name'),
                TextFormField(
                  controller: _displayNameController,
                  decoration: _inputDecoration('Child\'s name'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                const SizedBox(height: 14),

                _label('Username'),
                TextFormField(
                  controller: _usernameController,
                  decoration: _inputDecoration('Username for login'),
                  validator: (v) =>
                      v == null || v.trim().length < 3
                          ? 'At least 3 characters'
                          : null,
                ),
                const SizedBox(height: 14),

                _label('Grade Level'),
                Wrap(
                  spacing: 8,
                  children: List.generate(6, (index) {
                    final grade = index + 1;
                    final isSelected = _selectedGrade == grade;
                    return ChoiceChip(
                      label: Text('$grade'),
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedGrade = grade),
                      selectedColor: const Color(0xFF8B5FBF),
                      labelStyle: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF2E3A3A),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                _label('Password'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: _inputDecoration('Password'),
                  validator: (v) =>
                      v == null || v.length < 6
                          ? 'At least 6 characters'
                          : null,
                ),
                const SizedBox(height: 14),

                _label('4-digit PIN'),
                TextFormField(
                  controller: _pinController,
                  obscureText: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('4-digit PIN'),
                  validator: (v) =>
                      v == null || v.length != 4
                          ? 'PIN must be 4 digits'
                          : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFF6F61),
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleAddChild,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5FBF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'ADD CHILD',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7878),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCBE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE9DCBE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFF8B5FBF), width: 2),
      ),
    );
  }
}