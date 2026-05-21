import 'package:flutter/material.dart';
import 'package:avatar_monitoring/screens/alertes/alertes_screen.dart';
import 'package:avatar_monitoring/screens/contacts/contacts_screen.dart';
import 'package:avatar_monitoring/screens/notifs/notification_service.dart';
import 'package:avatar_monitoring/screens/profil/profil_screen.dart';
import 'package:avatar_monitoring/services/supabase_service.dart';
import 'package:avatar_monitoring/services/api_service.dart';
import 'package:avatar_monitoring/pages/login_page.dart';
import 'package:avatar_monitoring/models/alerte_model.dart';
import 'package:avatar_monitoring/models/physio_data.dart';
import 'package:avatar_monitoring/models/predict_model.dart';
import 'package:avatar_monitoring/utils/risk_status.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:math' as math;

// ─── Palette ──────────────────────────────────────────────────────────────────
const _bg = Color(0xFF0A0D16);
const _card = Color(0xFF151C2E);
const _glass = Color(0xFF1A2440);
const _rim = Color(0xFF1F2D4A);
const _cyan = Color(0xFF00C8E8);
const _teal = Color(0xFF00E5A0);
const _violet = Color(0xFF7B68EE);
const _ember = Color(0xFFFF6B6B);
const _amber = Color(0xFFFFB347);
const _muted = Color(0xFF4A5880);
const _pale = Color(0xFF8A9BBF);
const _white = Color(0xFFE8EEFF);
const _green = Color(0xFF00E5A0);
const _orange = Color(0xFFFFB347);
const _red = Color(0xFFFF6B6B);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final _service = SupabaseService();
  final _api = ApiService();
  final _logger = Logger();

  PhysioData? physio;
  PredictResult? prediction;
  String? errorMessage;
  int? _userId;
  Timer? _pollingTimer;
  Timer? _braceletTimer;
  bool _isSyncing = false;

  late AnimationController _pulseCtrl;
  late AnimationController _ringCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _blinkCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _blinkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _loadUserId().then((_) {
      _loadInitialData();
      _startBraceletSync();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _braceletTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    _fadeCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    _userId = await _api.getUserId();
  }

  void _loadInitialData() async {
    _logger.d('loadInitialData started');
    await _syncBraceletWithAi(showError: true);
    if (physio == null && prediction == null) {
      try {
        physio = await _service.getLatestPhysio();
        prediction = await _service.getLatestPrediction();
        if (mounted) {
          setState(() => errorMessage = null);
          _fadeCtrl.forward(from: 0);
        }
      } catch (e) {
        _logger.e('loadInitialData error: $e');
        if (mounted) setState(() => errorMessage = e.toString());
      }
    }
  }

  /// Envoie une mesure au backend → modèle FCM → enregistrement BDD.
  Future<void> _syncBraceletWithAi({bool showError = false}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final result = await _service.syncBraceletWithAi();
      if (mounted) {
        setState(() {
          physio = result.physio;
          prediction = result.prediction;
          errorMessage = null;
        });
        _fadeCtrl.forward(from: 0);
      }
      await NotificationService().afficherSelonStatus(
        effectiveRiskStatus(physio: result.physio, prediction: result.prediction),
      );
      _showEmailFeedback(result.alerts);
      _logger.i('IA sync OK: ${result.prediction.status_predict}');
    } catch (e) {
      _logger.w('bracelet IA sync: $e');
      if (showError && mounted) setState(() => errorMessage = e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  void _startBraceletSync() {
    _braceletTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _syncBraceletWithAi();
    });
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final newPhysio = await _service.getLatestPhysio();
        final newPrediction = await _service.getLatestPrediction();
        if (mounted) {
          setState(() {
            if (newPhysio != null) physio = newPhysio;
            if (newPrediction != null &&
                (newPhysio == null || newPrediction.id_physio == newPhysio.id)) {
              prediction = newPrediction;
            }
            errorMessage = null;
          });
        }
      } catch (e) {
        _logger.w('polling error: $e');
      }
    });
  }

  void _showEmailFeedback(List<Alerte> alerts) {
    if (!mounted) return;

    if (alerts.isEmpty && _displayStatus == 'critical') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            'État CRITIQUE : ajoutez un contact « Très proche » avec une adresse email '
            '(menu Contacts), puis relancez « Analyser IA ».',
          ),
          duration: Duration(seconds: 7),
        ),
      );
      return;
    }

    final sent = alerts.where((a) => a.status == 'sent').length;
    final failed = alerts.where((a) => a.status == 'failed').length;

    String? msg;
    Color? color;
    if (sent > 0) {
      msg =
          'Email d\'alerte envoyé à $sent contact(s). Vérifiez la boîte de réception et les spams.';
      color = _teal;
    } else if (failed > 0) {
      final err = alerts.first.errorMessage ??
          'SMTP non configuré sur Render ou NOTIF_DRY_RUN=true';
      msg = 'Email non envoyé : $err';
      color = _ember;
    }
    if (msg == null || color == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: color.withOpacity(0.15),
        content: Text(msg, style: TextStyle(color: color, fontSize: 12)),
        duration: const Duration(seconds: 7),
      ),
    );
  }

  void _logout() async {
    await _api.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  String get _displayStatus => effectiveRiskStatus(physio: physio, prediction: prediction);

  Color _riskColor() {
    switch (_displayStatus) {
      case 'critical': return _red;
      case 'warning': return _orange;
      default: return _green;
    }
  }

  String _riskLabel() {
    switch (_displayStatus) {
      case 'critical': return 'CRITIQUE';
      case 'warning': return 'ATTENTION';
      default: return 'NORMAL';
    }
  }

  IconData _riskIcon() {
    switch (_displayStatus) {
      case 'critical': return Icons.emergency_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      default: return Icons.check_circle_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const _Starfield(),
          const _Scanlines(),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildStatusBanner(),
                        const SizedBox(height: 20),
                        _buildVitalGrid(),
                        const SizedBox(height: 20),
                        _buildLastUpdated(),
                        const SizedBox(height: 20),
                        _buildActionRow(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AVATAR OS', style: TextStyle(color: _cyan, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4)),
                Text('TABLEAU DE BORD', style: TextStyle(color: _muted, fontSize: 10, letterSpacing: 2)),
              ],
            ),
          ),
          // Profil button
          GestureDetector(
            onTap: () {
              if (_userId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilScreen(userId: _userId!)));
              }
            },
            child: Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _rim)),
              child: const Icon(Icons.person_outline_rounded, color: _pale, size: 20),
            ),
          ),
          // Alerts button
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertesScreen())),
            child: Container(
              width: 40, height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _rim)),
              child: const Icon(Icons.notifications_outlined, color: _pale, size: 20),
            ),
          ),
          // Logout
          GestureDetector(
            onTap: _logout,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _ember.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _ember.withOpacity(0.3))),
              child: const Icon(Icons.logout_rounded, color: _ember, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _ember.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: _ember.withOpacity(0.3))),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: _ember, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text('Connexion impossible\n$errorMessage', style: const TextStyle(color: _ember, fontSize: 12))),
            GestureDetector(onTap: _syncBraceletWithAi, child: const Icon(Icons.refresh_rounded, color: _ember, size: 18)),
          ],
        ),
      );
    }

    final riskColor = _riskColor();
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: _displayStatus == 'critical' ? _pulseAnim.value : 1.0, child: child),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: riskColor.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(color: riskColor.withOpacity(0.12), blurRadius: 20, spreadRadius: 2)],
        ),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: riskColor.withOpacity(0.12),
                border: Border.all(color: riskColor.withOpacity(0.4), width: 1.5),
              ),
              child: Icon(_riskIcon(), color: riskColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ÉTAT ACTUEL', style: TextStyle(fontSize: 9, color: _muted, letterSpacing: 2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_riskLabel(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: riskColor, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text('Surveillance active', style: TextStyle(fontSize: 11, color: _muted)),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _blinkCtrl,
              builder: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: riskColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: riskColor.withOpacity(0.4 + _blinkCtrl.value * 0.6),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('LIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: riskColor, letterSpacing: 1.5, fontFamily: 'monospace')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalGrid() {
    final hasData = physio != null;
    return Column(
      children: [
        _sectionHeader('PARAMÈTRES VITAUX'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _VitalCard(label: 'SpO₂', value: hasData ? '${physio!.spo2.toStringAsFixed(1)}%' : '--', unit: '%', icon: Icons.air_rounded, color: _cyan, nominal: '95–100')),
            const SizedBox(width: 10),
            Expanded(child: _VitalCard(label: 'Fréq. Cardiaque', value: hasData ? '${physio!.heartRate.toStringAsFixed(0)}' : '--', unit: 'BPM', icon: Icons.favorite_outline_rounded, color: _ember, nominal: '60–100')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _VitalCard(label: 'Fréq. Respiratoire', value: hasData ? '${physio!.respiratoryRate.toStringAsFixed(0)}' : '--', unit: 'RPM', icon: Icons.waves_rounded, color: _violet, nominal: '12–20')),
            const SizedBox(width: 10),
            Expanded(child: _VitalCard(label: 'Dernière mesure', value: hasData ? _formatTime(physio!.createdAt) : '--', unit: '', icon: Icons.access_time_rounded, color: _teal, nominal: '')),
          ],
        ),
      ],
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _rim)),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: _muted, size: 16),
          const SizedBox(width: 10),
          Text(
            _isSyncing
                ? 'Analyse IA en cours…'
                : 'Bracelet → IA toutes les 30s · affichage 5s',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _syncBraceletWithAi(showError: true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _cyan.withOpacity(0.3))),
              child: Text('Analyser IA', style: TextStyle(color: _cyan, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.notifications_active_rounded,
            label: 'ALERTES',
            color: _ember,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertesScreen())),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.person_outline_rounded,
            label: 'PROFIL',
            color: _violet,
            onTap: () {
              if (_userId != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilScreen(userId: _userId!)));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.contacts_outlined,
            label: 'CONTACTS',
            color: _teal,
            onTap: () {
              if (_userId != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ContactsScreen(userId: _userId!)));
            },
          ),
        ),
      ],
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }
}

// ─── Vital Card ───────────────────────────────────────────────────────────────

class _VitalCard extends StatelessWidget {
  final String label, value, unit, nominal;
  final IconData icon;
  final Color color;

  const _VitalCard({required this.label, required this.value, required this.unit, required this.icon, required this.color, required this.nominal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
              if (nominal.isNotEmpty)
                Text(nominal, style: TextStyle(fontSize: 9, color: _muted, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _white, fontFamily: 'monospace')),
          if (unit.isNotEmpty) Text(unit, style: TextStyle(fontSize: 11, color: _muted)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: _muted, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

// ─── Action Card ──────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Background ───────────────────────────────────────────────────────────────

class _Starfield extends StatefulWidget {
  const _Starfield();
  @override State<_Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<_Starfield> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final _rng = math.Random();
  late List<_Star> _stars;

  @override void initState() {
    super.initState();
    _stars = List.generate(55, (_) => _Star(_rng));
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => CustomPaint(size: MediaQuery.of(context).size, painter: _StarPainter(_stars, _ctrl.value)),
  );
}

class _Star { double x, y, r, o; _Star(math.Random rng) : x = rng.nextDouble(), y = rng.nextDouble(), r = rng.nextDouble() * 1.5 + 0.3, o = rng.nextDouble() * 0.5 + 0.1; }

class _StarPainter extends CustomPainter {
  final List<_Star> stars; final double t;
  _StarPainter(this.stars, this.t);
  @override void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final o = (s.o + math.sin(t * 2 * math.pi + s.x * 10) * 0.1).clamp(0.0, 1.0);
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
    for (double y = 0; y < size.height; y += 3) canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }
  @override bool shouldRepaint(_) => false;
}
