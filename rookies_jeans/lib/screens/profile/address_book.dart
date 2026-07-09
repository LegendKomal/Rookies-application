import 'package:flutter/material.dart';
import 'package:rookies_jeans/constant/shopify_constants.dart';
import 'package:rookies_jeans/models/address_model.dart';
import 'package:rookies_jeans/screens/profile/add_edit.dart';
import 'package:rookies_jeans/services/address_service.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key, this.pickMode = false});

  final bool pickMode;

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  static const _primary     = Color(ShopifyConstants.primaryColorHex);
  static const _bg          = Color(0xFFF5F5F3);
  static const _cardColor   = Colors.white;
  static const _border      = Color(0xFFEEEEEE);
  static const _secondaryTx = Color(0xFF777777);
  static const _deleteRed   = Color(0xFFD32F2F);

  static const _fHead = ShopifyConstants.fontHeading;
  static const _fBody = ShopifyConstants.fontBody;
  static const _fBold = ShopifyConstants.fontBodyBold;

  // Layout tuning.
  static const double _kBaseWidth   = 375; // reference design width.
  static const double _kMaxContentW = 640; // cap content on tablets/desktop.

  String? _selectedId;
  bool _isSettingDefault = false;

  /// Width-based scale factor, clamped so text never gets too tiny or huge.
  double _sf(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return (w / _kBaseWidth).clamp(0.85, 1.35);
  }

  /// Scaled size helper.
  double _s(BuildContext c, double base) => base * _sf(c);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AddressService.instance.fetchAddresses();
      if (mounted && widget.pickMode) {
        final def = AddressService.instance.addresses
            .where((a) => a.isDefault)
            .firstOrNull;
        setState(() =>
            _selectedId = def?.id ?? AddressService.instance.addresses.firstOrNull?.id);
      }
    });
  }

  Future<void> _openAddAddress() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AddEditAddressScreen(),
      ),
    );
    if (saved == true && mounted && widget.pickMode) {
      final addresses = AddressService.instance.addresses;
      if (_selectedId == null && addresses.isNotEmpty) {
        setState(() => _selectedId = addresses.last.id);
      }
    }
  }

  Future<void> _openEditAddress(ShopifyAddress address) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditAddressScreen(address: address),
      ),
    );
  }

  Future<void> _confirmDelete(ShopifyAddress address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(),
        title: const Text(
          'Delete Address',
          style: TextStyle(fontFamily: _fBold, fontSize: 16),
        ),
        content: Text(
          'Remove "${address.shortAddress}" from your address book?',
          style: const TextStyle(fontFamily: _fBody, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: _fBody,
                color: _secondaryTx,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: _fBold, color: _deleteRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await AddressService.instance.deleteAddress(address.id);
    if (!mounted) return;
    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      if (_selectedId == address.id) {
        setState(() => _selectedId =
            AddressService.instance.addresses.firstOrNull?.id);
      }
      _showSnackBar('Address removed');
    }
  }

  Future<void> _setDefault(ShopifyAddress address) async {
    if (address.isDefault) return;
    setState(() => _isSettingDefault = true);
    final ok = await AddressService.instance.setDefaultAddress(address.id);
    if (mounted) {
      setState(() => _isSettingDefault = false);
      if (!ok) {
        _showSnackBar('Could not set default address.', isError: true);
      } else {
        _showSnackBar('Default address updated');
      }
    }
  }

  void _confirmPick() {
    if (_selectedId == null) return;
    final address = AddressService.instance.addresses
        .where((a) => a.id == _selectedId)
        .firstOrNull;
    Navigator.of(context).pop(address);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(fontFamily: _fBody, color: Colors.white)),
        backgroundColor: isError ? _deleteRed : _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPickMode = widget.pickMode;
    final media = MediaQuery.of(context);
    // Responsive app bar height (also grows a bit with the user's text scale).
    final toolbarHeight =
        (_s(context, 72)).clamp(64.0, 104.0) * media.textScaler.scale(1).clamp(1.0, 1.3);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: const Color(ShopifyConstants.bgColorHex),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: toolbarHeight,
        titleSpacing: 0,
        title: Padding(
          padding: EdgeInsets.only(left: _s(context, 12), right: _s(context, 16)),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: _s(context, 22).clamp(20.0, 30.0),
                  color: const Color(ShopifyConstants.primaryColorHex),
                ),
              ),
              SizedBox(width: _s(context, 10)),
              // Flexible + FittedBox lets the big display title shrink to fit
              // on very narrow screens instead of overflowing.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ADDRESS BOOK',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: _s(context, 34).clamp(26.0, 46.0),
                      height: 1,
                      fontFamily: _fHead,
                      color: const Color(ShopifyConstants.primaryColorHex),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isPickMode)
            TextButton(
              onPressed: _openAddAddress,
              child: Text(
                'Add',
                style: TextStyle(
                  fontFamily: _fBold,
                  fontSize: _s(context, 14).clamp(13.0, 18.0),
                  color: _primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AddressService.instance,
        builder: (context, _) {
          final svc       = AddressService.instance;
          final addresses = svc.addresses;

          if (svc.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          }

          if (svc.error != null && addresses.isEmpty) {
            return _errorState(svc.error!);
          }

          if (addresses.isEmpty) {
            return _emptyState();
          }

          final pad = _s(context, 16);
          return Stack(
            children: [
              // Center + max width keeps lines readable on tablets/desktop.
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxContentW),
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      pad, pad, pad,
                      isPickMode ? _s(context, 100) : pad,
                    ),
                    itemCount: addresses.length + (isPickMode ? 1 : 0),
                    separatorBuilder: (_, __) => SizedBox(height: _s(context, 10)),
                    itemBuilder: (_, i) {
                      if (isPickMode && i == addresses.length) {
                        return _addNewTile();
                      }
                      return _addressCard(addresses[i], isPickMode: isPickMode);
                    },
                  ),
                ),
              ),
              if (_isSettingDefault)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x33FFFFFF),
                    child: Center(
                      child: CircularProgressIndicator(color: _primary),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: widget.pickMode
          ? AnimatedBuilder(
              animation: AddressService.instance,
              builder: (_, __) {
                final canConfirm = _selectedId != null &&
                    AddressService.instance.addresses.isNotEmpty;
                return Container(
                  padding: EdgeInsets.fromLTRB(
                      _s(context, 16), _s(context, 12), _s(context, 16), _s(context, 16)),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _kMaxContentW),
                        child: SizedBox(
                          width: double.infinity,
                          height: _s(context, 50).clamp(46.0, 64.0),
                          child: ElevatedButton(
                            onPressed: canConfirm ? _confirmPick : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFFCCCCCC),
                              elevation: 0,
                              shape: const RoundedRectangleBorder(),
                            ),
                            child: Text(
                              'DELIVER HERE',
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: _s(context, 14).clamp(13.0, 18.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          : null,
    );
  }

  Widget _addressCard(ShopifyAddress address, {required bool isPickMode}) {
    final isSelected = isPickMode && _selectedId == address.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border.all(
          color: isSelected ? _primary : const Color(0xFFDDDDDD),
          width: isSelected ? 1.8 : 0.8,
        ),
      ),
      child: InkWell(
        onTap: isPickMode
            ? () => setState(() => _selectedId = address.id)
            : null,
        child: Padding(
          padding: EdgeInsets.all(_s(context, 14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPickMode)
                Padding(
                  padding: EdgeInsets.only(top: 1, right: _s(context, 10)),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: _s(context, 20).clamp(18.0, 26.0),
                    color: isSelected ? _primary : const Color(0xFFBBBBBB),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.only(top: 1, right: _s(context, 10)),
                  child: Icon(
                    address.isDefault
                        ? Icons.home_rounded
                        : Icons.location_on_outlined,
                    size: _s(context, 20).clamp(18.0, 26.0),
                    color: address.isDefault ? _primary : _secondaryTx,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            address.fullName,
                            style: TextStyle(
                              fontFamily: _fBold,
                              fontSize: _s(context, 13).clamp(12.0, 18.0),
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ),
                        if (address.isDefault)
                          Container(
                            margin: EdgeInsets.only(left: _s(context, 8)),
                            padding: EdgeInsets.symmetric(
                                horizontal: _s(context, 7), vertical: _s(context, 2)),
                            color: _primary.withOpacity(0.1),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: _s(context, 9).clamp(8.0, 12.0),
                                fontWeight: FontWeight.w700,
                                color: _primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: _s(context, 4)),
                    Text(
                      address.formattedAddress,
                      style: TextStyle(
                        fontFamily: _fBody,
                        fontSize: _s(context, 12).clamp(11.0, 16.0),
                        color: _secondaryTx,
                        height: 1.5,
                      ),
                    ),
                    if (address.phone.isNotEmpty) ...[
                      SizedBox(height: _s(context, 3)),
                      Text(
                        address.phone,
                        style: TextStyle(
                          fontFamily: _fBody,
                          fontSize: _s(context, 12).clamp(11.0, 16.0),
                          color: _secondaryTx,
                        ),
                      ),
                    ],
                    if (!isPickMode) ...[
                      SizedBox(height: _s(context, 10)),
                      // Wrap prevents the action buttons from overflowing on
                      // narrow screens; they flow to the next line instead.
                      Wrap(
                        spacing: _s(context, 14),
                        runSpacing: _s(context, 8),
                        children: [
                          if (!address.isDefault)
                            _actionButton(
                              label: 'Set Default',
                              icon: Icons.check_circle_outline_rounded,
                              color: _primary,
                              onTap: () => _setDefault(address),
                            ),
                          _actionButton(
                            label: 'Edit',
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF555555),
                            onTap: () => _openEditAddress(address),
                          ),
                          _actionButton(
                            label: 'Delete',
                            icon: Icons.delete_outline_rounded,
                            color: _deleteRed,
                            onTap: () => _confirmDelete(address),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: _s(context, 14).clamp(13.0, 18.0), color: color),
            SizedBox(width: _s(context, 3)),
            Text(
              label,
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: _s(context, 11).clamp(10.0, 15.0),
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );

  Widget _addNewTile() => InkWell(
        onTap: _openAddAddress,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: _s(context, 14), vertical: _s(context, 16)),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.add_location_alt_outlined,
                  size: _s(context, 20).clamp(18.0, 26.0), color: _primary),
              SizedBox(width: _s(context, 10)),
              Flexible(
                child: Text(
                  'Add New Address',
                  style: TextStyle(
                    fontFamily: _fBold,
                    fontSize: _s(context, 13).clamp(12.0, 18.0),
                    fontWeight: FontWeight.w600,
                    color: _primary,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded,
                  size: _s(context, 18).clamp(16.0, 24.0),
                  color: const Color(0xFFBBBBBB)),
            ],
          ),
        ),
      );

  Widget _emptyState() => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(_s(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_outlined,
                  size: _s(context, 52).clamp(44.0, 72.0),
                  color: Colors.grey.shade300),
              SizedBox(height: _s(context, 14)),
              Text(
                'No saved addresses',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fHead,
                  fontSize: _s(context, 20).clamp(18.0, 28.0),
                  fontWeight: FontWeight.w500,
                  color: _primary,
                ),
              ),
              SizedBox(height: _s(context, 6)),
              Text(
                'Add an address for faster checkout',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: _s(context, 12).clamp(11.0, 16.0),
                  color: _secondaryTx,
                ),
              ),
              SizedBox(height: _s(context, 24)),
              SizedBox(
                height: _s(context, 46).clamp(44.0, 60.0),
                child: ElevatedButton.icon(
                  onPressed: _openAddAddress,
                  icon: Icon(Icons.add_rounded, size: _s(context, 18).clamp(16.0, 24.0)),
                  label: Text(
                    'Add Address',
                    style: TextStyle(
                      fontFamily: _fBold,
                      fontSize: _s(context, 14).clamp(13.0, 18.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(),
                    padding: EdgeInsets.symmetric(horizontal: _s(context, 24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _errorState(String error) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(_s(context, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: _s(context, 48).clamp(40.0, 66.0),
                  color: const Color(0xFFBBBBBB)),
              SizedBox(height: _s(context, 12)),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: _fBody,
                  fontSize: _s(context, 13).clamp(12.0, 17.0),
                  color: _secondaryTx,
                ),
              ),
              SizedBox(height: _s(context, 16)),
              ElevatedButton(
                onPressed: () => AddressService.instance.fetchAddresses(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}