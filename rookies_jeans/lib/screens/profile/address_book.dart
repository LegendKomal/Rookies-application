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

  String? _selectedId;
  bool _isSettingDefault = false;

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

    return Scaffold(
      backgroundColor: _bg,
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
                'ADDRESS BOOK',
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
        actions: [
          if (!isPickMode)
            TextButton(
              onPressed: _openAddAddress,
              child: Text(
                'Add',
                style: TextStyle(
                  fontFamily: _fBold,
                  fontSize: 14,
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

          return Stack(
            children: [
              ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  16, 16, 16,
                  isPickMode ? 100 : 16,
                ),
                itemCount: addresses.length + (isPickMode ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (isPickMode && i == addresses.length) {
                    return _addNewTile();
                  }
                  return _addressCard(addresses[i], isPickMode: isPickMode);
                },
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: _border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: canConfirm ? _confirmPick : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFCCCCCC),
                          elevation: 0,
                          shape: const RoundedRectangleBorder(),
                        ),
                        child: const Text(
                          'DELIVER HERE',
                          style: TextStyle(
                            fontFamily: _fBold,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPickMode)
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 10),
                  child: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isSelected ? _primary : const Color(0xFFBBBBBB),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 10),
                  child: Icon(
                    address.isDefault
                        ? Icons.home_rounded
                        : Icons.location_on_outlined,
                    size: 20,
                    color: address.isDefault ? _primary : _secondaryTx,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.fullName,
                            style: const TextStyle(
                              fontFamily: _fBold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ),
                        if (address.isDefault)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            color: _primary.withOpacity(0.1),
                            child: Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontFamily: _fBold,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.formattedAddress,
                      style: const TextStyle(
                        fontFamily: _fBody,
                        fontSize: 12,
                        color: _secondaryTx,
                        height: 1.5,
                      ),
                    ),
                    if (address.phone.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        address.phone,
                        style: const TextStyle(
                          fontFamily: _fBody,
                          fontSize: 12,
                          color: _secondaryTx,
                        ),
                      ),
                    ],
                    if (!isPickMode) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (!address.isDefault)
                            _actionButton(
                              label: 'Set Default',
                              icon: Icons.check_circle_outline_rounded,
                              color: _primary,
                              onTap: () => _setDefault(address),
                            ),
                          if (!address.isDefault) const SizedBox(width: 14),
                          _actionButton(
                            label: 'Edit',
                            icon: Icons.edit_outlined,
                            color: const Color(0xFF555555),
                            onTap: () => _openEditAddress(address),
                          ),
                          const SizedBox(width: 14),
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
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: _fBold,
                fontSize: 11,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.add_location_alt_outlined, size: 20, color: _primary),
              const SizedBox(width: 10),
              Text(
                'Add New Address',
                style: TextStyle(
                  fontFamily: _fBold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFBBBBBB)),
            ],
          ),
        ),
      );

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 14),
            const Text(
              'No saved addresses',
              style: TextStyle(
                fontFamily: _fHead,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: _primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add an address for faster checkout',
              style: TextStyle(
                fontFamily: _fBody,
                fontSize: 12,
                color: _secondaryTx,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _openAddAddress,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Address',
                  style: TextStyle(
                    fontFamily: _fBold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _errorState(String error) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: Color(0xFFBBBBBB)),
            const SizedBox(height: 12),
            Text(
              error,
              style: const TextStyle(
                fontFamily: _fBody,
                fontSize: 13,
                color: _secondaryTx,
              ),
            ),
            const SizedBox(height: 16),
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
      );
}