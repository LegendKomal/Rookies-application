import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/screens/profile/profile.dart';
import 'package:rookies_jeans/services/order_service.dart';

/// Shared responsive helpers for the order screens.
/// Scales off screen width (400px baseline) and caps content width so the
/// layout stays comfortable from small phones to tablets/desktop.
class _R {
  _R(BuildContext context) : width = MediaQuery.of(context).size.width;
  final double width;

  double get factor => (width / 400).clamp(0.85, 1.3).toDouble();
  double s(double base) => base * factor;

  static const double maxContentWidth = 720;

  Widget center(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        ),
      );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _primary = Color(ShopifyConstants.primaryColorHex);
  static const _bg      = Color(0xFFF5F5F3);

  final _svc = ShopifyOrderService.instance;

  List<Map<String, dynamic>> _orders = [];
  bool    _isLoading    = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final orders = await _svc.fetchOrders();
      setState(() { _orders = orders; _isLoading = false; });
    } on ShopifyOrderException catch (e) {
      setState(() { _isLoading = false; _errorMessage = e.userMessage; });
    } catch (_) {
      setState(() { _isLoading = false; _errorMessage = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _R(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: const Color(0xFFEEEEEE),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF333333)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order History',
          style: TextStyle(
            fontFamily: ShopifyConstants.fontHeading,
            fontSize: r.s(17),
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111111),
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2))
          : _errorMessage != null
              ? _ErrorState(message: _errorMessage!, onRetry: _load)
              : _orders.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      color: _primary,
                      onRefresh: _load,
                      child: r.center(
                        ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _OrderTile(
                            order: _orders[i],
                            svc: _svc,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => OrderDetailScreen(order: _orders[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order, required this.svc, required this.onTap});

  final Map<String, dynamic> order;
  final ShopifyOrderService  svc;
  final VoidCallback         onTap;

  @override
  Widget build(BuildContext context) {
    final r = _R(context);
    final lineItems  = (order['lineItems']?['edges'] as List?) ?? [];
    final firstItem  = lineItems.isNotEmpty ? lineItems.first['node'] : null;
    final imageUrl   = firstItem?['variant']?['image']?['url'] as String?;
    final itemCount  = lineItems.fold<int>(0, (s, e) => s + ((e['node']['quantity'] as int?) ?? 1));
    final totalPrice = order['currentTotalPrice'] ?? {'amount': '0', 'currencyCode': 'INR'};
    final state      = svc.resolveOrderState(order);
    final isCod      = svc.isCod(order);

    final imgW = r.s(100).clamp(84.0, 140.0);
    final imgH = r.s(120).clamp(100.0, 168.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              // borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? Image.network(imageUrl, width: imgW, height: imgH, fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => _imgPlaceholder(imgW))
                  : _imgPlaceholder(imgW),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order['orderNumber']}',
                    style: TextStyle(
                      fontFamily: ShopifyConstants.fontBodyBold,
                      fontSize: r.s(14),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    svc.formatDate(order['processedAt'] ?? ''),
                    style: TextStyle(
                      fontFamily: ShopifyConstants.fontBody,
                      fontSize: r.s(12),
                      color: const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$itemCount item${itemCount != 1 ? 's' : ''}  •  ${svc.formatPrice(totalPrice)}',
                    style: TextStyle(
                      fontFamily: ShopifyConstants.fontBody,
                      fontSize: r.s(13),
                      color: const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _OrderStateBadge(state: state, isCod: isCod),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFBBBBBB), size: 20),
          ],
        ),
      ),
    );
  }
}

Widget _imgPlaceholder(double size) => Container(
  width: size, height: size,
  color: const Color(0xFFF0F0F0),
  child: const Icon(Icons.image_outlined, size: 24, color: Color(0xFFBBBBBB)),
);

class _OrderStateBadge extends StatelessWidget {
  const _OrderStateBadge({required this.state, required this.isCod});

  final OrderState state;
  final bool       isCod;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case OrderState.cancelled:
        return const _Badge(label: 'Cancelled', color: Color(0xFFD32F2F));
      case OrderState.delivered:
        return const _Badge(label: 'Delivered', color: Color(0xFF2E7D32));
      case OrderState.active:
        // Wrap so the two badges flow to a second line on narrow cards
        // instead of overflowing.
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            const _Badge(label: 'Processing', color: Color(0xFFE65100)),
            _Badge(
              label: isCod ? 'Cash on Delivery' : 'Paid',
              color: isCod ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
            ),
          ],
        );
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    final r = _R(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: ShopifyConstants.fontBody,
          fontSize: r.s(11),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String       message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: ShopifyConstants.fontBody,
                fontSize: 14,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(ShopifyConstants.primaryColorHex),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Retry', style: TextStyle(fontFamily: ShopifyConstants.fontBodyBold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFFBBBBBB)),
          SizedBox(height: 12),
          Text(
            'No orders yet',
            style: TextStyle(fontFamily: ShopifyConstants.fontHeading, fontSize: 16, color: Color(0xFF666666)),
          ),
          SizedBox(height: 6),
          Text(
            'Your order history will appear here.',
            style: TextStyle(fontFamily: ShopifyConstants.fontBody, fontSize: 13, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final Map<String, dynamic> order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _primary = Color(ShopifyConstants.primaryColorHex);
  final _svc = ShopifyOrderService.instance;

  void _openCancelPage() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebViewScreen(
        title: 'Cancel Order',
        url: _svc.orderCancelUrl(widget.order['id'] as String),
      ),
    ));
  }

  void _openTrackOrder() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WebViewScreen(title: 'Track Your Order', url: _svc.orderTrackUrl()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r          = _R(context);
    final order      = widget.order;
    final lineItems  = (order['lineItems']?['edges'] as List?) ?? [];
    final totalPrice = order['currentTotalPrice'] ?? {'amount': '0', 'currencyCode': 'INR'};
    final state      = _svc.resolveOrderState(order);
    final isCod      = _svc.isCod(order);
    final canCancel  = _svc.canCancelOrder(order);
    final btnHeight  = r.s(50).clamp(46.0, 60.0);
    final itemImg    = r.s(64).clamp(56.0, 88.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F3),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: const Color(0xFFEEEEEE),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF333333)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Order #${order['orderNumber']}',
          style: TextStyle(
            fontFamily: ShopifyConstants.fontHeading,
            fontSize: r.s(17),
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111111),
          ),
        ),
        centerTitle: true,
      ),
      body: r.center(
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontFamily: ShopifyConstants.fontHeading,
                        fontSize: r.s(15),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(label: 'Order Number', value: '#${order['orderNumber']}'),
                    _DetailRow(label: 'Placed On',    value: _svc.formatDate(order['processedAt'] ?? '')),
                    _DetailRow(label: 'Total',        value: _svc.formatPrice(totalPrice)),
                    const SizedBox(height: 10),
                    _OrderStateBadge(state: state, isCod: isCod),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Items',
                      style: TextStyle(
                        fontFamily: ShopifyConstants.fontHeading,
                        fontSize: r.s(15),
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...lineItems.asMap().entries.map((entry) {
                      final item     = entry.value['node'] as Map<String, dynamic>;
                      final variant  = item['variant'];
                      final imageUrl = variant?['image']?['url'] as String?;
                      final options  = (variant?['selectedOptions'] as List?) ?? [];
                      final optText  = options.map((o) => '${o['name']}: ${o['value']}').join(' · ');
                      final price    = variant?['price'];

                      return Column(
                        children: [
                          if (entry.key > 0)
                            const Divider(height: 20, thickness: 1, color: Color(0xFFEEEEEE)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: imageUrl != null
                                    ? Image.network(imageUrl, width: itemImg, height: itemImg, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _imgPlaceholder(itemImg))
                                    : _imgPlaceholder(itemImg),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['title'] ?? '',
                                      style: TextStyle(
                                        fontFamily: ShopifyConstants.fontBodyBold,
                                        fontSize: r.s(13),
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF222222),
                                      ),
                                    ),
                                    if (optText.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        optText,
                                        style: TextStyle(
                                          fontFamily: ShopifyConstants.fontBody,
                                          fontSize: r.s(12),
                                          color: const Color(0xFF888888),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 5),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Qty: ${item['quantity'] ?? 1}',
                                          style: TextStyle(
                                            fontFamily: ShopifyConstants.fontBody,
                                            fontSize: r.s(12),
                                            color: const Color(0xFF666666),
                                          ),
                                        ),
                                        if (price != null)
                                          Text(
                                            _svc.formatPrice(price),
                                            style: TextStyle(
                                              fontFamily: ShopifyConstants.fontBodyBold,
                                              fontSize: r.s(13),
                                              fontWeight: FontWeight.w600,
                                              color: _primary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (state == OrderState.cancelled)
                _StatusBanner(
                  icon: Icons.cancel_outlined,
                  label: 'Order Cancelled',
                  color: const Color(0xFFD32F2F),
                )
              else if (state == OrderState.delivered)
                _StatusBanner(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Order Delivered',
                  color: const Color(0xFF2E7D32),
                )
              else ...[
                SizedBox(
                  height: btnHeight,
                  child: ElevatedButton.icon(
                    onPressed: _openTrackOrder,
                    icon: const Icon(Icons.local_shipping_outlined, size: 18),
                    label: Text(
                      'Track My Order',
                      style: TextStyle(
                        fontFamily: ShopifyConstants.fontBodyBold,
                        fontSize: r.s(15),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: btnHeight,
                    child: OutlinedButton.icon(
                      onPressed: _openCancelPage,
                      icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFD32F2F)),
                      label: Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontFamily: ShopifyConstants.fontBodyBold,
                          fontSize: r.s(15),
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD32F2F),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final r = _R(context);
    return Container(
      height: r.s(50).clamp(46.0, 60.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: ShopifyConstants.fontBodyBold,
                fontSize: r.s(15),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final r = _R(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: ShopifyConstants.fontBody,
              fontSize: r.s(13),
              color: const Color(0xFF888888),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: ShopifyConstants.fontBodyBold,
                fontSize: r.s(13),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
              ),
            ),
          ),
        ],
      ),
    );
  }
}