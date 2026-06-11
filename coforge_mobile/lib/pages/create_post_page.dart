// lib/pages/create_post_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';
const _kTokenKey = 'coforge_access_token';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

final class _Skill {
  const _Skill({required this.id, required this.name});
  final int id;
  final String name;

  factory _Skill.fromJson(Map<String, dynamic> j) => _Skill(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// CreatePostPage
// ---------------------------------------------------------------------------

final class CreatePostPage extends StatefulWidget {
  const CreatePostPage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

final class _CreatePostPageState extends State<CreatePostPage> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _outputCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  String? _selectedCategory;
  String? _selectedExperience;
  String? _selectedWorkModel;
  _Skill? _selectedSkillToAdd;

  int _maxTeamSize = 3;
  List<_Skill> _allSkills = [];
  List<_Skill> _selectedSkills = [];
  bool _skillsLoading = true;
  bool _submitting = false;
  String _terminalPreview = '';

  static const _categories = [
    'Web Geliştirme',
    'Mobil Uygulama',
    'Yapay Zeka / ML',
    'Veri Bilimi',
    'DevOps / Cloud',
    'Oyun Geliştirme',
    'Diğer',
  ];

  static const _experienceLevels = [
    'Başlangıç',
    'Orta Seviye',
    'İleri Seviye',
    'Karma',
  ];

  static const _workModels = ['Uzaktan', 'Yüz Yüze', 'Hibrit'];

  @override
  void initState() {
    super.initState();
    _loadSkills();
    _updatePreview();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _outputCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final title =
        _titleCtrl.text.trim().isEmpty ? '[Proje Başlığı]' : _titleCtrl.text.trim();
    final category = _selectedCategory ?? '[Kategori]';
    final workModel = _selectedWorkModel ?? '[Belirtilmedi]';
    final duration =
        _durationCtrl.text.trim().isEmpty ? '[Belirtilmedi]' : _durationCtrl.text.trim();
    final skills = _selectedSkills.isEmpty
        ? '[Henüz eklenmedi]'
        : _selectedSkills.map((s) => s.name).join(', ');

    setState(() {
      _terminalPreview =
          '> CoForge İlan Önizleme\n'
          '> ───────────────────────────────\n'
          '  başlık     : $title\n'
          '  kategori   : $category\n'
          '  model      : $workModel\n'
          '  süre       : $duration\n'
          '  takım      : $_maxTeamSize kişi\n'
          '  yetkinlik  : $skills\n'
          '> Analiz için "NLP Analiz Et" butonuna basın.';
    });
  }

  Future<void> _loadSkills() async {
    if (mounted) setState(() => _skillsLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    try {
      final res = await http.get(
        Uri.parse('$kBaseUrl/api/skills/'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body is List ? body : (body['results'] ?? []) as List;
        _allSkills =
            list.map((e) => _Skill.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _skillsLoading = false);
  }

  void _addSelectedSkill() {
    if (_selectedSkillToAdd == null) return;
    if (_selectedSkills.any((s) => s.id == _selectedSkillToAdd!.id)) return;
    setState(() {
      _selectedSkills.add(_selectedSkillToAdd!);
      _selectedSkillToAdd = null;
    });
    _updatePreview();
  }

  void _removeSkill(_Skill skill) {
    setState(() => _selectedSkills.removeWhere((s) => s.id == skill.id));
    _updatePreview();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve açıklama zorunludur.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    try {
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/api/project-posts/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'title': title,
              'description': desc,
              'max_team_size': _maxTeamSize,
              'required_skills': _selectedSkills
                  .map((s) => {'skill_id': s.id, 'priority': 1})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İlan başarıyla oluşturuldu!'),
            backgroundColor: Color(0xFF1E472B),
          ),
        );
        _titleCtrl.clear();
        _descCtrl.clear();
        _outputCtrl.clear();
        setState(() {
          _selectedSkills = [];
          _selectedSkillToAdd = null;
          _maxTeamSize = 3;
        });
        _updatePreview();
      } else {
        final errBody = jsonDecode(res.body) as Map<String, dynamic>?;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${errBody?['detail'] ?? res.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Bağlantı hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  List<Widget> _buildTerminalLines() {
    final lines = _terminalPreview.split('\n');
    return lines.map((line) {
      if (line.startsWith('>')) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            line,
            style: const TextStyle(
              color: Color(0xFF7EE787),
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.7,
            ),
          ),
        );
      }
      final colonIdx = line.indexOf(':');
      if (colonIdx > 0) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: line.substring(0, colonIdx + 1),
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
                TextSpan(
                  text: line.substring(colonIdx + 1),
                  style: const TextStyle(
                    color: Color(0xFF58A6FF),
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Text(
          line,
          style: const TextStyle(
            color: Color(0xFF8B949E),
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.7,
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Co-Forge',
          style: TextStyle(
            color: cs.primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Açık tema' : 'Koyu tema',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sayfa Başlığı ──────────────────────────────────────────────
            Text(
              'Yeni İlan Oluştur',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Projenizi detaylıca tanıtın, yapay zeka destekli algoritma sizin için en uygun ekip üyelerini bulsun.',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),

            // ── GitHub İçe Aktar ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.code, size: 18, color: Colors.white),
                label: const Text(
                  "GitHub'dan İçe Aktar",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1117),
                  side: const BorderSide(color: Color(0xFF30363D)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Proje Başlığı ──────────────────────────────────────────────
            _FieldLabel(label: 'Proje Başlığı', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              onChanged: (_) => _updatePreview(),
              decoration: const InputDecoration(
                hintText: 'Örn: E-ticaret Mobil Uygulama',
              ),
            ),
            const SizedBox(height: 18),

            // ── Kategori + Deneyim (responsive row) ───────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth >= 480;
                final categoryField = _LabeledDropdown(
                  label: 'Proje Kategorisi',
                  hint: 'Kategori seçin',
                  value: _selectedCategory,
                  items: _categories,
                  onChanged: (v) {
                    setState(() => _selectedCategory = v);
                    _updatePreview();
                  },
                );
                final experienceField = _LabeledDropdown(
                  label: 'Deneyim Seviyesi',
                  hint: 'Seviye seçin',
                  value: _selectedExperience,
                  items: _experienceLevels,
                  onChanged: (v) => setState(() => _selectedExperience = v),
                );
                if (useRow) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: categoryField),
                      const SizedBox(width: 12),
                      Expanded(child: experienceField),
                    ],
                  );
                }
                return Column(
                  children: [
                    categoryField,
                    const SizedBox(height: 16),
                    experienceField,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // ── Çalışma Modeli + Tahmini Süre ─────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final useRow = constraints.maxWidth >= 480;
                final workModelField = _LabeledDropdown(
                  label: 'Çalışma Modeli',
                  hint: 'Model seçin',
                  value: _selectedWorkModel,
                  items: _workModels,
                  onChanged: (v) {
                    setState(() => _selectedWorkModel = v);
                    _updatePreview();
                  },
                );
                final durationField = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel(label: 'Tahmini Süre'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _durationCtrl,
                      onChanged: (_) => _updatePreview(),
                      decoration: const InputDecoration(hintText: 'Örn: 3 ay'),
                    ),
                  ],
                );
                if (useRow) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: workModelField),
                      const SizedBox(width: 12),
                      Expanded(child: durationField),
                    ],
                  );
                }
                return Column(
                  children: [
                    workModelField,
                    const SizedBox(height: 16),
                    durationField,
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // ── Maksimum Takım Boyutu ──────────────────────────────────────
            _FieldLabel(label: 'Maksimum Takım Boyutu'),
            const SizedBox(height: 8),
            _TeamSizeStepper(
              value: _maxTeamSize,
              onChanged: (v) {
                setState(() => _maxTeamSize = v);
                _updatePreview();
              },
            ),
            const SizedBox(height: 20),

            // ── Proje Açıklaması ───────────────────────────────────────────
            _FieldLabel(label: 'Proje Açıklaması', required: true),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                    'Projenizi detaylı açıklayın: hedefler, kullanılacak teknolojiler, ekip yapısı...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),

            // ── Beklenen Çıktılar ──────────────────────────────────────────
            _FieldLabel(label: 'Beklenen Çıktılar'),
            const SizedBox(height: 8),
            TextField(
              controller: _outputCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText:
                    'Proje tamamlandığında ortaya çıkacak ürün veya sonuçlar...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Gerekli Yetkinlikler ───────────────────────────────────────
            _FieldLabel(label: 'Gerekli Yetkinlikler'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _skillsLoading
                      ? Container(
                          height: 56,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outline),
                            color: cs.surface,
                          ),
                          child: Text(
                            'Yetkinlikler yükleniyor...',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : DropdownButtonFormField<_Skill>(
                          value: _selectedSkillToAdd,
                          hint: Text(
                            'Yetkinlik seçin',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                          ),
                          items: _allSkills
                              .where((s) => !_selectedSkills
                                  .any((sel) => sel.id == s.id))
                              .map(
                                (s) => DropdownMenuItem<_Skill>(
                                  value: s,
                                  child: Text(
                                    s.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (s) =>
                              setState(() => _selectedSkillToAdd = s),
                          isExpanded: true,
                        ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      _selectedSkillToAdd != null ? _addSelectedSkill : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                  ),
                  child: const Text('Ekle'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loadSkills,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 15),
                  ),
                  child: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            if (_selectedSkills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedSkills
                    .map(
                      (s) => Chip(
                        label: Text(s.name),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeSkill(s),
                        backgroundColor: cs.primary.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        side: BorderSide(
                            color: cs.primary.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),

            // ── İlan Önizleme (Terminal) ───────────────────────────────────
            _FieldLabel(label: 'İlan Önizleme'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      _TerminalDot(color: Color(0xFFFF5F56)),
                      SizedBox(width: 6),
                      _TerminalDot(color: Color(0xFFFFBD2E)),
                      SizedBox(width: 6),
                      _TerminalDot(color: Color(0xFF27C93F)),
                      SizedBox(width: 12),
                      Text(
                        'coforge-preview.sh',
                        style: TextStyle(
                          color: Color(0xFF8B949E),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ..._buildTerminalLines(),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Aksiyon Butonları ──────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _updatePreview,
                  child: const Text('Önizleme Güncelle'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('NLP analizi başlatılıyor...')),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('NLP Analiz Et'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF58A6FF),
                    side: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                ),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('İlanı Kaydet'),
                ),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt widget'lar
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: cs.onSurfaceVariant)),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          items: items
              .map(
                (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
          isExpanded: true,
        ),
      ],
    );
  }
}

class _TeamSizeStepper extends StatelessWidget {
  const _TeamSizeStepper({required this.value, required this.onChanged});
  final int value;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        color: cs.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            color: cs.primary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$value kişi',
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < 20 ? () => onChanged(value + 1) : null,
            color: cs.primary,
          ),
        ],
      ),
    );
  }
}

class _TerminalDot extends StatelessWidget {
  const _TerminalDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
