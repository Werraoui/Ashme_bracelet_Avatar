import 'dart:math';
import 'package:flutter/material.dart';
import 'package:avatar_monitoring/pages/login_page.dart';
import 'package:avatar_monitoring/screens/contacts/contacts_screen.dart';
import 'package:avatar_monitoring/services/supabase_service.dart';
import 'package:avatar_monitoring/services/api_service.dart';
import 'package:avatar_monitoring/models/user_model.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class AvatarTheme {
  static const ink = Color(0xFF0A0D16);
  static const deep = Color(0xFF0F1420);
  static const card = Color(0xFF151C2E);
  static const glass = Color(0xFF1A2440);
  static const rim = Color(0xFF1F2D4A);
  static const cyan = Color(0xFF00C8E8);
  static const teal = Color(0xFF00E5A0);
  static const violet = Color(0xFF7B68EE);
  static const ember = Color(0xFFFF6B6B);
  static const muted = Color(0xFF4A5880);
  static const pale = Color(0xFF8A9BBF);
  static const white = Color(0xFFE8EEFF);
}

class ProfilScreen extends StatefulWidget {
  final int userId;
  const ProfilScreen({super.key, required this.userId});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> with TickerProviderStateMixin {
  final _service = SupabaseService();
  final _api = ApiService();
  UserModel? user;
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadUser();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _blinkCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _loadUser() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await _service.getUserById(widget.userId);
      setState(() {
        user = data;
        isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  String _genderLabel(String? gender) {
    switch (gender?.toLowerCase()) {
      case 'male': case 'homme': return '♂ Homme';
      case 'female': case 'femme': return '♀ Femme';
      default: return gender ?? 'Non renseigné';
    }
  }

  String get _initials {
    final f = (user?.first_name.isNotEmpty ?? false) ? user!.first_name[0] : '?';
    final l = (user?.last_name.isNotEmpty ?? false) ? user!.last_name[0] : '?';
    return '$f$l';
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AvatarTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AvatarTheme.ember.withOpacity(0.3))),
        title: const Text('Déconnexion', style: TextStyle(color: AvatarTheme.white)),
        content: const Text('Voulez-vous vraiment vous déconnecter ?', style: TextStyle(color: AvatarTheme.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler', style: TextStyle(color: AvatarTheme.muted))),
          TextButton(
            onPressed: () async {
              await _api.clearSession();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
            },
            child: const Text('Déconnecter', style: TextStyle(color: AvatarTheme.ember)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AvatarTheme.ink,
      body: Stack(
        children: [
          const _Starfield(),
          SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: AvatarTheme.cyan))
                : errorMessage != null
                    ? _buildError()
                    : user == null
                        ? const Center(child: Text('Profil introuvable', style: TextStyle(color: AvatarTheme.muted)))
                        : FadeTransition(opacity: _fadeAnim, child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AvatarTheme.ember, size: 48),
          const SizedBox(height: 16),
          Text(errorMessage ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AvatarTheme.ember, fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadUser,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: AvatarTheme.ember.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AvatarTheme.ember.withOpacity(0.4))),
              child: const Text('Réessayer', style: TextStyle(color: AvatarTheme.ember, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildBody() {
    return Column(
      children: [
        _buildNav(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(),
                const SizedBox(height: 20),
                _buildSectionHeader('INFORMATIONS PERSONNELLES'),
                const SizedBox(height: 10),
                _buildInfoGrid(),
                const SizedBox(height: 20),
                _buildSectionHeader('SUIVI MÉDICAL'),
                const SizedBox(height: 10),
                _buildMedCard(),
                const SizedBox(height: 20),
                _buildSectionHeader('CONTACTS D\'URGENCE'),
                const SizedBox(height: 10),
                _buildContactsCard(),
                const SizedBox(height: 20),
                _buildSectionHeader('SESSION'),
                const SizedBox(height: 10),
                _buildLogoutCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AvatarTheme.rim)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AvatarTheme.pale, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('PROFIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AvatarTheme.cyan, letterSpacing: 3)),
                Text('PATIENT · AVATAR OS', style: TextStyle(fontSize: 10, color: AvatarTheme.muted, letterSpacing: 1.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showLogoutDialog,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AvatarTheme.ember.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AvatarTheme.ember.withOpacity(0.4))),
              child: const Icon(Icons.logout_rounded, color: AvatarTheme.ember, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: AvatarTheme.rim)),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Transform.scale(
                  scale: 0.8 + _pulseCtrl.value * 0.3,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AvatarTheme.cyan.withOpacity(0.25 * _pulseCtrl.value), Colors.transparent]),
                    ),
                  ),
                ),
              ),
              RotationTransition(
                turns: Tween(begin: 0.0, end: -1.0).animate(_ringCtrl),
                child: SizedBox(width: 110, height: 110, child: CustomPaint(painter: _DashedCirclePainter(color: AvatarTheme.cyan.withOpacity(0.2)))),
              ),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0x330000C8E8), Color(0x337B68EE)],
                  ),
                  border: Border.all(color: AvatarTheme.cyan.withOpacity(0.5), width: 2),
                ),
                child: Center(
                  child: Text(_initials, style: const TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w700, color: AvatarTheme.cyan, letterSpacing: 2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('${user!.first_name} ${user!.last_name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AvatarTheme.white, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(user!.email, style: const TextStyle(fontSize: 12, color: AvatarTheme.muted, fontFamily: 'monospace')),
          const SizedBox(height: 16),
          _StatusPill(label: 'DOSSIER ACTIF', color: AvatarTheme.teal, blink: _blinkCtrl),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        Container(width: 4, height: 4, decoration: const BoxDecoration(shape: BoxShape.circle, color: AvatarTheme.cyan)),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AvatarTheme.muted, letterSpacing: 2.5)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 0.5, color: AvatarTheme.rim)),
      ],
    ),
  );

  Widget _buildInfoGrid() {
    final memberSince = '${user!.createdAt.day.toString().padLeft(2, '0')}/${user!.createdAt.month.toString().padLeft(2, '0')}/${user!.createdAt.year}';
    final days = DateTime.now().difference(user!.createdAt).inDays;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.person_outline_rounded, color: AvatarTheme.cyan, label: 'NOM', value: '${user!.first_name}\n${user!.last_name}')),
              const SizedBox(width: 10),
              Expanded(child: _InfoTile(icon: Icons.cake_outlined, color: AvatarTheme.violet, label: 'ÂGE', value: '${user!.age} ans')),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _InfoTile(icon: Icons.wc_rounded, color: AvatarTheme.teal, label: 'GENRE', value: _genderLabel(user!.gender))),
              const SizedBox(width: 10),
              Expanded(child: _InfoTile(icon: Icons.phone_outlined, color: AvatarTheme.ember, label: 'TÉLÉPHONE', value: user!.phone)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AvatarTheme.rim)),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: AvatarTheme.cyan, size: 18),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MEMBRE DEPUIS', style: TextStyle(fontSize: 9, color: AvatarTheme.muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
                  Text(memberSince, style: const TextStyle(color: AvatarTheme.white, fontSize: 14, fontFamily: 'monospace')),
                ]),
                const Spacer(),
                Text('$days jours', style: const TextStyle(color: AvatarTheme.cyan, fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: AvatarTheme.cyan.withOpacity(0.25))),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: AvatarTheme.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: AvatarTheme.cyan.withOpacity(0.3))),
              child: const Icon(Icons.medical_services_outlined, color: AvatarTheme.cyan, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MALADIE SUIVIE', style: TextStyle(fontSize: 10, color: AvatarTheme.muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  const Text('Asthme chronique', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AvatarTheme.white)),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: AvatarTheme.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: AvatarTheme.teal.withOpacity(0.25))),
                    child: const Text('ACTIF', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AvatarTheme.teal, letterSpacing: 1.5, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContactsScreen(userId: widget.userId)),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AvatarTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AvatarTheme.teal.withOpacity(0.25)),
          ),
          child: Row(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AvatarTheme.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AvatarTheme.teal.withOpacity(0.3)),
              ),
              child: const Icon(Icons.contacts_outlined,
                  color: AvatarTheme.teal, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CONTACTS D\'URGENCE',
                    style: TextStyle(
                        fontSize: 10,
                        color: AvatarTheme.muted,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 3),
                Text('Gérer mes contacts',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AvatarTheme.white)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AvatarTheme.muted),
          ]),
        ),
      ),
    );
  }

  Widget _buildLogoutCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _showLogoutDialog,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: AvatarTheme.ember.withOpacity(0.25))),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: AvatarTheme.ember.withOpacity(0.1), border: Border.all(color: AvatarTheme.ember.withOpacity(0.3))),
                child: const Icon(Icons.logout_rounded, color: AvatarTheme.ember, size: 20),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DÉCONNEXION', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AvatarTheme.ember, letterSpacing: 1)),
                  Text('Terminer la session en cours', style: TextStyle(fontSize: 11, color: AvatarTheme.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _InfoTile({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 9, color: AvatarTheme.muted, letterSpacing: 1, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 13, color: AvatarTheme.white, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final AnimationController blink;
  const _StatusPill({required this.label, required this.color, required this.blink});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: blink,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.4 + blink.value * 0.6))),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 1.5, fontFamily: 'monospace')),
          ],
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1;
    const count = 20;
    for (int i = 0; i < count; i++) {
      final start = 2 * pi * i / count;
      final end = start + 2 * pi / count - 0.05;
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
  final _rng = Random();
  late List<_Star> _stars;

  @override void initState() {
    super.initState();
    _stars = List.generate(40, (_) => _Star(_rng));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => CustomPaint(size: MediaQuery.of(context).size, painter: _StarPainter(_stars, _ctrl.value)),
  );
}

class _Star { double x, y, r, o; _Star(Random rng) : x = rng.nextDouble(), y = rng.nextDouble(), r = rng.nextDouble() * 1.2 + 0.3, o = rng.nextDouble() * 0.4 + 0.1; }

class _StarPainter extends CustomPainter {
  final List<_Star> stars; final double t;
  _StarPainter(this.stars, this.t);
  @override void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final o = (s.o + sin(t * 2 * pi + s.x * 10) * 0.1).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, Paint()..color = const Color(0xFFE8EEFF).withOpacity(o));
    }
  }
  @override bool shouldRepaint(_StarPainter old) => old.t != t;
}
