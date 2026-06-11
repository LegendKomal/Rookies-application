import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rookies_jeans/models/banner_model.dart';
import 'package:rookies_jeans/models/collection_model.dart';
import 'package:rookies_jeans/models/home_screen_data.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color bgColor = Color(0xfff5f5f3);
  static const Color primary = Color(0xff111111);
  static const Color secondaryText = Color(0xff6b6b6b);
  static const Color border = Color(0xffdddddd);

  final PageController _bannerController = PageController(viewportFraction: 1);
  Timer? _bannerTimer;

  bool _isLoading = true;
  String? _error;
  HomeScreenData? _homeData;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ShopifyStorefrontService.instance.fetchHomeScreenData();
      if (!mounted) return;

      setState(() {
        _homeData = data;
        _isLoading = false;
      });

      _startBannerAutoScroll(data.banners.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startBannerAutoScroll(int count) {
    _bannerTimer?.cancel();
    if (count <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerController.hasClients) return;
      final nextPage = (_currentBannerIndex + 1) % count;
      _bannerController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final oversizedHandle = _homeData?.oversizedCollection?.handle ?? '';
    final oversizedProducts = _homeData?.collectionProducts[oversizedHandle] ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primary),
              )
            : _error != null
                ? _ErrorView(
                    error: _error!,
                    onRetry: _loadHomeData,
                  )
                : RefreshIndicator(
                    color: primary,
                    onRefresh: _loadHomeData,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          floating: false,
                          elevation: 0,
                          toolbarHeight: 62,
                          backgroundColor: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          titleSpacing: 16,
                          title: Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/logo.png',
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                          ),
                          bottom: PreferredSize(
                            preferredSize: const Size.fromHeight(62),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: primary, width: 0.8),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: const Text(
                                  'Search',
                                  style: TextStyle(
                                    color: Color(0xff7b7b7b),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 14),
                              if (_homeData!.banners.isNotEmpty)
                                _BannerSection(
                                  banners: _homeData!.banners,
                                  controller: _bannerController,
                                  currentIndex: _currentBannerIndex,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentBannerIndex = index;
                                    });
                                  },
                                ),
                              if (_homeData!.latestProducts.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                const _SectionTitle(title: 'THE LATEST DROP'),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 272,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _homeData!.latestProducts.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                                    itemBuilder: (context, index) {
                                      return _LatestProductCard(
                                        product: _homeData!.latestProducts[index],
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (_homeData!.selectedCategories.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                const _PaddedSection(
                                  child: _SectionTitle(title: 'EXPLORE CATEGORIES'),
                                ),
                                const SizedBox(height: 14),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: GridView.builder(
                                    itemCount: _homeData!.selectedCategories.length,
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 0.79,
                                    ),
                                    itemBuilder: (context, index) {
                                      return _CategoryTile(
                                        collection: _homeData!.selectedCategories[index],
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (_homeData!.promoBannerCollection != null) ...[
                                const SizedBox(height: 14),
                                _SinglePromoBanner(
                                  collection: _homeData!.promoBannerCollection!,
                                ),
                              ],
                              if (_homeData!.selectedCollections.isNotEmpty) ...[
                                const SizedBox(height: 18),
                                const _SectionTitle(title: 'OUR COLLECTION'),
                                const SizedBox(height: 14),
                                SizedBox(
                                  height: 112,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _homeData!.selectedCollections.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                                    itemBuilder: (context, index) {
                                      return _CollectionTile(
                                        collection: _homeData!.selectedCollections[index],
                                      );
                                    },
                                  ),
                                ),
                              ],
                              if (_homeData!.oversizedCollection != null &&
                                  oversizedProducts.isNotEmpty)
                                _EditorialProductSection(
                                  title: _homeData!.oversizedCollection!.title,
                                  subtitle: _homeData!.oversizedCollection!.description,
                                  products: oversizedProducts,
                                ),
                              if (_homeData!.hotDealCollections.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                _HotDealsSection(
                                  collections: _homeData!.hotDealCollections,
                                ),
                              ],
                              ..._homeData!.selectedCollections.map((collection) {
                                final products =
                                    _homeData!.collectionProducts[collection.handle] ?? [];
                                if (products.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return _EditorialProductSection(
                                  title: collection.title,
                                  subtitle: collection.description,
                                  products: products,
                                );
                              }),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _PaddedSection extends StatelessWidget {
  final Widget child;

  const _PaddedSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.4,
          color: Color(0xff111111),
        ),
      ),
    );
  }
}

class _BannerSection extends StatelessWidget {
  final List<BannerModel> banners;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  const _BannerSection({
    required this.banners,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: controller,
            itemCount: banners.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final banner = banners[index];
              final imageUrl = isMobile
                  ? (banner.mobileImageUrl.isNotEmpty
                      ? banner.mobileImageUrl
                      : banner.desktopImageUrl)
                  : (banner.desktopImageUrl.isNotEmpty
                      ? banner.desktopImageUrl
                      : banner.mobileImageUrl);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) {
                    return Container(color: const Color(0xffe3e3e3));
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            banners.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color:const Color(0xffd8d8d8),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SinglePromoBanner extends StatelessWidget {
  final CollectionModel collection;

  const _SinglePromoBanner({required this.collection});

  @override
  Widget build(BuildContext context) {
    if (collection.imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Image.network(
        collection.imageUrl,
        height: 96,
        width: double.infinity,
        filterQuality: FilterQuality.high,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            height: 96,
            color: const Color(0xffe3e3e3),
          );
        },
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final CollectionModel collection;

  const _CollectionTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: collection.imageUrl.isNotEmpty
                  ? Image.network(
                      collection.imageUrl,
                      width: double.infinity,
                      filterQuality: FilterQuality.high,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(color: const Color(0xffd8d8d8));
                      },
                    )
                  : Container(color: const Color(0xffd8d8d8)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            collection.title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CollectionModel collection;

  const _CategoryTile({required this.collection});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          collection.imageUrl.isNotEmpty
              ? Image.network(
                  collection.imageUrl,
                  filterQuality: FilterQuality.high,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(color: const Color(0xffd8d8d8));
                  },
                )
              : Container(color: const Color(0xffd8d8d8)),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black54,
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                collection.title.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestProductCard extends StatelessWidget {
  final ProductModel product;

  const _LatestProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      filterQuality: FilterQuality.high,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(color: const Color(0xffdcdcdc));
                      },
                    )
                  : Container(color: const Color(0xffdcdcdc)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xff111111),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorialProductSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<ProductModel> products;

  const _EditorialProductSection({
    required this.title,
    required this.subtitle,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xff111111),
            ),
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xff8a8a8a),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: 338,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 2),
            itemBuilder: (context, index) {
              return _EditorialProductCard(product: products[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _EditorialProductCard extends StatelessWidget {
  final ProductModel product;

  const _EditorialProductCard({required this.product});

  String _buttonLabel() {
    final title = product.title.trim();
    if (title.isEmpty) return 'SHOP NOW';
    final words = title.split(' ');
    if (words.length == 1) return words.first.toUpperCase();
    return '${words.first} ${words[1]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      color: const Color(0xfff5f5f3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: product.imageUrl.isNotEmpty
                ? Image.network(
                    product.imageUrl,
                    filterQuality: FilterQuality.high,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(color: const Color(0xffdcdcdc));
                    },
                  )
                : Container(color: const Color(0xffdcdcdc)),
          ),
          const SizedBox(height: 8),
          Text(
            product.title.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.25,
              color: Color(0xff111111),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text(
                product.formattedPrice,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xff4c4c4c),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (product.hasDiscount) ...[
                const SizedBox(width: 8),
                Text(
                  product.formattedCompareAt,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xff7b7b7b),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff111111),
                side: const BorderSide(
                  color: Color(0xff111111),
                  width: 0.8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                _buttonLabel(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotDealsSection extends StatelessWidget {
  final List<CollectionModel> collections;

  const _HotDealsSection({required this.collections});

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const _SectionTitle(title: 'HOT DEALS'),
        const SizedBox(height: 14),
        SizedBox(
          height: 96,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: collections.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return _HotDealCollectionCard(collection: collections[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _HotDealCollectionCard extends StatelessWidget {
  final CollectionModel collection;

  const _HotDealCollectionCard({required this.collection});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      child: collection.imageUrl.isNotEmpty
          ? Image.network(
              collection.imageUrl,
              filterQuality: FilterQuality.high,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(color: const Color(0xffdcdcdc));
              },
            )
          : Container(color: const Color(0xffdcdcdc)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xff111111),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xff6b6b6b),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}