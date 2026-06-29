class ShopifyAddress {
  final String id;
  final String firstName;
  final String lastName;
  final String address1;
  final String address2;
  final String city;
  final String province;
  final String country;
  final String zip;
  final String phone;
  final bool isDefault;

  const ShopifyAddress({
    required this.id,
    this.firstName = '',
    this.lastName = '',
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.province = '',
    this.country = '',
    this.zip = '',
    this.phone = '',
    this.isDefault = false,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  String get formattedAddress {
    final parts = [
      address1,
      if (address2.isNotEmpty) address2,
      city,
      province,
      zip,
      country,
    ].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get shortAddress {
    final parts = [address1, city, province]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  factory ShopifyAddress.fromJson(
    Map<String, dynamic> json, {
    bool isDefault = false,
  }) =>
      ShopifyAddress(
        id: json['id'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        address1: json['address1'] as String? ?? '',
        address2: json['address2'] as String? ?? '',
        city: json['city'] as String? ?? '',
        province: json['province'] as String? ?? '',
        country: json['country'] as String? ?? '',
        zip: json['zip'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        isDefault: isDefault,
      );

  Map<String, dynamic> toMailingAddressInput() => {
        'firstName': firstName,
        'lastName': lastName,
        'address1': address1,
        'address2': address2,
        'city': city,
        'province': province,
        'country': country,
        'zip': zip,
        'phone': phone,
      };

  ShopifyAddress copyWith({
    String? firstName,
    String? lastName,
    String? address1,
    String? address2,
    String? city,
    String? province,
    String? country,
    String? zip,
    String? phone,
    bool? isDefault,
  }) =>
      ShopifyAddress(
        id: id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        address1: address1 ?? this.address1,
        address2: address2 ?? this.address2,
        city: city ?? this.city,
        province: province ?? this.province,
        country: country ?? this.country,
        zip: zip ?? this.zip,
        phone: phone ?? this.phone,
        isDefault: isDefault ?? this.isDefault,
      );
}