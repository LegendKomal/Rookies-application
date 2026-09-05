import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:rookies_jeans/constant/app_ui.dart';
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
  static Color get primary      => AppColors.primary;
  static Color get bgColor      => AppColors.bg;
  static Color get cardColor    => AppColors.card;
  static Color get secondaryTxt => AppColors.secondaryText;

  static const String _fHead = AppFonts.heading;
  static const String _fBody = AppFonts.body;
  static const String _fBold = AppFonts.bold;

  static const double _kMaxContentW = 720;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ShopifyProduct> _suggestions = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  Timer? _debounce;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  double _s(double base) => Responsive.of(context, baseW: 375).s(base);

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
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) => Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxContentW),
            child: Column(
              children: [
                _buildSearchBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(_s(8), _s(12), _s(8), _s(10)),
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
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: _s(20).clamp(18.0, 26.0)),
            color: primary,
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          SizedBox(width: _s(4)),
          Expanded(
            child: Container(
              height: _s(44).clamp(42.0, 56.0),
              decoration: BoxDecoration(
                color: cardColor,
                border: Border.all(
                  color: primary.withOpacity(0.15),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                textAlignVertical: TextAlignVertical.center,
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: _s(14).clamp(13.0, 18.0),
                  color: primary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(
                    fontFamily: _fBody,
                    fontSize: _s(14).clamp(13.0, 18.0),
                    color: secondaryTxt.withOpacity(0.6),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: secondaryTxt,
                    size: _s(20).clamp(18.0, 26.0),
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: secondaryTxt,
                            size: _s(18).clamp(16.0, 24.0),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(_s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_rounded,
              size: _s(56).clamp(48.0, 76.0),
              color: primary.withOpacity(0.15),
            ),
            SizedBox(height: _s(16)),
            Text(
              'SEARCH PRODUCTS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(12).clamp(11.0, 16.0),
                fontWeight: FontWeight.w800,
                color: primary.withOpacity(0.35),
              ),
            ),
            SizedBox(height: _s(8)),
            Text(
              'Start typing to find what you\'re looking for',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: _s(12).clamp(11.0, 16.0),
                color: secondaryTxt.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeMoreHint(int currentLength) {
    final remaining = 3 - currentLength;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(_s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Type $remaining more ${remaining == 1 ? 'character' : 'characters'}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: _s(13).clamp(12.0, 17.0),
                color: secondaryTxt.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: _s(6)),
            Text(
              'to see suggestions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: _s(12).clamp(11.0, 16.0),
                color: secondaryTxt.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(_s(16), _s(16), _s(16), _s(24)),
      itemCount: 6,
      separatorBuilder: (_, __) => SizedBox(height: _s(12)),
      itemBuilder: (_, __) => _shimmerTile(),
    );
  }

  Widget _shimmerTile() {
    return Row(
      children: [
        Container(
          width: _s(72).clamp(60.0, 96.0),
          height: _s(88).clamp(74.0, 116.0),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.07),
          ),
        ),
        SizedBox(width: _s(14)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: _s(13).clamp(12.0, 18.0),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.07),
                ),
              ),
              SizedBox(height: _s(8)),
              Container(
                height: _s(11).clamp(10.0, 15.0),
                width: _s(100).clamp(80.0, 160.0),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.05),
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(_s(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: _s(48).clamp(40.0, 66.0),
              color: primary.withOpacity(0.18),
            ),
            SizedBox(height: _s(16)),
            Text(
              'No results for',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: _s(13).clamp(12.0, 17.0),
                color: secondaryTxt.withOpacity(0.55),
              ),
            ),
            SizedBox(height: _s(4)),
            Text(
              '"$query"',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(15).clamp(14.0, 20.0),
                fontWeight: FontWeight.w700,
                color: primary.withOpacity(0.75),
              ),
            ),
            SizedBox(height: _s(10)),
            Text(
              'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: _s(12).clamp(11.0, 16.0),
                color: secondaryTxt.withOpacity(0.4),
              ),
            ),
          ],
        ),
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
            padding: EdgeInsets.fromLTRB(_s(16), _s(14), _s(16), _s(8)),
            child: Text(
              '${_suggestions.length} RESULT${_suggestions.length == 1 ? '' : 'S'}',
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(10).clamp(9.0, 14.0),
                fontWeight: FontWeight.w800,
                color: primary.withOpacity(0.45),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(_s(16), 0, _s(16), _s(32)),
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
        padding: EdgeInsets.symmetric(vertical: _s(12)),
        child: Row(
          children: [
            ClipRRect(
              child: SizedBox(
                width: _s(72).clamp(60.0, 100.0),
                height: _s(88).clamp(74.0, 122.0),
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
                            size: _s(20).clamp(18.0, 26.0),
                          ),
                        ),
                      )
                    : Container(color: primary.withOpacity(0.07)),
              ),
            ),
            SizedBox(width: _s(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: _s(13).clamp(12.0, 18.0),
                      fontWeight: FontWeight.w600,
                      color: primary,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: _s(6)),
                  _priceRow(product),
                  if (product.colorHexCodes.isNotEmpty) ...[
                    SizedBox(height: _s(7)),
                    _colorSwatches(product.colorHexCodes),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: _s(8)),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: _s(13).clamp(12.0, 18.0),
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
        style: TextStyle(
          fontFamily: _fBold,
          fontSize: _s(13).clamp(12.0, 18.0),
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: _s(6),
      children: [
        Text(
          product.formattedPrice,
          style: TextStyle(
            fontFamily: _fBold,
            fontSize: _s(13).clamp(12.0, 18.0),
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        Text(
          product.formattedCompareAtPrice,
          style: TextStyle(
            fontFamily: _fBody,
            fontSize: _s(11).clamp(10.0, 15.0),
            color: secondaryTxt,
            decoration: TextDecoration.lineThrough,
            decorationColor: secondaryTxt,
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
          color = AppColors.border;
        }
        return Container(
          margin: EdgeInsets.only(right: _s(5)),
          width: _s(14).clamp(12.0, 20.0),
          height: _s(14).clamp(12.0, 20.0),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 0.8),
          ),
        );
      }).toList(),
    );
  }
}