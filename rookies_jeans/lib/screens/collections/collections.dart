import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/shop_menu_model.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

/// Which inline accordion panel is currently open. `null` means both are
/// collapsed. Only one panel can be open at a time — opening one closes the
/// other.
enum _MenuPanel { topWear, bottomWear }

class ExploreCategoriesPage extends StatefulWidget {
  const ExploreCategoriesPage({super.key});
  @override
  State<ExploreCategoriesPage> createState() => _ExploreCategoriesPageState();
}

class _ExploreCategoriesPageState extends State<ExploreCategoriesPage> {
  late Future<List<ShopMenuSection>> _future;
  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  _MenuPanel? _expandedPanel;

  @override
  void initState() {
    super.initState();
    _future = ShopifyStorefrontService.instance.getExploreMenuSections();
  }

  Future<void> _refresh() async {
    setState(() {
      ShopifyStorefrontService.instance.clearCache();
      _future = ShopifyStorefrontService.instance.getExploreMenuSections();
      _expandedPanel = null;
    });
    await _future;
  }

  void _togglePanel(_MenuPanel panel) {
    setState(() {
      _expandedPanel = _expandedPanel == panel ? null : panel;
    });
  }

  void _openCollections() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllCollectionsPage()),
    );
  }

  void _openCategory(
    String title,
    String collectionHandle, {
    String? fitTitle,
  }) {
    if (collectionHandle.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsPage(
          collection: ShopifyCollection(
            id: collectionHandle,
            title: title,
            handle: collectionHandle,
            label: title.toUpperCase(),
          ),
          initialFitFilter: fitTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final titleSize = (width * 0.09).clamp(20.0, 40.0);

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              Expanded(
                child: Text(
                  'EXPLORE CATEGORIES',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1,
                    fontFamily: _fHead,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<ShopMenuSection>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _refresh);
                }

                final sections = snapshot.data ?? [];
                final ShopMenuSection? topWear =
                    _sectionByHandle(sections, 'top-wear');
                final ShopMenuSection? bottomWear =
                    _sectionByHandle(sections, 'bottom-wear');

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _MenuRow(
                      title: 'COLLECTIONS',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                      ),
                      onTap: _openCollections,
                      fontFamily: _fBold,
                    ),
                    _divider(),
                    _MenuRow(
                      title: (topWear?.title ?? 'TOP WEAR').toUpperCase(),
                      trailing: _panelIcon(_expandedPanel == _MenuPanel.topWear),
                      onTap: () => _togglePanel(_MenuPanel.topWear),
                      fontFamily: _fBold,
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _expandedPanel == _MenuPanel.topWear
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: _CategoriesGrid(
                        categories: topWear?.categories ?? const [],
                        headFont: _fBold,
                        bodyFont: _fBody,
                        onCategoryTap: _openCategory,
                        onFitTap: (categoryTitle, categoryHandle, fit) =>
                            _openCategory(
                          categoryTitle,
                          categoryHandle,
                          fitTitle: fit.title,
                        ),
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                    _divider(),
                    _MenuRow(
                      title: (bottomWear?.title ?? 'BOTTOM WEAR').toUpperCase(),
                      trailing:
                          _panelIcon(_expandedPanel == _MenuPanel.bottomWear),
                      onTap: () => _togglePanel(_MenuPanel.bottomWear),
                      fontFamily: _fBold,
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 200),
                      crossFadeState: _expandedPanel == _MenuPanel.bottomWear
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      firstChild: _CategoriesGrid(
                        categories: bottomWear?.categories ?? const [],
                        headFont: _fBold,
                        bodyFont: _fBody,
                        onCategoryTap: _openCategory,
                        onFitTap: (categoryTitle, categoryHandle, fit) =>
                            _openCategory(
                          categoryTitle,
                          categoryHandle,
                          fitTitle: fit.title,
                        ),
                      ),
                      secondChild: const SizedBox(width: double.infinity),
                    ),
                    _divider(),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelIcon(bool expanded) => Icon(
        expanded ? Icons.remove_rounded : Icons.add_rounded,
        color: AppColors.primary,
        size: 22,
      );

  Widget _divider() => Divider(height: 1, thickness: 1, color: AppColors.border);

  ShopMenuSection? _sectionByHandle(List<ShopMenuSection> sections, String handle) {
    for (final s in sections) {
      if (s.handle == handle) return s;
    }
    return null;
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.trailing,
    required this.onTap,
    required this.fontFamily,
  });

  final String title;
  final Widget trailing;
  final VoidCallback onTap;
  final String fontFamily;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.primary,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// The two-column "category name (bold) + list of fits" grid shown under an
/// expanded Top Wear / Bottom Wear panel — matches the merchant's menu
/// design: categories alternate left/right column in the order Shopify
/// returns them.
class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({
    required this.categories,
    required this.headFont,
    required this.bodyFont,
    required this.onCategoryTap,
    required this.onFitTap,
  });

  final List<ShopMenuCategory> categories;
  final String headFont;
  final String bodyFont;
  final void Function(String title, String collectionHandle) onCategoryTap;
  final void Function(
    String categoryTitle,
    String collectionHandle,
    ShopMenuFit fit,
  ) onFitTap;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Text(
          'No categories found',
          style: TextStyle(fontFamily: bodyFont, color: AppColors.secondaryText),
        ),
      );
    }

    final List<ShopMenuCategory> left = [];
    final List<ShopMenuCategory> right = [];
    for (int i = 0; i < categories.length; i++) {
      (i.isEven ? left : right).add(categories[i]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: left.map(_block).toList(),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: right.map(_block).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(ShopMenuCategory category) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => onCategoryTap(category.title, category.collectionHandle),
            child: Text(
              category.title,
              style: TextStyle(
                fontFamily: headFont,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final fit in category.fits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () =>
                    onFitTap(category.title, category.collectionHandle, fit),
                child: Text(
                  fit.title,
                  style: TextStyle(
                    fontFamily: bodyFont,
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full list of every collection in the store — opened from the
/// "Collections" row on [ExploreCategoriesPage].
class AllCollectionsPage extends StatefulWidget {
  const AllCollectionsPage({super.key});
  @override
  State<AllCollectionsPage> createState() => _AllCollectionsPageState();
}

class _AllCollectionsPageState extends State<AllCollectionsPage> {
  late Future<List<ShopifyCollection>> _future;
  static const String _fHead = AppFonts.heading;

  @override
  void initState() {
    super.initState();
    _future = ShopifyStorefrontService.instance.getAllCollections();
  }

  Future<void> _refresh() async {
    setState(() {
      ShopifyStorefrontService.instance.clearCache();
      _future = ShopifyStorefrontService.instance.getAllCollections();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final titleSize = (width * 0.09).clamp(20.0, 40.0);
    final maxTileExtent = width >= 1024
        ? 260.0
        : width >= 600
            ? 240.0
            : 220.0;

    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.card,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'COLLECTIONS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: titleSize,
                    height: 1,
                    fontFamily: _fHead,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder<List<ShopifyCollection>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(onRetry: _refresh);
                }
                final collections = snapshot.data ?? [];
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (collections.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('No collections found')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: maxTileExtent,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) =>
                                _CategoryTile(category: collections[index]),
                            childCount: collections.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final ShopifyCollection category;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth;
        final labelSize = (tileWidth * 0.09).clamp(14.0, 22.0);
        final gradientHeight = (tileWidth * 0.42).clamp(56.0, 90.0);
        final inset = (tileWidth * 0.08).clamp(10.0, 18.0);

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductsPage(collection: category),
              ),
            );
          },
          child: ClipRRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  color: const Color(0xFFD9D9D9),
                  child: category.imageUrl != null
                      ? Image.network(
                          category.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) =>
                              const SizedBox.shrink(),
                        )
                      : null,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: gradientHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.45),
                          Colors.black.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: inset,
                  right: inset,
                  bottom: inset,
                  child: Text(
                    category.label.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: labelSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.secondaryText),
            const SizedBox(height: 12),
            const Text(
              'Something went wrong loading categories.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
