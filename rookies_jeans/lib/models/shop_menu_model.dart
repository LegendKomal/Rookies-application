// Models for the Shopify Storefront navigation menus used to drive the
// "Explore Categories" accordion (see ShopifyStorefrontService.getExploreMenuSections).
//
// Shopify's admin lets merchants manage a "Top Wear" menu and a "Bottom Wear"
// menu (each a flat list of category items, e.g. Shirts, Jeans...). Each of
// those category items links to a collection ("/collections/shirts"), and
// separately the merchant maintains one more flat menu per collection handle
// (e.g. a menu literally handled "shirts") whose items are that category's
// fits (Boxy fit, Loose fit, ...). We stitch those two levels together here
// so the whole taxonomy stays editable from Shopify without an app release.

class ShopMenuFit {
  final String title;
  final String url;

  /// Handle of the collection this item links to (e.g. "cargo-shirts"), when
  /// the menu item points at a collection.
  final String? collectionHandle;

  /// The collection's image, or its first product's image when the
  /// collection has none.
  final String? imageUrl;

  const ShopMenuFit({
    required this.title,
    required this.url,
    this.collectionHandle,
    this.imageUrl,
  });
}

class ShopMenuCategory {
  final String title;
  final String collectionHandle;
  final List<ShopMenuFit> fits;

  /// The category collection's image (or its first product's image).
  final String? imageUrl;

  const ShopMenuCategory({
    required this.title,
    required this.collectionHandle,
    this.fits = const [],
    this.imageUrl,
  });
}

class ShopMenuSection {
  final String title;
  final String handle;
  final List<ShopMenuCategory> categories;

  const ShopMenuSection({
    required this.title,
    required this.handle,
    this.categories = const [],
  });
}
