
class ShopifyCustomer {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final bool acceptsMarketing;

  ShopifyCustomer({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    required this.acceptsMarketing,
  });

  factory ShopifyCustomer.fromJson(Map<String, dynamic> json) {
    return ShopifyCustomer(
      id: json['id'] ?? '',
      firstName: json['firstName'],
      lastName: json['lastName'],
      email: json['email'],
      phone: json['phone'],
      acceptsMarketing: json['acceptsMarketing'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'acceptsMarketing': acceptsMarketing,
    };
  }

  String get fullName {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isEmpty ? 'Customer' : name;
  }
}