/// Shared structured address fields used by fighters, contacts, and locations.
class AddressFields {
  const AddressFields({
    this.address = '',
    this.city = '',
    this.stateCounty = '',
    this.postalCode = '',
    this.country = '',
  });

  final String address;
  final String city;
  final String stateCounty;
  final String postalCode;
  final String country;

  factory AddressFields.fromMap(Map<String, dynamic> data) {
    return AddressFields(
      address: (data['address'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      stateCounty: (data['stateCounty'] as String?)?.trim() ?? '',
      postalCode: (data['postalCode'] as String?)?.trim() ?? '',
      country: (data['country'] as String?)?.trim() ?? '',
    );
  }

  Map<String, String> toFirestoreMap() {
    return {
      'address': address.trim(),
      'city': city.trim(),
      'stateCounty': stateCounty.trim(),
      'postalCode': postalCode.trim(),
      'country': country.trim(),
    };
  }

  /// Single-line display for tables, chips, and tooltips.
  String get formatted {
    final parts = <String>[
      address.trim(),
      city.trim(),
      stateCounty.trim(),
      postalCode.trim(),
      country.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(', ');
  }

  bool get isEmpty =>
      address.trim().isEmpty &&
      city.trim().isEmpty &&
      stateCounty.trim().isEmpty &&
      postalCode.trim().isEmpty &&
      country.trim().isEmpty;

  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return address.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        stateCounty.toLowerCase().contains(q) ||
        postalCode.toLowerCase().contains(q) ||
        country.toLowerCase().contains(q);
  }
}
