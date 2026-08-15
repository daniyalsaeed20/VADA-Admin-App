import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Result of a forward or reverse geocode lookup via the Google Maps
/// JavaScript SDK's `google.maps.Geocoder`.
class GeocodeResult {
  const GeocodeResult({
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    required this.streetAddress,
    this.city = '',
    this.stateCounty = '',
    this.postalCode = '',
    this.country = '',
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String streetAddress;
  final String city;
  final String stateCounty;
  final String postalCode;
  final String country;
}

class GoogleGeocodingException implements Exception {
  GoogleGeocodingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thin wrapper around the Google Maps JavaScript SDK's `Geocoder`, loaded
/// via the `<script>` tag in `web/index.html`. Using the JS SDK (rather than
/// calling the REST Geocoding API directly) avoids browser CORS
/// restrictions, since Google's web-service REST endpoints are not meant to
/// be called from client-side code.
class GoogleGeocodingService {
  const GoogleGeocodingService();

  /// Whether the Maps JS SDK has finished loading on the page.
  bool get isAvailable {
    if (!globalContext.has('google')) {
      return false;
    }
    final google = globalContext['google'] as JSObject?;
    if (google == null || !google.has('maps')) {
      return false;
    }
    final maps = google['maps'] as JSObject?;
    return maps != null && maps.has('Geocoder');
  }

  /// Forward geocode: turn a typed address into coordinates + formatted
  /// address components.
  Future<GeocodeResult?> geocodeAddress(String address) {
    final request = JSObject()..setProperty('address'.toJS, address.toJS);
    return _geocode(request);
  }

  /// Reverse geocode: turn a map point into an address.
  Future<GeocodeResult?> reverseGeocode(double lat, double lng) {
    final location = JSObject()
      ..setProperty('lat'.toJS, lat.toJS)
      ..setProperty('lng'.toJS, lng.toJS);
    final request = JSObject()
      ..setProperty('location'.toJS, location);
    return _geocode(request);
  }

  Future<GeocodeResult?> _geocode(JSObject request) async {
    if (!isAvailable) {
      throw GoogleGeocodingException(
        'Google Maps failed to load. Check that a valid API key is '
        'configured in web/index.html.',
      );
    }
    final geocoderCtor = (globalContext['google'] as JSObject)['maps']
        as JSObject;
    final geocoderClass = geocoderCtor['Geocoder'] as JSFunction;
    final geocoder = geocoderClass.callAsConstructor<JSObject>();

    final JSObject response;
    try {
      final promise =
          geocoder.callMethod<JSPromise<JSObject>>('geocode'.toJS, request);
      response = await promise.toDart;
    } catch (_) {
      throw GoogleGeocodingException(
        'No results found for that location.',
      );
    }

    final results = response['results'] as JSArray<JSAny?>?;
    if (results == null || results.length == 0) {
      return null;
    }
    final result = results[0] as JSObject;
    final geometry = result['geometry'] as JSObject;
    final location = geometry['location'] as JSObject;
    final lat = location.callMethod<JSNumber>('lat'.toJS).toDartDouble;
    final lng = location.callMethod<JSNumber>('lng'.toJS).toDartDouble;
    final formattedAddress = (result['formatted_address'] as JSString?)
            ?.toDart ??
        '';
    final components = result['address_components'] as JSArray<JSAny?>?;
    final streetNumber = _component(components, const ['street_number']);
    final route = _component(components, const ['route']);
    final streetAddress = [
      streetNumber,
      route,
    ].where((part) => part.isNotEmpty).join(' ');

    return GeocodeResult(
      latitude: lat,
      longitude: lng,
      formattedAddress: formattedAddress,
      streetAddress: streetAddress.isNotEmpty ? streetAddress : formattedAddress,
      city: _component(components, const [
        'locality',
        'postal_town',
        'sublocality',
      ]),
      stateCounty: _component(components, const [
        'administrative_area_level_1',
      ]),
      postalCode: _component(components, const ['postal_code']),
      country: _component(components, const ['country']),
    );
  }

  String _component(JSArray<JSAny?>? components, List<String> wantedTypes) {
    if (components == null) {
      return '';
    }
    for (var i = 0; i < components.length; i++) {
      final component = components[i] as JSObject;
      final types = component['types'] as JSArray<JSAny?>?;
      if (types == null) {
        continue;
      }
      for (var j = 0; j < types.length; j++) {
        final type = (types[j] as JSString).toDart;
        if (wantedTypes.contains(type)) {
          final longName = component['long_name'] as JSString?;
          return longName?.toDart ?? '';
        }
      }
    }
    return '';
  }
}
