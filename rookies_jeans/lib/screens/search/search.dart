import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/product_model.dart';
import 'package:rookies_jeans/screens/products/product_detail_page.dart';
import 'package:rookies_jeans/services/shopify_storefront_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  static const Color primary      = Color(ShopifyConstants.primaryColorHex);
  static const Color bgColor      = Color(ShopifyConstants.bgColorHex);
  static const Color cardColor    = Color(ShopifyConstants.cardColorHex);
  static const Color secondaryTxt = Color(ShopifyConstants.secondaryTextHex);

  static const String _fHead = ShopifyConstants.fontHeading;
  static const String _fBody = ShopifyConstants.fontBody;
  static const String _fBold = ShopifyConstants.fontBodyBold;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ShopifyProduct> _suggestions = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  Timer? _debounce;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    if (query.length < 3) {
      setState(() {
        _suggestions = [];
        _hasSearched = false;
        _isSearching = false;
      });
      _fadeCtrl.reverse();
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 380), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) return;

    try {
      final result =
          await ShopifyStorefrontService.instance.searchProducts(query);
      if (!mounted) return;
      if (_searchCtrl.text.trim() != query) return;

      setState(() {
        _suggestions = result;
        _isSearching = false;
        _hasSearched = true;
      });

      if (result.isNotEmpty) {
        _fadeCtrl.forward(from: 0);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  void _openProductDetail(ShopifyProduct product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          handle: product.handle,
          title: product.title,
          heroImageUrl: product.primaryImageUrl,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _suggestions = [];
      _hasSearched = false;
      _isSearching = false;
      _lastQuery = '';
    });
    _fadeCtrl.reverse();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
            color: primary.withOpacity(0.12),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: primary,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),

          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: primary.withOpacity(0.15),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: _fBody,
                  fontSize: 14,
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(
                    fontFamily: _fBody,
                    fontSize: 14,
                    color: secondaryTxt.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: secondaryTxt,
                    size: 20,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: secondaryTxt,
                            size: 18,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final query = _searchCtrl.text.trim();

    if (query.isEmpty) return _buildIdleState();
    if (query.length < 3) return _buildTypeMoreHint(query.length);
    if (_isSearching) return _buildLoadingState();
    if (_hasSearched && _suggestions.isEmpty) return _buildEmptyState(query);
    if (_suggestions.isNotEmpty) return _buildResultsList();

    return const SizedBox.shrink();
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_rounded,
            size: 56,
            color: primary.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'SEARCH PRODUCTS',
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primary.withOpacity(0.35),
              // letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start typing to find what you\'re looking for',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 12,
              color: secondaryTxt.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeMoreHint(int currentLength) {
    final remaining = 3 - currentLength;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Type $remaining more ${remaining == 1 ? 'character' : 'characters'}',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 13,
              color: secondaryTxt.withOpacity(0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'to see suggestions',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 12,
              color: secondaryTxt.withOpacity(0.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _shimmerTile(),
    );
  }

  Widget _shimmerTile() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 88,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 13,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 11,
                width: 100,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: primary.withOpacity(0.18),
          ),
          const SizedBox(height: 16),
          Text(
            'No results for',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 13,
              color: secondaryTxt.withOpacity(0.55),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"$query"',
            style: TextStyle(
              fontFamily: _fBold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: primary.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try a different search term',
            style: TextStyle(
              fontFamily: _fBody,
              fontSize: 12,
              color: secondaryTxt.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '${_suggestions.length} RESULT${_suggestions.length == 1 ? '' : 'S'}',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: primary.withOpacity(0.45),
                // letterSpacing: 1.6,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: primary.withOpacity(0.08),
              ),
              itemBuilder: (_, i) => _suggestionTile(_suggestions[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionTile(ShopifyProduct product) {
    return InkWell(
      onTap: () => _openProductDetail(product),
      splashColor: primary.withOpacity(0.05),
      highlightColor: primary.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 72,
                height: 88,
                child: product.primaryImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: product.primaryImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: primary.withOpacity(0.07),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: primary.withOpacity(0.07),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: secondaryTxt.withOpacity(0.3),
                            size: 20,
                          ),
                        ),
                      )
                    : Container(color: primary.withOpacity(0.07)),
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _fBold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _priceRow(product),
                  if (product.colorHexCodes.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    _colorSwatches(product.colorHexCodes),
                  ],
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: primary.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(ShopifyProduct product) {
    if (!product.isOnSale) {
      return Text(
        product.formattedPrice,
        style: const TextStyle(
          fontFamily: _fBold,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      );
    }

    return Row(
      children: [
        Text(
          product.formattedPrice,
          style: const TextStyle(
            fontFamily: _fBold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          product.formattedCompareAtPrice,
          style: const TextStyle(
            fontFamily: _fBody,
            fontSize: 11,
            color: Color(0xFF9A9A9A),
            decoration: TextDecoration.lineThrough,
            decorationColor: Color(0xFF9A9A9A),
          ),
        ),
      ],
    );
  }

  Widget _colorSwatches(List<String> hexCodes) {
    final visible = hexCodes.take(5).toList();
    return Row(
      children: visible.map((hex) {
        Color color;
        try {
          final cleaned = hex.replaceAll('#', '');
          color = Color(int.parse('FF$cleaned', radix: 16));
        } catch (_) {
          color = const Color(0xFFCCCCCC);
        }
        return Container(
          margin: const EdgeInsets.only(right: 5),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFDDDDDD), width: 0.8),
          ),
        );
      }).toList(),
    );
  }
}