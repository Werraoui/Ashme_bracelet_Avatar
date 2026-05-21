import 'dart:math';
import 'package:flutter/material.dart';
import 'package:avatar_monitoring/models/alerte_model.dart';
import 'package:avatar_monitoring/services/supabase_service.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class AvatarTheme {
  static const ink = Color(0xFF0A0D16);
  static const card = Color(0xFF151C2E);
  static const glass = Color(0xFF1A2440);
  static const rim = Color(0xFF1F2D4A);
  static const cyan = Color(0xFF00C8E8);
  static const teal = Color(0xFF00E5A0);
  static const violet = Color(0xFF7B68EE);
  static const ember = Color(0xFFFF6B6B);
  static const amber = Color(0xFFFFB347);
  static const muted = Color(0xFF4A5880);
  static const pale = Color(0xFF8A9BBF);
  static const white = Color(0xFFE8EEFF);
}

// ── Screen ─────────────────────────────────────────────────────────────────────
class AlertesScreen extends StatefulWidget {
  const AlertesScreen({super.key});

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> with TickerProviderStateMixin {
  final _service = SupabaseService();
  List<Alerte> alertes = [];
  bool isLoading = true;
  String? errorMessage;

  late AnimationController _ringCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..repeat(reverse: true);
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadAlertes();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _loadAlertes() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final data = await _service.getAlertes();
      setState(() {
        alertes = data;
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

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical': return AvatarTheme.ember;
      case 'warning': return AvatarTheme.amber;
      case 'acknowledged': return AvatarTheme.teal;
      default: return AvatarTheme.muted;
    }
  }

  String _statusLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'critical': return 'CRITIQUE';
      case 'warning': return 'ATTENTION';
      case 'sent': return 'ENVOYÉ';
      case 'acknowledged': return 'ACQUITTÉ';
      case 'created': return 'CRÉÉ';
      case 'failed': return 'ÉCHEC';
      default: return status?.toUpperCase() ?? 'INCONNU';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AvatarTheme.ink,
      body: Stack(
        children: [
          const _Starfield(),
          SafeArea(
            child: Column(
              children: [
                _buildNav(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AvatarTheme.cyan))
                      : errorMessage != null
                          ? _buildError()
                          : alertes.isEmpty
                              ? _buildEmpty()
                              : FadeTransition(
                                  opacity: _fadeAnim,
                                  child: _buildList(),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                Text('ALERTES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AvatarTheme.cyan, letterSpacing: 3)),
                Text('HISTORIQUE · AVATAR OS', style: TextStyle(fontSize: 10, color: AvatarTheme.muted, letterSpacing: 1.5)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadAlertes,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AvatarTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AvatarTheme.rim)),
              child: const Icon(Icons.refresh_rounded, color: AvatarTheme.pale, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      itemCount: alertes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _AlertCard(alerte: alertes[i], statusColor: _statusColor, statusLabel: _statusLabel),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: AvatarTheme.card, shape: BoxShape.circle, border: Border.all(color: AvatarTheme.teal.withOpacity(0.3))),
            child: const Icon(Icons.check_circle_outline_rounded, color: AvatarTheme.teal, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Aucune alerte', style: TextStyle(color: AvatarTheme.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Tout va bien !', style: TextStyle(color: AvatarTheme.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
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
              onTap: _loadAlertes,
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
  }
}

// ── Alert Card ─────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final Alerte alerte;
  final Color Function(String?) statusColor;
  final String Function(String?) statusLabel;

  const _AlertCard({required this.alerte, required this.statusColor, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final riskStatus = alerte.statusPredict;
    final alertStatus = alerte.status;
    final color = statusColor(riskStatus ?? alertStatus);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AvatarTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.4))),
            child: Icon(
              riskStatus == 'critical' ? Icons.emergency_rounded : Icons.warning_amber_rounded,
              color: color, size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
                      child: Text(statusLabel(riskStatus ?? alertStatus), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                    if (alerte.stage != null) ...[
                      const SizedBox(width: 6),
                      Text('Étape ${alerte.stage}', style: const TextStyle(color: AvatarTheme.muted, fontSize: 10)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Alerte #${alerte.id} — Prédiction #${alerte.idPredict}',
                  style: const TextStyle(color: AvatarTheme.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(alerte.timeOfAlert),
                  style: const TextStyle(color: AvatarTheme.muted, fontSize: 11, fontFamily: 'monospace'),
                ),
                if (alerte.status == 'failed' && alerte.errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    alerte.errorMessage!,
                    style: const TextStyle(color: AvatarTheme.ember, fontSize: 10),
                  ),
                ],
                if (alerte.status == 'sent') ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Email envoyé — vérifiez aussi les spams',
                    style: TextStyle(color: AvatarTheme.teal, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

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
