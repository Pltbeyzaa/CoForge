// lib/pages/profile_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api_config.dart';
const _kTokenKey = 'coforge_access_token';

// ---------------------------------------------------------------------------
// API Modeller
// ---------------------------------------------------------------------------

final class _ProfileData {
  const _ProfileData({
    required this.id,
    required this.email,
    required this.fullName,
    required this.bio,
    required this.githubUrl,
    required this.linkedinUrl,
  });

  final int id;
  final String email;
  final String fullName;
  final String bio;
  final String githubUrl;
  final String linkedinUrl;

  factory _ProfileData.fromJson(Map<String, dynamic> j) => _ProfileData(
        id: j['id'] as int? ?? 0,
        email: j['email'] as String? ?? '',
        fullName: j['full_name'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        githubUrl: j['github_url'] as String? ?? '',
        linkedinUrl: j['linkedin_url'] as String? ?? '',
      );
}

final class _UserSkill {
  const _UserSkill(
      {required this.id, required this.skillId, required this.skillName});

  final int id;
  final int skillId;
  final String skillName;

  factory _UserSkill.fromJson(Map<String, dynamic> j) {
    final skill = j['skill'] as Map<String, dynamic>? ?? {};
    return _UserSkill(
      id: j['id'] as int? ?? 0,
      skillId: skill['id'] as int? ?? 0,
      skillName: skill['name'] as String? ?? '',
    );
  }
}

final class _AvailableSkill {
  const _AvailableSkill({required this.id, required this.name});

  final int id;
  final String name;

  factory _AvailableSkill.fromJson(Map<String, dynamic> j) => _AvailableSkill(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// Mock veri sınıfları
// ---------------------------------------------------------------------------

class _MockPost {
  const _MockPost({
    required this.title,
    required this.description,
    required this.tags,
    this.isOpen = true,
  });

  final String title;
  final String description;
  final List<String> tags;
  final bool isOpen;
}

class _MockProject {
  const _MockProject({
    required this.name,
    required this.language,
    required this.languageColor,
    required this.repoLink,
  });

  final String name;
  final String language;
  final Color languageColor;
  final String repoLink;
}

// ---------------------------------------------------------------------------
// ProfilePage
// ---------------------------------------------------------------------------

final class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    this.refreshTrigger,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final ValueNotifier<int>? refreshTrigger;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

final class _ProfilePageState extends State<ProfilePage> {
  _ProfileData? _profile;
  List<_UserSkill> _userSkills = [];
  List<_AvailableSkill> _allSkills = [];
  List<_AvailableSkill> _filteredSkills = [];

  bool _loading = true;
  String? _error;
  bool _addingSkill = false;
  bool _importingGitHub = false;
  bool _saving = false;

  final _skillSearchCtrl = TextEditingController();

  final List<_MockPost> _posts = [
    const _MockPost(
      title: 'Flutter E-Ticaret Uygulaması',
      description:
          'iOS ve Android için modern pazar yeri uygulaması. Flutter veya React Native deneyimli geliştirici aranıyor.',
      tags: ['Flutter', 'Dart', 'Firebase'],
      isOpen: true,
    ),
    const _MockPost(
      title: 'AI Proje Eşleştirme Platformu',
      description:
          'NLP tabanlı geliştirici-proje eşleştirme sistemi. Python ve ML deneyimi gerekiyor.',
      tags: ['Python', 'Django', 'ML', 'NLP'],
      isOpen: false,
    ),
  ];

  final List<_MockProject> _projects = [
    const _MockProject(
      name: 'CoForge',
      language: 'Python',
      languageColor: Color(0xFF3776AB),
      repoLink: 'github.com/user/coforge',
    ),
    const _MockProject(
      name: 'pltbeyzaa',
      language: 'JavaScript',
      languageColor: Color(0xFFE8C219),
      repoLink: 'github.com/user/pltbeyzaa',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAll();
    _skillSearchCtrl.addListener(_onSearchChanged);
    widget.refreshTrigger?.addListener(_onRefreshTrigger);
  }

  void _onRefreshTrigger() => _loadAll();

  @override
  void dispose() {
    widget.refreshTrigger?.removeListener(_onRefreshTrigger);
    _skillSearchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _skillSearchCtrl.text.toLowerCase().trim();
    setState(() {
      _filteredSkills = q.isEmpty
          ? []
          : _allSkills
              .where((s) =>
                  s.name.toLowerCase().contains(q) &&
                  !_userSkills.any((us) => us.skillId == s.id))
              .take(6)
              .toList();
    });
  }

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kTokenKey);
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hdrs = await _headers();
      final results = await Future.wait([
        http
            .get(Uri.parse('$kBaseUrl/api/me/profile/'), headers: hdrs)
            .timeout(const Duration(seconds: 15)),
        http
            .get(Uri.parse('$kBaseUrl/api/me/skills/'), headers: hdrs)
            .timeout(const Duration(seconds: 15)),
        http
            .get(Uri.parse('$kBaseUrl/api/skills/'), headers: hdrs)
            .timeout(const Duration(seconds: 15)),
      ]);
      if (!mounted) return;
      if (results[0].statusCode == 200) {
        _profile = _ProfileData.fromJson(
            jsonDecode(results[0].body) as Map<String, dynamic>);
      }
      if (results[1].statusCode == 200) {
        final list = jsonDecode(results[1].body) as List;
        _userSkills = list
            .map((e) => _UserSkill.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (results[2].statusCode == 200) {
        final body = jsonDecode(results[2].body);
        final list = body is List ? body : (body['results'] ?? []) as List;
        _allSkills = list
            .map((e) => _AvailableSkill.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _addSkill(_AvailableSkill skill) async {
    setState(() => _addingSkill = true);
    try {
      final hdrs = await _headers();
      final res = await http
          .post(
            Uri.parse('$kBaseUrl/api/me/skills/'),
            headers: {...hdrs, 'Content-Type': 'application/json'},
            body: jsonEncode({'skill_id': skill.id}),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _skillSearchCtrl.clear();
        _filteredSkills = [];
        await _loadAll();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yetenek eklenemedi: ${res.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _addingSkill = false);
    }
  }

  Future<void> _deleteSkill(_UserSkill skill) async {
    try {
      final hdrs = await _headers();
      final res = await http
          .delete(
            Uri.parse('$kBaseUrl/api/me/skills/${skill.id}/'),
            headers: hdrs,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 204) await _loadAll();
    } catch (_) {}
  }

  Future<void> _openEditProfilePage() async {
    final result = await Navigator.of(context).push<_ProfileEditResult>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(
          initialGithub: _profile?.githubUrl ?? '',
          initialLinkedin: _profile?.linkedinUrl ?? '',
          initialBio: _profile?.bio ?? '',
        ),
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final hdrs = await _headers();
      final res = await http
          .patch(
            Uri.parse('$kBaseUrl/api/me/profile/'),
            headers: {...hdrs, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'bio': result.bio,
              'github_url': result.github.isEmpty ? null : result.github,
              'linkedin_url': result.linkedin.isEmpty ? null : result.linkedin,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _loadAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil güncellendi.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Güncelleme başarısız: ${res.body}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onGitHubTap() async {
    final url = _profile?.githubUrl ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Önce Profili Düzenle kısmından GitHub linkinizi ekleyin.'),
        ),
      );
      return;
    }
    await _launchLink(url);
  }

  Future<void> _onLinkedInTap() async {
    final url = _profile?.linkedinUrl ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Önce Profili Düzenle kısmından LinkedIn linkinizi ekleyin.'),
        ),
      );
      return;
    }
    await _launchLink(url);
  }

  Future<void> _launchLink(String raw) async {
    final normalized =
        raw.startsWith('http') ? raw : 'https://$raw';
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz URL formatı.')),
        );
      }
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: $normalized')),
        );
      }
    }
  }

  Future<void> _importGitHubProject() async {
    if (_importingGitHub) return;
    setState(() => _importingGitHub = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() {
      _projects.add(const _MockProject(
        name: 'beyzapolat017/FindUs',
        language: 'Dart',
        languageColor: Color(0xFF0175C2),
        repoLink: 'github.com/beyzapolat017/FindUs',
      ));
      _importingGitHub = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('FindUs - Vektörel Arama Motoru eklendi!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark;
    final displayBio = _profile?.bio ?? '';

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
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _error != null
              ? _ErrorBody(error: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  color: cs.primary,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHeaderCard(
                          profile: _profile,
                          githubUrl: _profile?.githubUrl ?? '',
                          linkedinUrl: _profile?.linkedinUrl ?? '',
                          saving: _saving,
                          onEditProfile: _openEditProfilePage,
                          onGitHub: _onGitHubTap,
                          onLinkedIn: _onLinkedInTap,
                        ),
                        const SizedBox(height: 16),
                        _BioSkillsCard(
                          profile: _profile,
                          displayBio: displayBio,
                          userSkills: _userSkills,
                          filteredSkills: _filteredSkills,
                          searchCtrl: _skillSearchCtrl,
                          addingSkill: _addingSkill,
                          onAdd: _addSkill,
                          onDelete: _deleteSkill,
                        ),
                        const SizedBox(height: 16),
                        _PostsSection(posts: _posts),
                        const SizedBox(height: 16),
                        _ProjectsSection(
                          projects: _projects,
                          isImporting: _importingGitHub,
                          onImport: _importGitHubProject,
                        ),
                        const SizedBox(height: 16),
                        _StatsSection(
                          postCount: _posts.length,
                          projectCount: _projects.length,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profili Düzenle — Tam Sayfa
// ---------------------------------------------------------------------------

class _ProfileEditResult {
  const _ProfileEditResult({
    required this.github,
    required this.linkedin,
    required this.bio,
  });
  final String github;
  final String linkedin;
  final String bio;
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    required this.initialGithub,
    required this.initialLinkedin,
    required this.initialBio,
  });

  final String initialGithub;
  final String initialLinkedin;
  final String initialBio;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _githubCtrl;
  late final TextEditingController _linkedinCtrl;
  late final TextEditingController _bioCtrl;

  @override
  void initState() {
    super.initState();
    _githubCtrl = TextEditingController(text: widget.initialGithub);
    _linkedinCtrl = TextEditingController(text: widget.initialLinkedin);
    _bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _githubCtrl.dispose();
    _linkedinCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      _ProfileEditResult(
        github: _githubCtrl.text.trim(),
        linkedin: _linkedinCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        leading: const BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _save,
              child: Text(
                'Kaydet',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel('GitHub Linki'),
            const SizedBox(height: 8),
            TextField(
              controller: _githubCtrl,
              decoration: InputDecoration(
                hintText: 'github.com/kullaniciadi',
                prefixIcon: const Icon(Icons.code, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            _FieldLabel('LinkedIn Linki'),
            const SizedBox(height: 8),
            TextField(
              controller: _linkedinCtrl,
              decoration: InputDecoration(
                hintText: 'linkedin.com/in/kullaniciadi',
                prefixIcon: const Icon(Icons.link, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            _FieldLabel('Biyografi'),
            const SizedBox(height: 8),
            TextField(
              controller: _bioCtrl,
              decoration: InputDecoration(
                hintText: 'Kendinizi kısaca tanıtın...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 4,
              maxLength: 200,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Kaydet',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hata durumu
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: cs.error),
            const SizedBox(height: 14),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profil Header Kartı
// ---------------------------------------------------------------------------

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.githubUrl,
    required this.linkedinUrl,
    required this.saving,
    required this.onEditProfile,
    required this.onGitHub,
    required this.onLinkedIn,
  });

  final _ProfileData? profile;
  final String githubUrl;
  final String linkedinUrl;
  final bool saving;
  final VoidCallback onEditProfile;
  final VoidCallback onGitHub;
  final VoidCallback onLinkedIn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Kullanıcı';
    final email = profile?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.42),
                  blurRadius: 32,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 46,
              backgroundColor: cs.primary,
              child: Text(
                initial,
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF238636).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: const Color(0xFF238636).withValues(alpha: 0.55)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: Color(0xFF3FB950)),
                    SizedBox(width: 4),
                    Text(
                      'GitHub Verified',
                      style: TextStyle(
                        color: Color(0xFF3FB950),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'CoForge Üyesi',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '⭐ 4.8 / 5.0  AI Güvenilirlik Skoru',
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: saving ? null : onEditProfile,
              icon: saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.edit_outlined, size: 16),
              label: Text(saving ? 'Kaydediliyor...' : 'Profili Düzenle'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SocialButton(
                icon: Icons.code,
                label: 'GitHub',
                hasLink: githubUrl.isNotEmpty,
                onTap: onGitHub,
              ),
              const SizedBox(width: 12),
              _SocialButton(
                icon: Icons.link,
                label: 'LinkedIn',
                hasLink: linkedinUrl.isNotEmpty,
                onTap: onLinkedIn,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.hasLink,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool hasLink;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = hasLink ? cs.primary : cs.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hasLink
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outline,
          ),
          color: hasLink
              ? cs.primary.withValues(alpha: 0.08)
              : cs.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: activeColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activeColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bio & Yetenekler Kartı
// ---------------------------------------------------------------------------

class _BioSkillsCard extends StatelessWidget {
  const _BioSkillsCard({
    required this.profile,
    required this.displayBio,
    required this.userSkills,
    required this.filteredSkills,
    required this.searchCtrl,
    required this.addingSkill,
    required this.onAdd,
    required this.onDelete,
  });

  final _ProfileData? profile;
  final String displayBio;
  final List<_UserSkill> userSkills;
  final List<_AvailableSkill> filteredSkills;
  final TextEditingController searchCtrl;
  final bool addingSkill;
  final void Function(_AvailableSkill) onAdd;
  final void Function(_UserSkill) onDelete;

  static const _chipColors = [
    Color(0xFF3776AB),
    Color(0xFF238636),
    Color(0xFF9945FF),
    Color(0xFFE34C26),
    Color(0xFF0175C2),
    Color(0xFF764ABC),
    Color(0xFFE8C219),
    Color(0xFFF05032),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Kullanıcı';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hi, I'm $name 👋",
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            displayBio.isNotEmpty
                ? displayBio
                : 'Yazılım geliştirici | CoForge ile proje ortakları buluyorum.',
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Languages & Tools',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Yetenek ara ve ekle...',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon: addingSkill
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.add_circle_outline, size: 20),
            ),
          ),
          if (filteredSkills.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                children: filteredSkills
                    .map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s.name,
                            style: TextStyle(color: cs.onSurface)),
                        trailing:
                            Icon(Icons.add, color: cs.primary, size: 20),
                        onTap: () => onAdd(s),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (userSkills.isEmpty)
            Text(
              'Henüz yetkinlik eklenmemiş. Yukarıdan yetkinliklerinizi ekleyin.',
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 13, height: 1.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: userSkills.asMap().entries.map((entry) {
                final color = _chipColors[entry.key % _chipColors.length];
                final us = entry.value;
                return GestureDetector(
                  onLongPress: () => onDelete(us),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          us.skillName,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onDelete(us),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: color.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// İlanlarım Bölümü  (dış Container kaldırıldı — transparan)
// ---------------------------------------------------------------------------

class _PostsSection extends StatelessWidget {
  const _PostsSection({required this.posts});
  final List<_MockPost> posts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'İlanlarım',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Yeni İlan'),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...posts.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(top: entry.key > 0 ? 10 : 0),
              child: _PostCard(post: entry.value),
            )),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final _MockPost post;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  post.title,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: post.isOpen
                      ? const Color(0xFF238636).withValues(alpha: 0.15)
                      : cs.error.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: post.isOpen
                        ? const Color(0xFF238636).withValues(alpha: 0.5)
                        : cs.error.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  post.isOpen ? 'OPEN' : 'CLOSED',
                  style: TextStyle(
                    color: post.isOpen ? const Color(0xFF3FB950) : cs.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            post.description,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 13,
              height: 1.45,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: post.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Projelerim Bölümü  (dış Container kaldırıldı — transparan)
// ---------------------------------------------------------------------------

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection({
    required this.projects,
    required this.isImporting,
    required this.onImport,
  });

  final List<_MockProject> projects;
  final bool isImporting;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Projelerim',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton.icon(
              onPressed: isImporting ? null : onImport,
              icon: isImporting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.code, size: 15),
              label: Text(
                  isImporting ? 'İçe Aktarılıyor...' : "GitHub'dan İçe Aktar"),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...projects.asMap().entries.map((entry) => Padding(
              padding: EdgeInsets.only(top: entry.key > 0 ? 10 : 0),
              child: _ProjectCard(project: entry.value),
            )),
      ],
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final _MockProject project;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  project.name,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'GitHub reposundan içe aktarıldı',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.link, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  project.repoLink,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: project.languageColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: project.languageColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: project.languageColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      project.language,
                      style: TextStyle(
                        color: project.languageColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CoForge Stats Bölümü  (dinamik)
// ---------------------------------------------------------------------------

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.postCount,
    required this.projectCount,
  });

  final int postCount;
  final int projectCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CoForge Stats',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _StatBox(
                label: 'Toplam\nİlanlar',
                value: postCount.toString(),
                icon: Icons.campaign_outlined,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Tamamlanan\nProjeler',
                value: projectCount.toString(),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 12),
              _StatBox(
                label: 'Güncel Seri\n(Streak)',
                value: '0 gün',
                icon: Icons.local_fire_department_outlined,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: 145,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(color: cs.outline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: cs.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
