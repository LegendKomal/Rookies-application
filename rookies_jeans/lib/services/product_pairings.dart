/// Which collections feed the "Goes Well With" and "You May Also Like" rows,
/// picked from a product's handle/title. Shared by the product page and cart.
class ProductPairings {
  ProductPairings._();

  /// Category -> collections whose products pair with it.
  static const Map<String, List<String>> _goesWellWith = {
    'shirt': ['ss26-loose-fit-jeans', 'ss26-bootcutjeans', 'baloon-fit-pants'],
    'tshirt': ['ss26-loose-fit-jeans', 'baloon-fit-pants'],
    'jeans': ['ss26-tshirts-oversize-fit-half-sleeve', 'oversized-shirts'],
    'pants': ['ss26-tshirts-oversize-fit-half-sleeve', 'oversized-shirts'],
    'linen': ['ss26-loose-fit-jeans', 'baloon-fit-pants'],
  };

  static String detectCategory(String handle, String title) {
    final combined = '$handle $title'.toLowerCase();
    if (combined.contains('shirt')) return 'shirt';
    if (combined.contains('tshirt') ||
        combined.contains('t-shirt') ||
        combined.contains('tee')) {
      return 'tshirt';
    }
    if (combined.contains('jean') || combined.contains('denim')) return 'jeans';
    if (combined.contains('pant') ||
        combined.contains('trouser') ||
        combined.contains('cargo')) {
      return 'pants';
    }
    if (combined.contains('linen')) return 'linen';
    return 'shirt';
  }

  static List<String> goesWellWithCollections(String category) =>
      _goesWellWith[category] ?? const [];

  /// The collection a product of [category] most likely belongs to.
  static String sameCollectionHandle(String category, String handle) {
    switch (category) {
      case 'shirt':
        return handle.contains('oversized')
            ? 'oversized-shirts'
            : 'ss26-linens';
      case 'tshirt':
        return 'ss26-tshirts-oversize-fit-half-sleeve';
      case 'jeans':
        return handle.contains('loose')
            ? 'ss26-loose-fit-jeans'
            : 'ss26-bootcutjeans';
      case 'pants':
        return 'baloon-fit-pants';
      case 'linen':
        return 'ss26-linens';
      default:
        return 'all';
    }
  }
}
