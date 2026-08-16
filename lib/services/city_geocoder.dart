import 'package:flutter/services.dart';

import '../l10n/ritual_i18n.dart';

class CityGeocoderException implements Exception {
  const CityGeocoderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CityGeocoder {
  const CityGeocoder();

  static const _channel = MethodChannel(
    'com.nishkamkhanna.ritual/city_geocoder',
  );

  Future<String> cityAndCountry({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final label = await _channel.invokeMethod<String>('reverseGeocodeCity', {
        'latitude': latitude,
        'longitude': longitude,
      });
      if (label == null || label.trim().isEmpty) {
        throw CityGeocoderException(
          tr('Android did not return a city for this area.'),
        );
      }
      return label.trim();
    } on PlatformException catch (error) {
      throw CityGeocoderException(
        error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : tr('Android could not name this area.'),
      );
    }
  }
}
