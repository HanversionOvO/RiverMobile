import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:river/core/account/account_models.dart';
import 'package:river/core/constants.dart';
import 'package:url_launcher/url_launcher.dart';

class ComposeTopicPreviewPage extends StatelessWidget {
  const ComposeTopicPreviewPage({
    super.key,
    required this.title,
    required this.categoryName,
    required this.markdown,
    required this.author,
  });

  final String title;
  final String categoryName;
  final String markdown;
  final UserAccount? author;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final displayName = (author?.displayName ?? '').trim();
    final username = (author?.username ?? '').trim();
    final avatarUrl = (author?.avatarUrl ?? '').trim();
    final subtitleName = displayName.isNotEmpty
        ? displayName
        : (username.isNotEmpty ? username : '匿名用户');

    return Scaffold(
      appBar: AppBar(title: const Text('发帖预览')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: avatarUrl.isEmpty
                            ? null
                            : NetworkImage(avatarUrl),
                        child: avatarUrl.isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitleName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username.isEmpty ? '' : '@$username',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _Meta(
                        text: _formatTime(now),
                        icon: Icons.schedule_outlined,
                      ),
                      const _Meta(text: '编辑 0', icon: Icons.edit_note),
                      const _Meta(
                        text: '浏览 0',
                        icon: Icons.visibility_outlined,
                      ),
                      const _Meta(
                        text: '点赞 0',
                        icon: Icons.thumb_up_alt_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (categoryName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Chip(
                        label: Text(categoryName),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  MarkdownBody(
                    data: _normalizeMarkdownForPreview(markdown),
                    selectable: true,
                    onTapLink: (_, href, _) async {
                      final raw = href?.trim() ?? '';
                      if (raw.isEmpty) {
                        return;
                      }
                      final uri = Uri.tryParse(raw);
                      if (uri == null) {
                        return;
                      }
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '评论内容',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '这是预览页面。发帖成功后将进入真实帖子详情页。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeMarkdownForPreview(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return text;
    }
    return text.replaceAllMapped(
      RegExp(r'upload://([^\s)>\]]+)', caseSensitive: false),
      (match) => '$riverSideBaseUrl/uploads/short-url/${match.group(1) ?? ''}',
    );
  }

  String _formatTime(DateTime value) {
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
