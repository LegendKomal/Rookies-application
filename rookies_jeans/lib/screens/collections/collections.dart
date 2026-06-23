import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/screens/search/search.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class ExploreCategoriesPage extends StatefulWidget {
  const ExploreCategoriesPage({super.key});

  @override
  State<ExploreCategoriesPage> createState() => _ExploreCategoriesPageState();
}

class _ExploreCategoriesPageState extends State<ExploreCategoriesPage> {
  late Future<List<ShopifyCollection>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopifyStorefrontService.instance.getExploreCategories();
  }

  Future<void> _refresh() async {
    setState(() {
      // Force a fresh network call instead of the cached one.
      ShopifyStorefrontService.instance.clearCache();
      _future = ShopifyStorefrontService.instance.getExploreCategories();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(ShopifyConstants.bgColorHex),
      appBar: AppBar(
        backgroundColor: const Color(ShopifyConstants.bgColorHex),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: const Color(ShopifyConstants.primaryColorHex),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            color: const Color(ShopifyConstants.primaryColorHex),
            onPressed: () {
              Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const SearchPage(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
            },
          ),
          // IconButton(
          //   icon: const Icon(Icons.favorite_border),
          //   color: const Color(ShopifyConstants.primaryColorHex),
          //   onPressed: () {
          //     // TODO: hook up to your wishlist page/route
          //   },
          // ),
          // IconButton(
          //   icon: const Icon(Icons.shopping_bag_outlined),
          //   color: const Color(ShopifyConstants.primaryColorHex),
          //   onPressed: () {
          //     // TODO: hook up to your cart page/route
          //   },
          // ),
        ],
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

              final categories = snapshot.data ?? [];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                      child: Text(
                        'EXPLORE CATEGORIES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(ShopifyConstants.primaryColorHex),
                        ),
                      ),
                    ),
                  ),
                  if (categories.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('No categories found')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final category = categories[index];
                            return _CategoryTile(category: category);
                          },
                          childCount: categories.length,
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
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final ShopifyCollection category;

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(4),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
              height: 70,
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
              left: 14,
              bottom: 14,
              child: Text(
                category.label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
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
            const Icon(Icons.error_outline, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Something went wrong loading categories.'),
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