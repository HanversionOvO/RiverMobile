import 'dart:ui';

import 'package:flutter/material.dart';

class MineSettingsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const MineSettingsAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.heroTagPrefix,
    this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? heroTagPrefix;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 6,
      leadingWidth: 54,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: _buildBackButton(context),
      ),
      title: Row(
        children: [
          _maybeHero(
            tag: _tag('icon'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _maybeHero(
                  tag: _tag('title'),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ),
                _maybeHero(
                  tag: _tag('subtitle'),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
      flexibleSpace: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.36 * value,
                  ),
                  theme.colorScheme.surface.withValues(alpha: 0.88),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.28,
                  ),
                ),
              ),
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: child,
              ),
            ),
          );
        },
        child: const SizedBox.expand(),
      ),
    );
  }

  String? _tag(String suffix) {
    if (heroTagPrefix == null || heroTagPrefix!.isEmpty) {
      return null;
    }
    return '${heroTagPrefix!}__$suffix';
  }

  Widget _maybeHero({required String? tag, required Widget child}) {
    if (tag == null) {
      return child;
    }
    return Hero(tag: tag, child: child);
  }

  Widget _buildBackButton(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface.withValues(alpha: 0.90),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.26),
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).maybePop(),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 20,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
