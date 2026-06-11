import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';
import 'pages/home_page.dart';
import 'pages/create_post_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart';
import 'pages/scrum_master_page.dart';

// -----------------------------------------------------------------------------
// Co-Forge mobil iskelet — tek dosya (sunum için)
// Backend: Django REST + JWT. Base URL: http://localhost:8000
// -----------------------------------------------------------------------------

const String _kAccessTokenKey = 'coforge_access_token';

// --- Modeller (final + JSON listelerinde .map) -------------------------------------------------

final class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
  });

  final int id;
  final String email;
  final String fullName;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }
}

final class LoginResponse {
  const LoginResponse({
    required this.access,
    required this.refresh,
    required this.user,
  });

  final String access;
  final String refresh;
  final AuthUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>? ?? {};
    return LoginResponse(
      access: json['access'] as String? ?? '',
      refresh: json['refresh'] as String? ?? '',
      user: AuthUser.fromJson(userMap),
    );
  }
}

final class ProjectMatch {
  const ProjectMatch({
    required this.projectId,
    required this.projectTitle,
    required this.similarityPercent,
    required this.semanticPercent,
    required this.requiredSkills,
    required this.commonSkills,
  });

  final int projectId;
  final String projectTitle;
  final int similarityPercent;
  final int semanticPercent;
  final List<String> requiredSkills;
  final List<String> commonSkills;

  factory ProjectMatch.fromJson(Map<String, dynamic> json) {
    final req = (json['required_skills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final common = (json['common_skills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    return ProjectMatch(
      projectId: json['project_id'] as int? ?? 0,
      projectTitle: json['project_title'] as String? ?? '',
      similarityPercent: _parseInt(json['similarity_percent']),
      semanticPercent: _parseInt(json['semantic_similarity_percent']),
      requiredSkills: req,
      commonSkills: common,
    );
  }

  static int _parseInt(Object? v) {
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

final class MatchSuggestionsResponse {
  const MatchSuggestionsResponse({
    required this.ok,
    required this.source,
    required this.matches,
    this.error,
  });

  final bool ok;
  final String source;
  final List<ProjectMatch> matches;
  final String? error;

  factory MatchSuggestionsResponse.fromJson(Map<String, dynamic> json) {
    final rawMatches = json['matches'] as List<dynamic>? ?? <dynamic>[];
    final parsed = rawMatches
        .map((e) => ProjectMatch.fromJson(e as Map<String, dynamic>))
        .toList();
    return MatchSuggestionsResponse(
      ok: json['ok'] as bool? ?? false,
      source: json['source'] as String? ?? '',
      matches: parsed,
      error: json['error'] as String?,
    );
  }
}

// --- API servisi -------------------------------------------------------------------------------

final class ApiService {
  ApiService({String? baseUrl})
      : baseUrl = (baseUrl ?? kBaseUrl).replaceAll(RegExp(r'/+$'), '');

  final String baseUrl;

  Uri _uri(String path) {
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$p');
  }

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final resp = await http.post(
      _uri('/api/auth/login/'),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      // KRİTİK DÜZELTME BURASI: Backend'in beklediği gibi 'email' yaptık ve trim ekledik.
      body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
    );
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return LoginResponse.fromJson(map);
    }
    final detail = map['detail']?.toString() ?? resp.body;
    throw ApiException(resp.statusCode, detail);
  }

  Future<MatchSuggestionsResponse> fetchMatchSuggestions(String accessToken) async {
    final resp = await http.get(
      _uri('/api/me/match-suggestions/'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    final map = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return MatchSuggestionsResponse.fromJson(map);
    }
    final detail = map['detail']?.toString() ?? resp.body;
    throw ApiException(resp.statusCode, detail);
  }

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessTokenKey, token);
  }

  static Future<String?> readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessTokenKey);
  }

  static Future<void> clearAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessTokenKey);
  }
}

final class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}

// --- Tema (web/css/style.css :root birebir) ----------------------------------------------------

const Color _kColorBg = Color(0xFF141A36);
const Color _kColorAccent = Color(0xFFFCFF70);
const Color _kColorSuccess = Color(0xFF1E472B);
const Color _kColorDanger = Color(0xFF6E0512);
const Color _kBodyText = Color(0xFFD1D0E3);
const Color _kOnAccent = Color(0xFF141A36);

ThemeData buildCoForgeDarkTheme() {
  const colorScheme = ColorScheme.dark(
    primary: _kColorAccent,
    onPrimary: _kOnAccent,
    surface: Color(0x17FFFFFF),
    onSurface: Color(0xFFF2F4FF),
    onSurfaceVariant: Color(0xFF9EA5BD),
    error: _kColorDanger,
    outline: Color(0x1FFFFFFF),
    outlineVariant: Color(0xFF3D4454),
  );

  return _buildCoForgeTheme(
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBg: _kColorBg,
    bodyText: _kBodyText,
    ui: _CoForgeUiColors(
      heroGradientStart: const Color(0x247C5CFF),
      heroGradientEnd: Color(0x1A38BDF8),
      heroBorder: Color(0x1FFFFFFF),
      heroSubtitle: Color(0xFFC5CBE3),
      cardBg: Color(0x17FFFFFF),
      cardBorder: Color(0x1AFFFFFF),
      cardShadow: Color(0x52000000),
      cardHoverBorder: Color(0x80FCFF70),
      spot1: Color(0x24FCFF70),
      spot2: Color(0x14FCFF70),
      spot3: Color(0x0AFFFFFF),
      cardRing: Color(0x3DFCFF70),
      spotInnerBorder: Color(0x14FFFFFF),
      authorName: Color(0xFFDFE4F7),
      authorRole: Color(0xFF99A1BB),
      jobTitle: Color(0xFFF2F4FF),
      jobDesc: Color(0xFFBDC4DD),
      metaChipText: Color(0xFFCFD5EC),
      metaChipBg: Color(0x0AFFFFFF),
      metaChipBorder: Color(0x2EFFFFFF),
      tagText: Color(0xFFCFCEFF),
      tagBg: Color(0x1FFCFF70),
      tagBorder: Color(0x61FCFF70),
      statusBg: Color.alphaBlend(_kColorSuccess.withValues(alpha: 0.28), Colors.transparent),
      statusBorder: Color.alphaBlend(_kColorSuccess.withValues(alpha: 0.55), const Color(0xFFFFFFFF)),
      statusText: Color(0xFFEAF6EE),
      pulseDot: Color(0x8C1E472B),
      ghostText: _kBodyText,
      ghostBorder: Color(0x38FFFFFF),
      ghostHoverBg: Color(0x14FFFFFF),
      avatarStart: Color(0xFF7C5CFF),
      avatarEnd: Color(0xFF4A9CF5),
      feedMeta: Color(0xFF9EA5BD),
    ),
  );
}

ThemeData buildCoForgeLightTheme() {
  const colorScheme = ColorScheme.light(
    primary: Color(0xFF9B1C1C),   // bordo/dark-red — web light mode ile eşleşir
    onPrimary: Colors.white,
    surface: Colors.white,        // kartlar saf beyaz
    onSurface: Color(0xFF111827), // ana metinler çok koyu
    onSurfaceVariant: Color(0xFF4B5563), // ikincil metinler koyu gri
    error: _kColorDanger,
    outline: Color(0xFFD1D5DB),   // görünür açık gri kenarlık
    outlineVariant: Color(0xFFE5E7EB),
  );

  return _buildCoForgeTheme(
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBg: const Color(0xFFF3F4F6), // temiz açık gri (lavender kaldırıldı)
    bodyText: const Color(0xFF111827),
    ui: _CoForgeUiColors(
      heroGradientStart: const Color(0x1A9B1C1C),
      heroGradientEnd: const Color(0x0AFFFFFF),
      heroBorder: const Color(0xFFE5E7EB),
      heroSubtitle: const Color(0xFF4B5563),
      cardBg: Colors.white,
      cardBorder: const Color(0xFFE5E7EB),
      cardShadow: const Color(0x14000000),
      cardHoverBorder: const Color(0x859B1C1C),
      spot1: const Color(0x8CFFFFFF),
      spot2: const Color(0x1F9B1C1C),
      spot3: const Color(0x59FFFFFF),
      cardRing: const Color(0x3D9B1C1C),
      spotInnerBorder: const Color(0xFFE5E7EB),
      authorName: const Color(0xFF111827),
      authorRole: const Color(0xFF4B5563),
      jobTitle: const Color(0xFF111827),
      jobDesc: const Color(0xFF374151),
      metaChipText: const Color(0xFF374151),
      metaChipBg: const Color(0x0F111827),
      metaChipBorder: const Color(0xFFE5E7EB),
      tagText: const Color(0xFF374151),
      tagBg: const Color(0xFFF3F4F6),
      tagBorder: const Color(0xFFD1D5DB),
      statusBg: Color.alphaBlend(_kColorSuccess.withValues(alpha: 0.18), Colors.white),
      statusBorder: _kColorSuccess.withValues(alpha: 0.45),
      statusText: const Color(0xFF0F2918),
      pulseDot: Color.alphaBlend(_kColorSuccess.withValues(alpha: 0.55), const Color(0xFFA7F3D0)),
      ghostText: const Color(0xFF374151),
      ghostBorder: const Color(0xFFD1D5DB),
      ghostHoverBg: const Color(0x0A000000),
      avatarStart: const Color(0xFF9B1C1C),
      avatarEnd: const Color(0xFFB91C1C),
      feedMeta: const Color(0xFF4B5563),
    ),
  );
}

ThemeData _buildCoForgeTheme({
  required Brightness brightness,
  required ColorScheme colorScheme,
  required Color scaffoldBg,
  required Color bodyText,
  required _CoForgeUiColors ui,
}) {
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldBg,
    canvasColor: scaffoldBg,
    cardColor: ui.cardBg,
    primaryColor: colorScheme.primary,
    fontFamily: 'Segoe UI',
    extensions: <ThemeExtension<dynamic>>[ui],
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: bodyText),
      bodyMedium: TextStyle(color: bodyText),
      titleLarge: TextStyle(color: bodyText),
      titleMedium: TextStyle(color: bodyText),
      headlineSmall: TextStyle(color: bodyText),
      headlineMedium: TextStyle(color: bodyText),
    ).apply(
      bodyColor: bodyText,
      displayColor: bodyText,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: ui.cardBg,
      foregroundColor: bodyText,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: ui.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: ui.cardBg,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.38),
        disabledForegroundColor: colorScheme.onPrimary.withValues(alpha: 0.54),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ui.ghostText,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: ui.ghostBorder),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.2),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ui.cardBg,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
  );
}

final class _CoForgeUiColors extends ThemeExtension<_CoForgeUiColors> {
  const _CoForgeUiColors({
    required this.heroGradientStart,
    required this.heroGradientEnd,
    required this.heroBorder,
    required this.heroSubtitle,
    required this.cardBg,
    required this.cardBorder,
    required this.cardShadow,
    required this.cardHoverBorder,
    required this.spot1,
    required this.spot2,
    required this.spot3,
    required this.cardRing,
    required this.spotInnerBorder,
    required this.authorName,
    required this.authorRole,
    required this.jobTitle,
    required this.jobDesc,
    required this.metaChipText,
    required this.metaChipBg,
    required this.metaChipBorder,
    required this.tagText,
    required this.tagBg,
    required this.tagBorder,
    required this.statusBg,
    required this.statusBorder,
    required this.statusText,
    required this.pulseDot,
    required this.ghostText,
    required this.ghostBorder,
    required this.ghostHoverBg,
    required this.avatarStart,
    required this.avatarEnd,
    required this.feedMeta,
  });

  final Color heroGradientStart;
  final Color heroGradientEnd;
  final Color heroBorder;
  final Color heroSubtitle;
  final Color cardBg;
  final Color cardBorder;
  final Color cardShadow;
  final Color cardHoverBorder;
  final Color spot1;
  final Color spot2;
  final Color spot3;
  final Color cardRing;
  final Color spotInnerBorder;
  final Color authorName;
  final Color authorRole;
  final Color jobTitle;
  final Color jobDesc;
  final Color metaChipText;
  final Color metaChipBg;
  final Color metaChipBorder;
  final Color tagText;
  final Color tagBg;
  final Color tagBorder;
  final Color statusBg;
  final Color statusBorder;
  final Color statusText;
  final Color pulseDot;
  final Color ghostText;
  final Color ghostBorder;
  final Color ghostHoverBg;
  final Color avatarStart;
  final Color avatarEnd;
  final Color feedMeta;

  @override
  _CoForgeUiColors copyWith({
    Color? heroGradientStart,
    Color? heroGradientEnd,
    Color? heroBorder,
    Color? heroSubtitle,
    Color? cardBg,
    Color? cardBorder,
    Color? cardShadow,
    Color? cardHoverBorder,
    Color? spot1,
    Color? spot2,
    Color? spot3,
    Color? cardRing,
    Color? spotInnerBorder,
    Color? authorName,
    Color? authorRole,
    Color? jobTitle,
    Color? jobDesc,
    Color? metaChipText,
    Color? metaChipBg,
    Color? metaChipBorder,
    Color? tagText,
    Color? tagBg,
    Color? tagBorder,
    Color? statusBg,
    Color? statusBorder,
    Color? statusText,
    Color? pulseDot,
    Color? ghostText,
    Color? ghostBorder,
    Color? ghostHoverBg,
    Color? avatarStart,
    Color? avatarEnd,
    Color? feedMeta,
  }) {
    return _CoForgeUiColors(
      heroGradientStart: heroGradientStart ?? this.heroGradientStart,
      heroGradientEnd: heroGradientEnd ?? this.heroGradientEnd,
      heroBorder: heroBorder ?? this.heroBorder,
      heroSubtitle: heroSubtitle ?? this.heroSubtitle,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      cardHoverBorder: cardHoverBorder ?? this.cardHoverBorder,
      spot1: spot1 ?? this.spot1,
      spot2: spot2 ?? this.spot2,
      spot3: spot3 ?? this.spot3,
      cardRing: cardRing ?? this.cardRing,
      spotInnerBorder: spotInnerBorder ?? this.spotInnerBorder,
      authorName: authorName ?? this.authorName,
      authorRole: authorRole ?? this.authorRole,
      jobTitle: jobTitle ?? this.jobTitle,
      jobDesc: jobDesc ?? this.jobDesc,
      metaChipText: metaChipText ?? this.metaChipText,
      metaChipBg: metaChipBg ?? this.metaChipBg,
      metaChipBorder: metaChipBorder ?? this.metaChipBorder,
      tagText: tagText ?? this.tagText,
      tagBg: tagBg ?? this.tagBg,
      tagBorder: tagBorder ?? this.tagBorder,
      statusBg: statusBg ?? this.statusBg,
      statusBorder: statusBorder ?? this.statusBorder,
      statusText: statusText ?? this.statusText,
      pulseDot: pulseDot ?? this.pulseDot,
      ghostText: ghostText ?? this.ghostText,
      ghostBorder: ghostBorder ?? this.ghostBorder,
      ghostHoverBg: ghostHoverBg ?? this.ghostHoverBg,
      avatarStart: avatarStart ?? this.avatarStart,
      avatarEnd: avatarEnd ?? this.avatarEnd,
      feedMeta: feedMeta ?? this.feedMeta,
    );
  }

  @override
  _CoForgeUiColors lerp(ThemeExtension<_CoForgeUiColors>? other, double t) {
    if (other is! _CoForgeUiColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return _CoForgeUiColors(
      heroGradientStart: l(heroGradientStart, other.heroGradientStart),
      heroGradientEnd: l(heroGradientEnd, other.heroGradientEnd),
      heroBorder: l(heroBorder, other.heroBorder),
      heroSubtitle: l(heroSubtitle, other.heroSubtitle),
      cardBg: l(cardBg, other.cardBg),
      cardBorder: l(cardBorder, other.cardBorder),
      cardShadow: l(cardShadow, other.cardShadow),
      cardHoverBorder: l(cardHoverBorder, other.cardHoverBorder),
      spot1: l(spot1, other.spot1),
      spot2: l(spot2, other.spot2),
      spot3: l(spot3, other.spot3),
      cardRing: l(cardRing, other.cardRing),
      spotInnerBorder: l(spotInnerBorder, other.spotInnerBorder),
      authorName: l(authorName, other.authorName),
      authorRole: l(authorRole, other.authorRole),
      jobTitle: l(jobTitle, other.jobTitle),
      jobDesc: l(jobDesc, other.jobDesc),
      metaChipText: l(metaChipText, other.metaChipText),
      metaChipBg: l(metaChipBg, other.metaChipBg),
      metaChipBorder: l(metaChipBorder, other.metaChipBorder),
      tagText: l(tagText, other.tagText),
      tagBg: l(tagBg, other.tagBg),
      tagBorder: l(tagBorder, other.tagBorder),
      statusBg: l(statusBg, other.statusBg),
      statusBorder: l(statusBorder, other.statusBorder),
      statusText: l(statusText, other.statusText),
      pulseDot: l(pulseDot, other.pulseDot),
      ghostText: l(ghostText, other.ghostText),
      ghostBorder: l(ghostBorder, other.ghostBorder),
      ghostHoverBg: l(ghostHoverBg, other.ghostHoverBg),
      avatarStart: l(avatarStart, other.avatarStart),
      avatarEnd: l(avatarEnd, other.avatarEnd),
      feedMeta: l(feedMeta, other.feedMeta),
    );
  }
}

_CoForgeUiColors _ui(BuildContext context) =>
    Theme.of(context).extension<_CoForgeUiColors>()!;

// --- Uygulama kökü -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoForgeApp());
}

final class CoForgeApp extends StatefulWidget {
  const CoForgeApp({super.key});

  @override
  State<CoForgeApp> createState() => _CoForgeAppState();
}

final class _CoForgeAppState extends State<CoForgeApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Co-Forge',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: buildCoForgeLightTheme(),
      darkTheme: buildCoForgeDarkTheme(),
      home: _AuthGate(
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

final class _AuthGate extends StatefulWidget {
  const _AuthGate({
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

final class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }
  Future<void> _load() async {
    final t = await ApiService.readAccessToken();
    if (!mounted) return;
    setState(() {
      _token = t;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }
    if ((_token ?? '').isEmpty) {
      return LoginScreen(
        onLoggedIn: (token) {
          setState(() => _token = token);
        },
      );
    }
    return _MainShell(
      accessToken: _token!,
      themeMode: widget.themeMode,
      onToggleTheme: widget.onToggleTheme,
      onLogout: () async {
        await ApiService.clearAccessToken();
        if (mounted) setState(() => _token = null);
      },
    );
  }
}

/// Giriş sonrası: alt menü + sekmeler (yalnızca Ana Sayfa eşleşme listesini gösterir).
final class _MainShell extends StatefulWidget {
  const _MainShell({
    required this.accessToken,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final String accessToken;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onLogout;

  @override
  State<_MainShell> createState() => _MainShellState();
}

final class _MainShellState extends State<_MainShell> {
  int _navIndex = 0;
  final _profileRefreshTrigger = ValueNotifier<int>(0);

  @override
  void dispose() {
    _profileRefreshTrigger.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    setState(() => _navIndex = i);
    if (i == 4) _profileRefreshTrigger.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _navIndex,
        children: [
          // 0 — Ana Sayfa: tüm proje ilanları (/api/project-posts/)
          HomePage(
            themeMode: widget.themeMode,
            onToggleTheme: widget.onToggleTheme,
            onLogout: widget.onLogout,
            onCreatePost: () => setState(() => _navIndex = 2),
          ),
          // 1 — Eşleşen İlanlar: AI destekli kişisel öneriler (/api/me/match-suggestions/)
          MatchmakingScreen(
            accessToken: widget.accessToken,
            themeMode: widget.themeMode,
            onToggleTheme: widget.onToggleTheme,
            onLogout: widget.onLogout,
          ),
          // 2 — İlan Oluştur
          CreatePostPage(
            themeMode: widget.themeMode,
            onToggleTheme: widget.onToggleTheme,
          ),
          // 3 — AI Scrum Master
          const ScrumMasterPage(),
          // 4 — Profil
          ProfilePage(
            themeMode: widget.themeMode,
            onToggleTheme: widget.onToggleTheme,
            refreshTrigger: _profileRefreshTrigger,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'Eşleşmeler',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'İlan Oluştur',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy_outlined),
            activeIcon: Icon(Icons.smart_toy),
            label: 'AI Scrum',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

// --- Login ekranı -------------------------------------------------------------------------------

final class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn});

  final void Function(String accessToken) onLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiService();
  bool _busy = false;

  late final AnimationController _splashCtrl;
  late final Animation<double> _splashFade;
  bool _splashActive = false;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 500),
    );
    _splashFade = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _splashCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final res = await _api.login(
        email: _email.text,
        password: _password.text,
      );
      await ApiService.saveAccessToken(res.access);
      if (!mounted) return;
      await _showSplashThenNavigate(res.access);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red.shade900),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bağlantı hatası: $e'), backgroundColor: Colors.red.shade900),
      );
    }
  }

  Future<void> _showSplashThenNavigate(String token) async {
    setState(() => _splashActive = true);
    await _splashCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    await _splashCtrl.reverse();
    if (!mounted) return;
    widget.onLoggedIn(token);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_mosaic, size: 72, color: cs.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Co-Forge',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Giriş yaparak eşleşme önerilerinizi görün',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 40),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _busy ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const RegisterPage()),
                      ),
                      child: Text(
                        'Hesabın yok mu? Kayıt Ol',
                        style: TextStyle(color: cs.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_splashActive)
          Positioned.fill(
            child: FadeTransition(
              opacity: _splashFade,
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_mosaic, size: 96, color: cs.primary),
                        const SizedBox(height: 28),
                        Text(
                          'Co-Forge',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                                letterSpacing: 2.5,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Fikirleri koda, kodları geleceğe\ndönüştürecek doğru ekibi kur.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 16,
                            height: 1.65,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 56),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: cs.primary.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// --- Project Match Feed (web/index.html + style.css birebir) -----------------------------------

Widget _metaChip(BuildContext context, String label) {
  final ui = _ui(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7.7, vertical: 3.2),
    decoration: BoxDecoration(
      color: ui.metaChipBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ui.metaChipBorder),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: ui.metaChipText,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    ),
  );
}

Widget _skillTag(BuildContext context, String label) {
  final ui = _ui(context);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6.4, vertical: 2.9),
    decoration: BoxDecoration(
      color: ui.tagBg,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: ui.tagBorder),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: ui.tagText,
        fontFamily: 'monospace',
        fontSize: 11.5,
        height: 1.2,
      ),
    ),
  );
}

Widget _projectStatusBadge(BuildContext context, {required bool closed}) {
  final ui = _ui(context);
  if (closed) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9.3),
      decoration: BoxDecoration(
        color: _kColorDanger.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kColorDanger.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5.4),
          const Text(
            'CLOSED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    height: 26,
    padding: const EdgeInsets.symmetric(horizontal: 9.3),
    decoration: BoxDecoration(
      color: ui.statusBg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: ui.statusBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ui.pulseDot,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ui.pulseDot.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5.4),
        Text(
          'OPEN',
          style: TextStyle(
            color: ui.statusText,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
      ],
    ),
  );
}

Widget _authorAvatar(BuildContext context, {required String initial}) {
  final ui = _ui(context);
  return Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [ui.avatarStart, ui.avatarEnd],
      ),
    ),
    child: Text(
      initial,
      style: const TextStyle(
        color: _kOnAccent,
        fontSize: 14.1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

final class ProjectCard extends StatefulWidget {
  const ProjectCard({super.key, required this.match});

  final ProjectMatch match;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

final class _ProjectCardState extends State<ProjectCard> {
  Offset? _pointerLocal;
  bool _pointerActive = false;

  static const Color _kSpotNeon = Color(0xFFFCFF70);

  static const String _dummyDescription =
      'Yerel üreticilerin kendi ürünlerini sergileyip satabileceği, iOS ve Android '
      'platformlarında sorunsuz çalışacak modern bir pazar yeri uygulaması geliştirilmesi '
      'hedeflenmektedir. Ekip, backend ve mobil deneyimine sahip geliştiriciler arıyor.';

  static const _cardRadius = BorderRadius.all(Radius.circular(18));
  static const _cardPadding = EdgeInsets.fromLTRB(16.8, 17.6, 16.8, 17.6);

  bool get _isClosed =>
      widget.match.similarityPercent < 50 || widget.match.projectId % 4 == 0;

  void _onPointerHover(PointerHoverEvent event) {
    setState(() {
      _pointerLocal = event.localPosition;
      _pointerActive = true;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    setState(() {
      _pointerLocal = event.localPosition;
      _pointerActive = true;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _pointerLocal = event.localPosition;
      _pointerActive = true;
    });
  }

  void _clearSpotlight() {
    setState(() {
      _pointerLocal = null;
      _pointerActive = false;
    });
  }

  Widget _cardContent(BuildContext context) {
    final ui = _ui(context);
    const ownerEmail = 'kullanici@gmail.com';
    final skills = widget.match.requiredSkills.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _authorAvatar(context, initial: ownerEmail[0].toUpperCase()),
            const SizedBox(width: 8.8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ownerEmail,
                    style: TextStyle(
                      color: ui.authorName,
                      fontSize: 13.1,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    'İlan Sahibi',
                    style: TextStyle(
                      color: ui.authorRole,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            _projectStatusBadge(context, closed: _isClosed),
          ],
        ),
        const SizedBox(height: 11.2),
        Text(
          widget.match.projectTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ui.jobTitle,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 9.9),
        Wrap(
          spacing: 6.7,
          runSpacing: 6.7,
          children: [
            _metaChip(context, 'Takım: ${widget.match.similarityPercent}'),
            _metaChip(context, 'Yetenek: ${widget.match.semanticPercent}'),
          ],
        ),
        const SizedBox(height: 11.2),
        Wrap(
          spacing: 6.1,
          runSpacing: 6.1,
          children: skills.isEmpty
              ? [_skillTag(context, 'Belirtilmedi')]
              : skills.map((s) => _skillTag(context, s)).toList(),
        ),
        const SizedBox(height: 11.2),
        Text(
          _dummyDescription,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15.2,
            height: 1.68,
            color: ui.jobDesc,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = _ui(context);
    final surfaceFill = ui.cardBg.withValues(alpha: 0.8);

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _clearSpotlight(),
      onPointerCancel: (_) => _clearSpotlight(),
      child: MouseRegion(
        onHover: _onPointerHover,
        onExit: (_) => _clearSpotlight(),
        child: ClipRRect(
          borderRadius: _cardRadius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: _cardRadius,
              border: Border.all(
                color: _pointerActive ? ui.cardHoverBorder : ui.cardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: ui.cardShadow,
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final showSpot = _pointerActive && _pointerLocal != null && w > 0 && h > 0;
                Alignment gradientCenter = Alignment.center;
                if (showSpot) {
                  gradientCenter = Alignment(
                    (_pointerLocal!.dx / w) * 2 - 1,
                    (_pointerLocal!.dy / h) * 2 - 1,
                  );
                }

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: surfaceFill),
                    ),
                    if (showSpot)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: gradientCenter,
                                radius: 1.05,
                                colors: [
                                  _kSpotNeon.withValues(alpha: 0.28),
                                  _kSpotNeon.withValues(alpha: 0.14),
                                  _kSpotNeon.withValues(alpha: 0.05),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.28, 0.45, 0.72],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: _cardPadding,
                      child: _cardContent(context),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Widget _feedHeaderSliver(BuildContext context, {required void Function() onRefresh}) {
  final ui = _ui(context);

  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;

          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Project Match Feed',
                style: TextStyle(
                  fontSize: 19.5,
                  fontWeight: FontWeight.w700,
                  color: ui.jobTitle,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3.2),
              Text(
                'Yazılım projeleri, ekip ihtiyaçları ve teknoloji stack bazlı ilan akışı.',
                style: TextStyle(
                  fontSize: 14.7,
                  height: 1.6,
                  letterSpacing: 0.3,
                  color: ui.heroSubtitle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('İlan oluşturma yakında mobilde.')),
                  );
                },
                child: const Text('Yeni Proje İlanı'),
              ),
              OutlinedButton(
                onPressed: onRefresh,
                child: const Text('Akışı Yenile'),
              ),
            ],
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 17.6),
            padding: const EdgeInsets.fromLTRB(16.8, 16, 16.8, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ui.heroBorder),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(-0.5, 1.2),
                colors: [ui.heroGradientStart, ui.heroGradientEnd],
              ),
            ),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 16),
                      actions,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      actions,
                    ],
                  ),
          );
        },
      ),
    ),
  );
}

// --- Matchmaking ekranı ------------------------------------------------------------------------

final class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({
    super.key,
    required this.accessToken,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final String accessToken;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final Future<void> Function() onLogout;

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

final class _MatchmakingScreenState extends State<MatchmakingScreen> {
  final _api = ApiService();
  late Future<MatchSuggestionsResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchMatchSuggestions(widget.accessToken);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.fetchMatchSuggestions(widget.accessToken);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Co-Forge'),
        actions: [
          IconButton(
            icon: Icon(
              widget.themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: widget.themeMode == ThemeMode.dark ? 'Açık tema' : 'Koyu tema',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: _kColorDanger),
            tooltip: 'Çıkış Yap',
            onPressed: () async => widget.onLogout(),
          ),
        ],
      ),
      body: FutureBuilder<MatchSuggestionsResponse>(
        future: _future,
        builder: (context, snap) {
          final slivers = <Widget>[
            _feedHeaderSliver(context, onRefresh: () => _refresh()),
          ];

          if (snap.connectionState == ConnectionState.waiting) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            );
            return CustomScrollView(slivers: slivers);
          }
          if (snap.hasError) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_off, size: 56, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          snap.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            return CustomScrollView(slivers: slivers);
          }
          final data = snap.data!;
          if (!data.ok) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(data.error ?? 'Bilinmeyen hata')),
              ),
            );
            return CustomScrollView(slivers: slivers);
          }
          if (data.matches.isEmpty) {
            slivers.add(
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Henüz öneri yok.\n(Kaynak: ${data.source})',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            );
            return CustomScrollView(slivers: slivers);
          }

          slivers.add(
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 15.2, 24, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final m = data.matches[index];
                    return Padding(
                      padding: EdgeInsets.only(bottom: index < data.matches.length - 1 ? 16 : 0),
                      child: ProjectCard(match: m),
                    );
                  },
                  childCount: data.matches.length,
                ),
              ),
            ),
          );
          return CustomScrollView(slivers: slivers);
        },
      ),
    );
  }
}