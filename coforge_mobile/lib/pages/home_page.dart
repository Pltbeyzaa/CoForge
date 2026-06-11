// lib/pages/home_page.dart
// Project Match Feed — /api/project-posts/

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

// main.dart ile aynı SharedPreferences anahtarı
const _kTokenKey = 'coforge_access_token';

// Status badge renkleri (her iki temada da sabit tutulur)
const _kStatusOpenBg = Color(0x471E472B);
const _kStatusOpenBorder = Color(0x8C1E472B);
const _kStatusOpenText = Color(0xFFEAF6EE);
const _kStatusClosedBg = Color(0xAA6E0512);

// ---------------------------------------------------------------------------
// Model — ProjectPostSerializer.to_representation çıktısı
// ---------------------------------------------------------------------------

final class RequiredSkill {
  const RequiredSkill({
    required this.skillId,
    required this.skillName,
    required this.priority,
  });

  final int skillId;
  final String skillName;
  final int priority;

  factory RequiredSkill.fromJson(Map<String, dynamic> j) => RequiredSkill(
        skillId: j['skill_id'] as int? ?? 0,
        skillName: j['skill_name'] as String? ?? '',
        priority: j['priority'] as int? ?? 1,
      );
}

final class ProjectPost {
  const ProjectPost({
    required this.id,
    required this.ownerEmail,
    required this.title,
    required this.description,
    required this.status,
    required this.maxTeamSize,
    required this.requiredSkills,
    required this.createdAt,
  });

  final int id;
  final String ownerEmail;
  final String title;
  final String description;
  final String status;
  final int maxTeamSize;
  final List<RequiredSkill> requiredSkills;
  final DateTime createdAt;

  bool get isOpen => status.toLowerCase() == 'open';

  factory ProjectPost.fromJson(Map<String, dynamic> j) {
    final rawSkills = j['required_skills_detail'] as List<dynamic>? ?? [];
    return ProjectPost(
      id: j['id'] as int? ?? 0,
      ownerEmail: j['owner_email'] as String? ?? '',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      status: j['status'] as String? ?? 'open',
      maxTeamSize: j['max_team_size'] as int? ?? 0,
      requiredSkills: rawSkills
          .map((e) => RequiredSkill.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// ---------------------------------------------------------------------------
// API katmanı
// ---------------------------------------------------------------------------

final class _FeedApi {
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  static Future<List<ProjectPost>> fetchPosts() async {
    final token = await _token();
    final res = await http
        .get(
          Uri.parse('$kBaseUrl/api/project-posts/'),
          headers: {
            'Accept': 'application/json',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = jsonDecode(res.body);
      final list = body is List ? body : (body['results'] ?? []) as List;
      return list
          .map((e) => ProjectPost.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('HTTP ${res.statusCode}: ${res.body}');
  }
}

// ---------------------------------------------------------------------------
// HomePage
// ---------------------------------------------------------------------------

final class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLogout,
    required this.onCreatePost,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onLogout;
  final VoidCallback onCreatePost;

  @override
  State<HomePage> createState() => _HomePageState();
}

final class _HomePageState extends State<HomePage> {
  List<ProjectPost> _posts = [];
  bool _loading = true;
  String? _error;
  String _meta = 'İlanlar yükleniyor...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _meta = 'İlanlar yükleniyor...';
    });
    try {
      final posts = await _FeedApi.fetchPosts();
      if (!mounted) return;
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _posts = posts;
        _loading = false;
        _meta = 'Toplam ${posts.length} ilan gösteriliyor.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _meta = 'İlan akışı yüklenemedi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
          IconButton(
            icon: Icon(Icons.logout, color: cs.error),
            tooltip: 'Çıkış Yap',
            onPressed: () async => widget.onLogout(),
          ),
          IconButton(
            icon: Icon(Icons.refresh_outlined, color: cs.onSurface),
            tooltip: 'Akışı Yenile',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _HeroStripSliver(
              onRefresh: _load,
              onCreatePost: widget.onCreatePost,
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Text(
                  _meta,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ),
            ),

            if (_loading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                    child: CircularProgressIndicator(color: cs.primary)),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(message: _error!, onRetry: _load),
              )
            else if (_posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Henüz ilan bulunmuyor.',
                    style: TextStyle(
                        color: cs.onSurfaceVariant, fontSize: 15),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 320,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => ProjectFeedCard(
                      post: _posts[i],
                      onTap: () {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                                'İlan #${_posts[i].id} — detay yakında'),
                            backgroundColor: cs.surface,
                          ),
                        );
                      },
                    ),
                    childCount: _posts.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero strip
// ---------------------------------------------------------------------------

final class _HeroStripSliver extends StatelessWidget {
  const _HeroStripSliver({
    required this.onRefresh,
    required this.onCreatePost,
  });

  final VoidCallback onRefresh;
  final VoidCallback onCreatePost;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: const Alignment(-0.5, 1.2),
              colors: [
                cs.primary.withValues(alpha: 0.14),
                cs.primary.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Match Feed',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Yazılım projeleri, ekip ihtiyaçları ve teknoloji stack bazlı ilan akışı.',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13.5,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: onCreatePost,
                    child: const Text('Yeni Proje İlanı'),
                  ),
                  OutlinedButton(
                    onPressed: onRefresh,
                    child: const Text('Akışı Yenile'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProjectFeedCard
// ---------------------------------------------------------------------------

final class ProjectFeedCard extends StatefulWidget {
  const ProjectFeedCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final ProjectPost post;
  final VoidCallback? onTap;

  @override
  State<ProjectFeedCard> createState() => _ProjectFeedCardState();
}

final class _ProjectFeedCardState extends State<ProjectFeedCard> {
  bool _isRequested = false;

  void _onMatchRequest() {
    if (_isRequested) return;
    setState(() => _isRequested = true);
    // Backend API çağrısı buraya bağlanabilir:
    // http.post(Uri.parse('$kBaseUrl/api/match-request/'), ...)
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final skills = widget.post.requiredSkills.take(4).toList();

    final shortDesc = widget.post.description.length > 80
        ? '${widget.post.description.substring(0, 80)}...'
        : widget.post.description;

    final ownerInitial = widget.post.ownerEmail.isNotEmpty
        ? widget.post.ownerEmail[0].toUpperCase()
        : 'U';

    return Card(
      color: cs.surface,
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outline),
      ),
      child: InkWell(
        onTap: widget.onTap,
        splashColor: cs.primary.withValues(alpha: 0.08),
        highlightColor: cs.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            children: [
              // Kart başlığı
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _AuthorAvatar(initial: ownerInitial),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.ownerEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                        Text(
                          'İlan Sahibi',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(isOpen: widget.post.isOpen),
                ],
              ),

              const SizedBox(height: 10),

              // Proje başlığı
              Text(
                widget.post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 7),

              // Meta chips
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _MetaChip(label: 'Takım: ${widget.post.maxTeamSize}'),
                  _MetaChip(
                      label: 'Yetenek: ${widget.post.requiredSkills.length}'),
                ],
              ),

              const SizedBox(height: 7),

              // Skill tag'leri
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: skills.isEmpty
                    ? const [_SkillTag(label: 'Belirtilmedi')]
                    : skills
                        .map((s) => _SkillTag(label: s.skillName))
                        .toList(),
              ),

              const SizedBox(height: 7),

              // Kısa açıklama
              Expanded(
                child: Text(
                  shortDesc.isEmpty ? 'Açıklama belirtilmemiş.' : shortDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Eşleşme İsteği butonu ─────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 36,
                child: FilledButton(
                  onPressed: _isRequested ? null : _onMatchRequest,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRequested
                        ? const Color(0xFF28a745)
                        : cs.primary,
                    disabledBackgroundColor: const Color(0xFF28a745),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isRequested
                            ? Icons.check_circle_outline
                            : Icons.send_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isRequested
                            ? 'Eşleşme İsteği Gönderildi'
                            : 'Eşleşme İsteği Gönder',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alt widget'lar
// ---------------------------------------------------------------------------

final class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// OPEN / CLOSED pill badge — status renklerini sabit tutar (her temada okunabilir)
final class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? _kStatusOpenBg : _kStatusClosedBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isOpen ? _kStatusOpenBorder : _kStatusClosedBg,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen
                  ? _kStatusOpenText
                  : Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'OPEN' : 'CLOSED',
            style: TextStyle(
              color: isOpen ? _kStatusOpenText : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

final class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.primary,
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.2,
        ),
      ),
    );
  }
}

final class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52, color: cs.error),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
            ),
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
