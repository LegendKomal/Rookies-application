import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/screens/products/products.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class ExploreCategoriesPage extends StatefulWidget {
  const ExploreCategoriesPage({super.key});

  @override
  State<ExploreCategoriesPage> createState() => _ExploreCategoriesPageState();
}

class _ExploreCategoriesPageState extends State<ExploreCategoriesPage> {
  late Future<List<ShopifyCollection>> _future;
  static const String _fHead = ShopifyConstants.fontHeading;

  @override
  void initState() {
    super.initState();
    _future = ShopifyStorefrontService.instance.getExploreCategories();
  }

  Future<void> _refresh() async {
    setState(() {
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
        automaticallyImplyLeading: false,
        toolbarHeight: 84,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 12, right: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  size: 22,
                  color: Color(ShopifyConstants.primaryColorHex),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'EXPLORE CATEGORIES',
                style: TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontFamily: _fHead,
                  color: Color(ShopifyConstants.primaryColorHex),
                ),
              ),
            ],
          ),
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

              final categories = snapshot.data ?? [];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
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