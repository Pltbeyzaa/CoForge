import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_config.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class _TeamMember {
  _TeamMember({required this.name, required this.role});
  final String name;
  final String role;

  Map<String, dynamic> toJson() => {'name': name, 'role': role};
}

class _AssignedTask {
  const _AssignedTask({required this.taskName, required this.assignee});
  final String taskName;
  final String assignee;
}

class _ChatEntry {
  _ChatEntry(
      {required this.userMessage,
      required this.aiMessage,
      required this.tasks});
  final String userMessage;
  final String aiMessage;
  final List<_AssignedTask> tasks;
}

class _QuickPrompt {
  const _QuickPrompt(
      {required this.label, required this.icon, required this.prompt});
  final String label;
  final IconData icon;
  final String prompt;
}

// ── Constants ───────────────────────────────────────────────────────────────

// kBaseUrl gelir: Web → 127.0.0.1:8000, Android emülatör → 10.0.2.2:8000

const _quickPrompts = [
  _QuickPrompt(
      label: 'Sprint Planı',
      icon: Icons.calendar_month_outlined,
      prompt:
          'Bu proje için 2 haftalık bir sprint planı oluştur ve görevleri takım üyelerine dağıt.'),
  _QuickPrompt(
      label: 'Görev Dağıtımı',
      icon: Icons.assignment_ind_outlined,
      prompt:
          'Takım üyelerinin rollerine göre mevcut görevleri yeniden dağıt.'),
  _QuickPrompt(
      label: 'Risk Analizi',
      icon: Icons.warning_amber_outlined,
      prompt:
          'Projemizin olası risklerini analiz et ve önlem önerilerini paylaş.'),
  _QuickPrompt(
      label: 'Retrospektif',
      icon: Icons.reviews_outlined,
      prompt:
          'Bu sprint için bir retrospektif toplantısı yönet. Neyi iyi yaptık, neyi iyileştirebiliriz?'),
];

// ── Page ────────────────────────────────────────────────────────────────────

class ScrumMasterPage extends StatefulWidget {
  const ScrumMasterPage({super.key});

  @override
  State<ScrumMasterPage> createState() => _ScrumMasterPageState();
}

class _ScrumMasterPageState extends State<ScrumMasterPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final String _projectTitle = '';
  final String _projectDescription = '';
  final List<_TeamMember> _teamMembers = [];
  final List<_ChatEntry> _history = [];

  bool _loading = false;
  String? _errorStrip;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────

  Future<void> _send(String message) async {
    if (message.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _errorStrip = null;
    });
    _msgCtrl.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final res = await http
          .post(
            Uri.parse('$kBaseUrl/api/scrum-master/chat/'),
            headers: {
              'Content-Type': 'application/json',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'project_title': _projectTitle,
              'project_description': _projectDescription,
              'team_members':
                  _teamMembers.map((m) => m.toJson()).toList(),
              'user_message': message,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (!mounted) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        setState(() {
          _errorStrip = data['error'] as String;
          _loading = false;
        });
        return;
      }

      final aiMessage = data['ai_message'] as String? ?? '';
      final rawTasks = data['assigned_tasks'] as List? ?? [];
      final tasks = rawTasks
          .cast<Map<String, dynamic>>()
          .map((t) => _AssignedTask(
                taskName: t['task_name'] as String? ?? '',
                assignee: t['assignee'] as String? ?? '',
              ))
          .toList();

      setState(() {
        _history.add(_ChatEntry(
            userMessage: message, aiMessage: aiMessage, tasks: tasks));
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorStrip =
            'Bağlantı hatası: ${e.toString().split('\n').first}';
        _loading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            _AiAvatar(size: 32, cs: cs),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Forgey',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
                Text('CoForge · Gemini 2.5 Flash',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: cs.outlineVariant),
        ),
      ),
      body: Column(
        children: [
          if (_errorStrip != null)
            _ErrorStrip(
              message: _errorStrip!,
              onDismiss: () => setState(() => _errorStrip = null),
              cs: cs,
            ),
          Expanded(
            child: _history.isEmpty && !_loading
                ? _EmptyState(cs: cs)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _history.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _history.length) {
                        return _LoadingBubble(cs: cs);
                      }
                      return _ChatPair(entry: _history[i], cs: cs);
                    },
                  ),
          ),
          _QuickActionsBar(
              prompts: _quickPrompts, onTap: _send, cs: cs),
          _MessageInput(
            ctrl: _msgCtrl,
            loading: _loading,
            cs: cs,
            onSend: () => _send(_msgCtrl.text),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.size, required this.cs});
  final double size;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.6)]),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              spreadRadius: 1)
        ],
      ),
      child:
          Icon(Icons.smart_toy, color: cs.onPrimary, size: size * 0.55),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip(
      {required this.message,
      required this.onDismiss,
      required this.cs});
  final String message;
  final VoidCallback onDismiss;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.error.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: cs.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12, color: cs.error))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDismiss,
            color: cs.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiAvatar(size: 72, cs: cs),
            const SizedBox(height: 20),
            Text(
              'Forgey',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Projenizle ilgili bir şey sorun veya\nhızlı komutları kullanarak başlayın.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                  height: 1.55),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AiAvatar(size: 28, cs: cs),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: cs.primary),
                ),
                const SizedBox(width: 10),
                Text('Düşünüyor...',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPair extends StatelessWidget {
  const _ChatPair({required this.entry, required this.cs});
  final _ChatEntry entry;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(entry.userMessage,
                style: TextStyle(
                    color: cs.onPrimary, fontSize: 14, height: 1.4)),
          ),
        ),
        _AiResponseCard(entry: entry, cs: cs),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AiResponseCard extends StatelessWidget {
  const _AiResponseCard({required this.entry, required this.cs});
  final _ChatEntry entry;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AiAvatar(size: 28, cs: cs),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.aiMessage,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 14, height: 1.55)),
                if (entry.tasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TaskSection(tasks: entry.tasks, cs: cs),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({required this.tasks, required this.cs});
  final List<_AssignedTask> tasks;
  final ColorScheme cs;

  Map<String, List<_AssignedTask>> _grouped() {
    final map = <String, List<_AssignedTask>>{};
    for (final t in tasks) {
      map.putIfAbsent(t.assignee, () => []).add(t);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.outlineVariant),
        Row(
          children: [
            Icon(Icons.assignment_outlined, size: 14, color: cs.primary),
            const SizedBox(width: 6),
            Text('Görev Dağılımı',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: cs.primary)),
          ],
        ),
        const SizedBox(height: 8),
        ...grouped.entries.map(
            (e) => _PersonTaskGroup(
                assignee: e.key, tasks: e.value, cs: cs)),
      ],
    );
  }
}

class _PersonTaskGroup extends StatelessWidget {
  const _PersonTaskGroup(
      {required this.assignee, required this.tasks, required this.cs});
  final String assignee;
  final List<_AssignedTask> tasks;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      dense: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(left: 12, bottom: 8),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: cs.primary.withValues(alpha: 0.15),
        child: Text(
          assignee.isNotEmpty ? assignee[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.primary),
        ),
      ),
      title: Text(assignee,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface)),
      subtitle: Text('${tasks.length} görev',
          style:
              TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      children: tasks
          .map(
            (t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.check_box_outline_blank,
                      size: 14, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(t.taskName,
                          style: TextStyle(
                              fontSize: 13, color: cs.onSurface))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar(
      {required this.prompts, required this.onTap, required this.cs});
  final List<_QuickPrompt> prompts;
  final void Function(String) onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final p = prompts[i];
          return ActionChip(
            avatar: Icon(p.icon, size: 14, color: cs.primary),
            label: Text(p.label,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.primary,
                    fontWeight: FontWeight.w500)),
            backgroundColor: cs.primary.withValues(alpha: 0.08),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
            onPressed: () => onTap(p.prompt),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  const _MessageInput(
      {required this.ctrl,
      required this.loading,
      required this.cs,
      required this.onSend});
  final TextEditingController ctrl;
  final bool loading;
  final ColorScheme cs;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style:
                    TextStyle(fontSize: 14, color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Forgey\'e bir komut ver...',
                  hintStyle:
                      TextStyle(color: cs.onSurfaceVariant),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide:
                          BorderSide(color: cs.outlineVariant)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(
                          color: cs.primary, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            loading
                ? SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: cs.primary),
                      ),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: cs.primary),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.send,
                          color: cs.onPrimary, size: 20),
                      onPressed: onSend,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
