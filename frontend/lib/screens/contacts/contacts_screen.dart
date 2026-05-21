import 'package:flutter/material.dart';
import 'package:avatar_monitoring/services/api_service.dart';

// ── Palette (cohérente avec le reste de l'app) ────────────────────────────────
const _bg = Color(0xFF0A0D16);
const _card = Color(0xFF151C2E);
const _rim = Color(0xFF1F2D4A);
const _cyan = Color(0xFF00C8E8);
const _teal = Color(0xFF00E5A0);
const _violet = Color(0xFF7B68EE);
const _ember = Color(0xFFFF6B6B);
const _muted = Color(0xFF4A5880);
const _pale = Color(0xFF8A9BBF);
const _white = Color(0xFFE8EEFF);

// APRÈS (valeurs correctes selon le backend)
const _relationLabels = {
  'very close': 'Très proche',
  'close': 'Proche',
  'not that close': 'Pas très proche',
};

class ContactsScreen extends StatefulWidget {
  final int userId;
  const ContactsScreen({super.key, required this.userId});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getContacts(widget.userId);
      setState(() {
        _contacts = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete(int contactId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _ember.withOpacity(0.3)),
        ),
        title: const Text('Supprimer ce contact ?',
            style: TextStyle(color: _white, fontSize: 16)),
        content: const Text('Cette action est irréversible.',
            style: TextStyle(color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
                style: TextStyle(color: _ember, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteContact(contactId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _ember),
        );
      }
    }
  }

  void _showAddDialog({Map<String, dynamic>? existing}) {
    final isEdit = existing != null;
    final nameCtrl =
        TextEditingController(text: existing?['name_contact'] ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?['phone_contact'] ?? '');
    final emailCtrl =
        TextEditingController(text: existing?['email_contact'] ?? '');
    String relation = existing?['relation'] ?? 'very close';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: _cyan.withOpacity(0.3)),
          ),
          title: Text(
            isEdit ? 'Modifier le contact' : 'Ajouter un contact',
            style: const TextStyle(color: _white, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(nameCtrl, 'Nom complet *', Icons.person_outline_rounded),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'Téléphone *', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(
                emailCtrl,
                relation == 'very close'
                    ? 'Email * (alertes critiques)'
                    : 'Email (optionnel)',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              if (relation == 'very close')
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'En cas d\'alerte CRITIQUE, un email est envoyé à ce contact.',
                    style: TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: relation,
                dropdownColor: _card,
                decoration: InputDecoration(
                  labelText: 'Relation',
                  labelStyle: const TextStyle(color: _muted),
                  prefixIcon: const Icon(Icons.people_outline_rounded,
                      color: _muted, size: 18),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: _rim),
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _cyan),
                      borderRadius: BorderRadius.circular(10)),
                ),
                style: const TextStyle(color: _white),
                items: _relationLabels.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setDlg(() => relation = v ?? relation),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: _muted)),
            ),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty ||
                    phoneCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Nom et téléphone obligatoires'),
                    backgroundColor: _ember,
                  ));
                  return;
                }
                if (relation == 'very close' &&
                    emailCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                      'Email obligatoire pour un contact « Très proche » (alertes par mail)',
                    ),
                    backgroundColor: _ember,
                  ));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  if (isEdit) {
                    await _api.updateContact(
                      existing!['id_contact'] as int,
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      relation: relation,
                    );
                  } else {
                    await _api.createContact(
                      userId: widget.userId,
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      email: emailCtrl.text.trim().isEmpty
                          ? null
                          : emailCtrl.text.trim(),
                      relation: relation,
                    );
                  }
                  await _load();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Erreur : $e'),
                          backgroundColor: _ember),
                    );
                  }
                }
              },
              child: Text(
                isEdit ? 'Enregistrer' : 'Ajouter',
                style:
                    const TextStyle(color: _cyan, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(color: _white),
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _muted),
          prefixIcon: Icon(icon, color: _muted, size: 18),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _rim),
              borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _cyan),
              borderRadius: BorderRadius.circular(10)),
        ),
      );

  Color _relationColor(String? rel) {
    switch (rel) {
      case 'doctor':
        return _cyan;
      case 'caregiver':
        return _violet;
      case 'family member':
        return _teal;
      case 'friend':
        return _pale;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(children: [
          // ── Nav ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _rim)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: _pale, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CONTACTS',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _cyan,
                              letterSpacing: 3)),
                      Text('URGENCE · AVATAR OS',
                          style: TextStyle(
                              fontSize: 10, color: _muted, letterSpacing: 1.5)),
                    ]),
              ),
              GestureDetector(
                onTap: _load,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _rim)),
                  child:
                      const Icon(Icons.refresh_rounded, color: _pale, size: 20),
                ),
              ),
              GestureDetector(
                onTap: () => _showAddDialog(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _teal.withOpacity(0.4))),
                  child: const Icon(Icons.add_rounded, color: _teal, size: 22),
                ),
              ),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded,
                                color: _ember, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: _ember, fontSize: 13)),
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: _load,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _ember.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: _ember.withOpacity(0.4)),
                                ),
                                child: const Text('Réessayer',
                                    style: TextStyle(
                                        color: _ember,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _contacts.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.contacts_outlined,
                                    color: _muted, size: 56),
                                SizedBox(height: 14),
                                Text('Aucun contact d\'urgence',
                                    style: TextStyle(
                                        color: _white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 6),
                                Text('Appuyez sur + pour en ajouter un',
                                    style:
                                        TextStyle(color: _muted, fontSize: 12)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                            itemCount: _contacts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final c = _contacts[i];
                              final relColor = _relationColor(c['relation']);
                              final relLabel = _relationLabels[c['relation']] ??
                                  (c['relation'] ?? '');
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: relColor.withOpacity(0.25)),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: relColor.withOpacity(0.1),
                                      border: Border.all(
                                          color: relColor.withOpacity(0.4)),
                                    ),
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: relColor,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['name_contact'] ?? '',
                                            style: const TextStyle(
                                                color: _white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            const Icon(Icons.phone_outlined,
                                                color: _muted, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              c['phone_contact'] ?? '',
                                              style: const TextStyle(
                                                  color: _muted,
                                                  fontSize: 12,
                                                  fontFamily: 'monospace'),
                                            ),
                                          ]),
                                          if (c['email_contact'] != null &&
                                              c['email_contact']
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
                                              child: Row(children: [
                                                const Icon(Icons.email_outlined,
                                                    color: _muted, size: 12),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    c['email_contact'],
                                                    style: const TextStyle(
                                                        color: _muted,
                                                        fontSize: 11),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ]),
                                            ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: relColor.withOpacity(0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: relColor
                                                      .withOpacity(0.3)),
                                            ),
                                            child: Text(
                                              relLabel.toUpperCase(),
                                              style: TextStyle(
                                                  color: relColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1),
                                            ),
                                          ),
                                        ]),
                                  ),
                                  // ── Actions ─────────────────────────
                                  Column(children: [
                                    GestureDetector(
                                      onTap: () => _showAddDialog(existing: c),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        margin:
                                            const EdgeInsets.only(bottom: 6),
                                        decoration: BoxDecoration(
                                          color: _cyan.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: _cyan.withOpacity(0.25)),
                                        ),
                                        child: const Icon(Icons.edit_outlined,
                                            color: _cyan, size: 16),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _delete(c['id_contact'] as int),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: _ember.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: _ember.withOpacity(0.25)),
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: _ember,
                                            size: 16),
                                      ),
                                    ),
                                  ]),
                                ]),
                              );
                            },
                          ),
          ),
        ]),
      ),
    );
  }
}
