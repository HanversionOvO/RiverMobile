part of 'riverside_profile_page.dart';

class _ProfileHiddenView extends StatelessWidget {
  const _ProfileHiddenView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text('用户已隐藏资料', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;

  const _MetaChip({required this.label, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finalColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: finalColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: finalColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionAnimatedSwitcher extends StatelessWidget {
  const _ProfileSectionAnimatedSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            final children = <Widget>[...previousChildren, ?currentChild];
            return Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: children,
            );
          },
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(fade);
            final size = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return Align(
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: fade,
                child: SizeTransition(
                  sizeFactor: size,
                  axisAlignment: -1,
                  child: SlideTransition(position: slide, child: child),
                ),
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class _ProfileHeaderSkeleton extends StatelessWidget {
  const _ProfileHeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox.circular(size: 84),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 8),
                    _SkeletonBox(width: 180, height: 26),
                    SizedBox(height: 10),
                    _SkeletonBox(width: 120, height: 16),
                    SizedBox(height: 10),
                    _SkeletonBox(width: 150, height: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          _SkeletonBox(height: 44),
          SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _SkeletonStat(),
              _SkeletonStat(),
              _SkeletonStat(),
              _SkeletonStat(),
            ],
          ),
          SizedBox(height: 20),
          _SkeletonBox(height: 14),
          SizedBox(height: 8),
          _SkeletonBox(width: 260, height: 14),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SkeletonBox(width: 110, height: 24),
              _SkeletonBox(width: 138, height: 24),
              _SkeletonBox(width: 124, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityTabSkeleton extends StatelessWidget {
  const _ActivityTabSkeleton({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 6,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const _ActivityCardSkeleton(),
      ),
    );
  }
}

class _BadgesTabSkeleton extends StatelessWidget {
  const _BadgesTabSkeleton({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => const _BadgeTileSkeleton(),
      ),
    );
  }
}

class _UsersTabSkeleton extends StatelessWidget {
  const _UsersTabSkeleton({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        itemCount: 10,
        separatorBuilder: (_, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => const _UserTileSkeleton(),
      ),
    );
  }
}

class _SkeletonStat extends StatelessWidget {
  const _SkeletonStat();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _SkeletonBox(width: 28, height: 20),
        SizedBox(height: 6),
        _SkeletonBox(width: 34, height: 12),
      ],
    );
  }
}

class _ActivityCardSkeleton extends StatelessWidget {
  const _ActivityCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 72, height: 20),
              Spacer(),
              _SkeletonBox(width: 46, height: 14),
            ],
          ),
          SizedBox(height: 10),
          _SkeletonBox(height: 18),
          SizedBox(height: 6),
          _SkeletonBox(width: 220, height: 18),
          SizedBox(height: 10),
          _SkeletonBox(height: 14),
          SizedBox(height: 6),
          _SkeletonBox(width: 260, height: 14),
          SizedBox(height: 12),
          Row(
            children: [
              _SkeletonBox(width: 52, height: 14),
              SizedBox(width: 16),
              _SkeletonBox(width: 52, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTileSkeleton extends StatelessWidget {
  const _BadgeTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          _SkeletonBox.circular(size: 40),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 150, height: 16),
                SizedBox(height: 8),
                _SkeletonBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTileSkeleton extends StatelessWidget {
  const _UserTileSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          _SkeletonBox.circular(size: 38),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: 130, height: 15),
                SizedBox(height: 7),
                _SkeletonBox(width: 96, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, this.height = 12}) : circle = false;

  const _SkeletonBox.circular({required double size})
    : width = size,
      height = size,
      circle = true;

  final double? width;
  final double height;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surfaceContainerHigh;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {},
      builder: (context, value, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOut,
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Color.lerp(base, highlight, value),
            borderRadius: BorderRadius.circular(circle ? height / 2 : 8),
          ),
        );
      },
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  final VoidCallback onRefresh;
  const _EmptyView({required this.message, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.grey)),
          TextButton(onPressed: onRefresh, child: const Text('刷新')),
        ],
      ),
    );
  }
}

class _ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color color;

  _StickyTabBarDelegate(this._tabBar, {required this.color});

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: color, child: _tabBar);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return _tabBar != oldDelegate._tabBar;
  }
}

class _ProfileTabDef {
  final String title;
  final RiverSideProfileActivityKind? kind;
  const _ProfileTabDef({required this.title, this.kind});
}
