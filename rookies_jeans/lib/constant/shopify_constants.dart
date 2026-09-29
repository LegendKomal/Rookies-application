import 'package:flutter/material.dart';

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

  static const String storeUrl      = 'https://rookiesjeans.com';
  static const String shiprocketUrl  = 'https://rookiesjeans.shiprocket.co/';

  static const String fontHeading  = 'BebasNene';
  static const String fontBody     = 'AlteHaasGroteskRegular';
  static const String fontBodyBold = 'SplineSansMono';
  static const String fontAlteBold = 'AlteHaasGroteskBold';
  static const String fontNumber = 'Typist';
  static const String fontRupee = 'Serif4';

  static const TextStyle tsHeading = TextStyle(
    fontFamily: fontHeading,
    color: Color(primaryColorHex),
  );

  static const TextStyle tsBody = TextStyle(
    fontFamily: fontBody,
    color: Color(primaryColorHex),
  );

  static const TextStyle tsBold = TextStyle(
    fontFamily: fontBodyBold,
    color: Color(primaryColorHex),
  );

  static const String latestDropHandle       = 'new-arrivals';
  static const String cargosHandle           = 'CARGOS';
  static const String jeansHandle            = 'JEANS';
  static const String shirtsHandle           = 'SHIRTS';
  static const String tshirtsHandle          = 'TSHIRTS';
  static const String linensHandle           = 'LINENS';
  static const String shortsHandle           = 'SHORTS';
  static const String hotDealsHandle         = 'hot-deals';
  static const String summerEditHandle       = 'summer-edit';
  static const String trendingNowHandle      = 'trending-now';
  static const String balloonCargosHandle    = 'BALLOON FIT CARGO';
  static const String oversizedShirtsHandle  = 'oversized-shirts';

  /// The Collections tab's "Shop by category" taxonomy: tab → group → card.
  /// Every card is a real Shopify collection (by handle); images come live
  /// from each collection (its image, else its first product's). The
  /// Storefront API can't list menus, so the grouping/order is pinned here.
  /// A group's own `handle` is opened when its title is tapped ('' = none).
  static const List<Map<String, Object>> exploreMenuSections = [
    {
      'title': 'Top Wear',
      'groups': [
        {
          'title': 'Shirts',
          'handle': 'shirts',
          'items': [
            {'title': 'Cargo Shirts', 'handle': 'cargo-shirts'},
            {'title': 'Check Shirts', 'handle': 'check-shirts'},
            {'title': 'Stripe Shirts', 'handle': 'stripe-shirts'},
            {'title': 'Denim Shirts', 'handle': 'denim-shirts-1'},
            {'title': 'Corduroy Shirts', 'handle': 'corduroy-shirts'},
            {'title': 'Pure Linen Shirts', 'handle': 'pure-linen-shirts'},
            {'title': 'Solid Shirts', 'handle': 'solid-shirts'},
            {'title': 'Printed Shirts', 'handle': 'printed-shirts'},
            {'title': 'Textured Shirts', 'handle': 'textured-shirts'},
            {'title': 'Half Sleeve Shirts', 'handle': 'half-sleeve-shirts'},
            {'title': 'Linen-Blend Shirts', 'handle': 'linen-shirts'},
          ],
        },
        {
          'title': 'T-Shirts',
          'handle': 'tshirts',
          'items': [
            {'title': 'Regular T-Shirts', 'handle': 'regular-tshirts'},
            {'title': 'Oversized T-Shirts', 'handle': 'oversized-tshirts'},
            {'title': 'Polo T-Shirts', 'handle': 'polo-tshirts'},
            {'title': 'Full-Sleeve T-Shirts', 'handle': 'full-sleeve-tshirts'},
          ],
        },
        {
          'title': 'Jackets',
          'handle': 'jacket',
          'items': [
            {'title': 'Denim Jackets', 'handle': 'denim-jackets'},
            {'title': 'Utility Jackets', 'handle': 'utility-jackets'},
            {'title': 'Suede Jackets', 'handle': 'suede-jackets'},
            {'title': 'Puffer Jackets', 'handle': 'puffer-jackets'},
            {'title': 'Leather Jackets', 'handle': 'leather-jackets'},
            {'title': 'Light Jackets', 'handle': 'light-jackets'},
            {'title': 'Shackets', 'handle': 'shackets'},
          ],
        },
        {
          'title': 'Knits & Sweats',
          'handle': 'flatknit-sweaters',
          'items': [
            {'title': 'Sweatshirts', 'handle': 'sweatshirts'},
            {'title': 'Hoodies', 'handle': 'hoodies'},
            {'title': 'Flatknits', 'handle': 'flatknits'},
            {'title': 'Sweaters', 'handle': 'sweaters'},
          ],
        },
        {
          'title': 'Kurtas & Co-ords',
          'handle': '',
          'items': [
            {'title': 'Kurtas', 'handle': 'kurtas'},
            {'title': 'Co-ord Sets', 'handle': 'co-ords'},
          ],
        },
      ],
    },
    {
      'title': 'Bottom Wear',
      'groups': [
        {
          'title': 'Jeans',
          'handle': 'jeans',
          'items': [
            {'title': 'Jann (Loose Stretch)', 'handle': 'jeans-jann'},
            {'title': 'Jesse (Straight Stretch)', 'handle': 'jeans-jesse'},
            {'title': 'Lennon (Slim Stretch)', 'handle': 'jeans-lennon'},
            {'title': 'Mojo (Baggy / Oversized)', 'handle': 'jeans-mojo'},
            {'title': 'Nikki (Signature Bootcut)', 'handle': 'jeans-nikki'},
            {'title': 'Springsteen (Ankle Tapered)', 'handle': 'jeans-springsteen'},
          ],
        },
        {
          'title': 'Cargos & Pants',
          'handle': 'cargos',
          'items': [
            {'title': 'Cargo Pants', 'handle': 'cargo-pants'},
            {'title': 'Balloon Fit Cargos', 'handle': 'balloon-fit-cargos'},
            {'title': 'Utility Pants', 'handle': 'utility-pants'},
            {'title': 'Linen Cargos', 'handle': 'linen-cargos'},
            {'title': 'Denim Cargo', 'handle': 'denim-cargo'},
            {'title': 'Chinos', 'handle': 'chinos'},
            {'title': 'Korean Fit Trousers', 'handle': 'korean-fit-trousers'},
            {'title': 'Linen Trousers', 'handle': 'linen-trousers'},
            {'title': 'Casual Pants', 'handle': 'casual-pants'},
          ],
        },
        {
          'title': 'Shorts',
          'handle': 'shorts',
          'items': [
            {'title': 'Cargo Shorts', 'handle': 'cargo-shorts'},
            {'title': 'Linen Shorts', 'handle': 'linen-shorts'},
            {'title': 'Jorts', 'handle': 'jorts'},
          ],
        },
      ],
    },
  ];

  static const List<Map<String, String>> exploreCategories = [
    {'handle': cargosHandle,   'label': 'CARGOS'},
    {'handle': jeansHandle,    'label': 'JEANS'},
    {'handle': shirtsHandle,   'label': 'SHIRTS'},
    {'handle': tshirtsHandle,  'label': 'TSHIRTS'},
    {'handle': linensHandle,   'label': 'LINENS'},
    {'handle': 'CHINOS',       'label': 'CHINOS'},
    {'handle': shortsHandle,   'label': 'SHORTS'},
    {'handle': 'polo-tees',    'label': 'POLO TEES'},
  ];

  static const List<Map<String, String>> latestDropCollections = [
    {'handle': tshirtsHandle,       'label': 'Oversized Tees'},
    {'handle': cargosHandle,        'label': 'Balloon Fit Pants'},
    {'handle': linensHandle,        'label': 'Linens'},
    {'handle': shortsHandle,        'label': 'Shorts'},
    {'handle': jeansHandle,         'label': 'Jeans'},
    {'handle': shirtsHandle,        'label': 'Shirts'},
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