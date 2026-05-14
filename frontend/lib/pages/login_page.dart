import 'package:flutter/material.dart';
import 'package:avatar_monitoring/pages/register_page.dart';
import 'package:avatar_monitoring/screens/dashboard/dashboard.dart';
import 'package:avatar_monitoring/services/auth_service.dart';
import 'dart:math' as math;

// ─── Palette AVATAR OS ────────────────────────────────────────────────────────
const _ink = Color(0xFF0A0D16);
const _card = Color(0xFF151C2E);
const _glass = Color(0xFF1A2440);
const _rim = Color(0xFF1F2D4A);
const _cyan = Color(0xFF00C8E8);
const _teal = Color(0xFF00E5A0);
const _ember = Color(0xFFFF6B6B);
const _muted = Color(0xFF4A5880);
const _pale = Color(0xFF8A9BBF);
const _white = Color(0xFFE8EEFF);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading = false;

  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _fadeCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Veuillez remplir tous les champs', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final error = await _authService.signInWithEmailPassword(email, password);
      if (error != null) {
        if (mounted) _showSnack('Erreur : $error', isError: true);
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.4)),
        ),
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
      body: Stack(
        children: [
          const _Starfield(),
          const _Scanlines(),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildBrand(),
                    const SizedBox(height: 32),
                    _buildHero(),
                    const SizedBox(height: 28),
                    _buildSectionHeader('CONNEXION'),
                    const SizedBox(height: 12),
                    _buildForm(),
                    const SizedBox(height: 20),
                    _buildLoginButton(),
                    const SizedBox(height: 20),
                    _buildDivider(),
                    const SizedBox(height: 20),
                    _buildRegisterLink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AVATAR', style: TextStyle(color: _cyan, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 5)),
            Text('MONITORING SYSTEM', style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 2)),
          ],
        ),
        AnimatedBuilder(
          animation: _blinkCtrl,
          builder: (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _teal.withOpacity(0.08),
              border: Border.all(color: _teal.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _teal.withOpacity(0.4 + _blinkCtrl.value * 0.6),
                    boxShadow: [BoxShadow(color: _teal.withOpacity(_blinkCtrl.value * 0.5), blurRadius: 4)],
                  ),
                ),
                const SizedBox(width: 5),
                Text('SECURE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _teal, letterSpacing: 1.5, fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _ringCtrl,
            child: SizedBox(width: 180, height: 180, child: CustomPaint(painter: _HexPainter())),
          ),
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: 0.8 + _pulseCtrl.value * 0.3,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_cyan.withOpacity(0.2 * _pulseCtrl.value), Colors.transparent]),
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: Tween(begin: 0.0, end: -1.0).animate(_ringCtrl),
            child: SizedBox(width: 120, height: 120, child: CustomPaint(painter: _DashedRingPainter(color: _cyan.withOpacity(0.2)))),
          ),
          RotationTransition(
            turns: _ringCtrl,
            child: SizedBox(width: 95, height: 95, child: CustomPaint(painter: _DashedRingPainter(color: _cyan.withOpacity(0.35), solid: true))),
          ),
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0x3300C8E8), Color(0x337B68EE)],
              ),
              border: Border.all(color: _cyan.withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.shield_outlined, color: _cyan, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: _cyan)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted, letterSpacing: 2.5)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 0.5, color: _rim)),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _rim)),
      child: Column(
        children: [
          _AvatarField(
            controller: _emailController,
            label: 'ADRESSE EMAIL',
            hint: 'patient@avatar.os',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _AvatarField(
            controller: _passwordController,
            label: 'MOT DE PASSE',
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _muted, size: 18),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _login,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: _isLoading ? [_muted.withOpacity(0.3), _muted.withOpacity(0.3)] : [_cyan.withOpacity(0.9), _cyan],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: _isLoading ? [] : [BoxShadow(color: _cyan.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: _isLoading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _ink))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.login_rounded, color: _ink, size: 18),
                    SizedBox(width: 8),
                    Text('SE CONNECTER', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 0.5, color: _rim)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('OU', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 2))),
        Expanded(child: Container(height: 0.5, color: _rim)),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _rim)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Pas encore de compte ?  ', style: TextStyle(color: _muted, fontSize: 13)),
            Text('Créer un compte', style: TextStyle(color: _cyan, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: _cyan.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00C8E8).withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = math.pi / 180 * (60 * i - 30);
      final x = cx + r * math.cos(angle), y = cy + r * math.sin(angle);
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }
  @override bool shouldRepaint(_) => false;
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  final bool solid;
  _DashedRingPainter({required this.color, this.solid = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (solid) {
      canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, paint);
      return;
    }
    const dashCount = 24;
    const gap = 0.04;
    for (int i = 0; i < dashCount; i++) {
      final start = 2 * math.pi * i / dashCount;
      final end = start + 2 * math.pi / dashCount - gap;
      canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), start, end - start, false, paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _Starfield extends StatefulWidget {
  const _Starfield();
  @override State<_Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<_Starfield> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _stars = List.generate(55, (_) => _Star(_rng));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => CustomPaint(size: MediaQuery.of(context).size, painter: _StarPainter(_stars, _ctrl.value)),
  );
}

class _Star { double x, y, r, opacity; _Star(math.Random rng) : x = rng.nextDouble(), y = rng.nextDouble(), r = rng.nextDouble() * 1.5 + 0.3, opacity = rng.nextDouble() * 0.5 + 0.1; }

class _StarPainter extends CustomPainter {
  final List<_Star> stars; final double t;
  _StarPainter(this.stars, this.t);
  @override void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final o = (s.opacity + math.sin(t * 2 * math.pi + s.x * 10) * 0.1).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, Paint()..color = const Color(0xFFE8EEFF).withOpacity(o));
    }
  }
  @override bool shouldRepaint(_StarPainter old) => old.t != t;
}

class _Scanlines extends StatelessWidget {
  const _Scanlines();
  @override Widget build(BuildContext context) => CustomPaint(size: MediaQuery.of(context).size, painter: _ScanlinePainter());
}

class _ScanlinePainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF000000).withOpacity(0.03);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Field Widget ─────────────────────────────────────────────────────────────

class _AvatarField extends StatefulWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final Color accentColor;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const _AvatarField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.accentColor = _cyan,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
  });

  @override State<_AvatarField> createState() => _AvatarFieldState();
}

class _AvatarFieldState extends State<_AvatarField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final color = _focused ? widget.accentColor : _muted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _glass,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _focused ? widget.accentColor.withOpacity(0.6) : _rim, width: _focused ? 1.5 : 1),
            boxShadow: _focused ? [BoxShadow(color: widget.accentColor.withOpacity(0.1), blurRadius: 10)] : [],
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
                hintStyle: TextStyle(color: _muted.withOpacity(0.6), fontSize: 13),
                prefixIcon: Icon(widget.icon, color: color, size: 18),
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
