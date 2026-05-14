import 'package:flutter/material.dart';
import 'package:avatar_monitoring/services/auth_service.dart';
import 'package:avatar_monitoring/screens/dashboard/dashboard.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _ink = Color(0xFF0A0D16);
const _card = Color(0xFF151C2E);
const _glass = Color(0xFF1A2440);
const _rim = Color(0xFF1F2D4A);
const _cyan = Color(0xFF00C8E8);
const _teal = Color(0xFF00E5A0);
const _ember = Color(0xFFFF6B6B);
const _violet = Color(0xFF7B68EE);
const _muted = Color(0xFF4A5880);
const _pale = Color(0xFF8A9BBF);
const _white = Color(0xFFE8EEFF);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _authService = AuthService();

  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _selectedGender = 'male';
  bool _obscurePass = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _register() async {
    final lastName = _lastNameCtrl.text.trim();
    final firstName = _firstNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final ageStr = _ageCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (lastName.isEmpty || firstName.isEmpty || email.isEmpty || phone.isEmpty || ageStr.isEmpty || password.isEmpty) {
      _showSnack('Veuillez remplir tous les champs', isError: true);
      return;
    }

    final age = int.tryParse(ageStr);
    if (age == null || age < 0 || age > 130) {
      _showSnack('Âge invalide', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnack('Le mot de passe doit contenir au moins 6 caractères', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final error = await _authService.signUp(
        lastName: lastName,
        firstName: firstName,
        email: email,
        phone: phone,
        age: age,
        gender: _selectedGender,
        password: password,
      );
      if (error != null) {
        if (mounted) _showSnack('Erreur : $error', isError: true);
      } else {
        // Auto sign in after registration
        final loginError = await _authService.signInWithEmailPassword(email, password);
        if (loginError == null && mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (_) => false,
          );
        } else if (mounted) {
          _showSnack('Compte créé ! Connectez-vous.', isError: false);
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    final color = isError ? _ember : _teal;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: color.withOpacity(0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color.withOpacity(0.4))),
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ink,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nav
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _rim)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: _pale, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CRÉER UN COMPTE', style: TextStyle(color: _cyan, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      Text('AVATAR OS · INSCRIPTION', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 1.5)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Section label
              _sectionHeader('INFORMATIONS PERSONNELLES'),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _rim)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Field(controller: _firstNameCtrl, label: 'PRÉNOM', hint: 'Jean', icon: Icons.person_outline_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _Field(controller: _lastNameCtrl, label: 'NOM', hint: 'Dupont', icon: Icons.badge_outlined)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Field(controller: _emailCtrl, label: 'EMAIL', hint: 'jean@avatar.os', icon: Icons.alternate_email_rounded, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 14),
                    _Field(controller: _phoneCtrl, label: 'TÉLÉPHONE', hint: '+33 6 00 00 00 00', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _Field(controller: _ageCtrl, label: 'ÂGE', hint: '30', icon: Icons.cake_outlined, keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('GENRE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 1.5)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: _glass, borderRadius: BorderRadius.circular(12), border: Border.all(color: _rim)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedGender,
                                    dropdownColor: _card,
                                    style: const TextStyle(color: _white, fontSize: 14),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
                                    isExpanded: true,
                                    items: const [
                                      DropdownMenuItem(value: 'male', child: Text('Homme')),
                                      DropdownMenuItem(value: 'female', child: Text('Femme')),
                                    ],
                                    onChanged: (v) => setState(() => _selectedGender = v ?? 'male'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _Field(
                      controller: _passwordCtrl,
                      label: 'MOT DE PASSE',
                      hint: '••••••••',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePass,
                      accentColor: _violet,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _muted, size: 18),
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit button
              GestureDetector(
                onTap: _isLoading ? null : _register,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: _isLoading ? [_muted.withOpacity(0.3), _muted.withOpacity(0.3)] : [_violet.withOpacity(0.9), _violet],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: _isLoading ? [] : [BoxShadow(color: _violet.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 6))],
                  ),
                  child: Center(
                    child: _isLoading
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_add_rounded, color: _ink, size: 18),
                              SizedBox(width: 8),
                              Text('CRÉER MON COMPTE', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Row(
    children: [
      Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: _cyan)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 2.5)),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 0.5, color: _rim)),
    ],
  );
}

// ─── Field ────────────────────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final Color accentColor;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.accentColor = _cyan,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = _focused ? widget.accentColor : _muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? widget.accentColor.withOpacity(0.6) : _rim, width: _focused ? 1.5 : 1),
          ),
          child: Focus(
            onFocusChange: (v) => setState(() => _focused = v),
            child: TextField(
              controller: widget.controller,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              style: const TextStyle(color: _white, fontSize: 14, fontFamily: 'monospace'),
              cursorColor: _cyan,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: _muted.withOpacity(0.6), fontSize: 12),
                prefixIcon: Icon(widget.icon, color: color, size: 16),
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
