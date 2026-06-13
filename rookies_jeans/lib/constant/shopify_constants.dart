class ShopifyConstants {
  ShopifyConstants._();

  static const String shopDomain = 'rookies-jeans.myshopify.com';
  static const String storefrontAccessToken = '8127f95aa12da6ed0234550d19abd043';
  static const String apiVersion = '2026-04';

  static String get storefrontEndpoint =>
      'https://$shopDomain/api/$apiVersion/graphql.json';

  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'X-Shopify-Storefront-Access-Token': storefrontAccessToken,
      };

  static const String latestDropHandle       = 'new-arrivals';
  static const String cargosHandle           = 'cargos';
  static const String jeansHandle            = 'jeans';
  static const String shirtsHandle           = 'shirts';
  static const String tshirtsHandle          = 'TSHIRTS';
  static const String linensHandle           = 'linens';
  static const String shortsHandle           = 'shorts';
  static const String hotDealsHandle         = 'hot-deals';
  static const String summerEditHandle       = 'summer-edit';
  static const String trendingNowHandle      = 'trending-now';
  static const String balloonCargosHandle    = 'BALLOON FIT CARGO';
  static const String oversizedShirtsHandle  = 'oversized-shirts';

  static const List<Map<String, String>> exploreCategories = [
    {'handle': cargosHandle,   'label': 'CARGOS'},
    {'handle': jeansHandle,    'label': 'JEANS'},
    {'handle': shirtsHandle,   'label': 'SHIRTS'},
    {'handle': tshirtsHandle,  'label': 'T-SHIRTS'},
    {'handle': linensHandle,   'label': 'LINENS'},
    {'handle': shortsHandle,   'label': 'SHORTS'},
  ];

  static const List<Map<String, String>> latestDropCollections = [
    {'handle': tshirtsHandle,  'label': 'Oversized Tees'},
    {'handle': cargosHandle,   'label': 'Balloon Fit Pants'},
    {'handle': linensHandle,   'label': 'Linens'},
    {'handle': shortsHandle,   'label': 'Shorts'},
    {'handle': jeansHandle,    'label': 'Jeans'},
    {'handle': shirtsHandle,   'label': 'Shirts'},
    {'handle': balloonCargosHandle, 'label': 'Balloon Fit Pants'},
  ];

  static const List<Map<String, String>> ourCollectionTiles = [
    {'handle': summerEditHandle,  'label': 'SUMMER EDIT'},
    {'handle': hotDealsHandle,    'label': 'HOT DEALS'},
    {'handle': trendingNowHandle, 'label': 'TRENDING NOW'},
  ];

  static const int latestDropCount      = 6;
  static const int hotDealsCount        = 4;
  static const int oversizedShirtsCount = 10;

  static const int primaryColorHex   = 0xFF111111;
  static const int accentOrangeHex   = 0xFFFF6B00;
  static const int bgColorHex        = 0xFFF5F5F5;
  static const int cardColorHex      = 0xFFFFFFFF;
  static const int secondaryTextHex  = 0xFF6B6B6B;
  static const int borderColorHex    = 0xFFDDDDDD;
}