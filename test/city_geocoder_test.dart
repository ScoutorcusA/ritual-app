import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/services/city_geocoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.nishkamkhanna.ritual/city_geocoder');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns the broad city and country label from Android', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'reverseGeocodeCity');
          expect(call.arguments, {'latitude': 39.96, 'longitude': -82.99});
          return 'Columbus, United States';
        });

    final result = await const CityGeocoder().cityAndCountry(
      latitude: 39.96,
      longitude: -82.99,
    );
    expect(result, 'Columbus, United States');
  });

  test('surfaces Android geocoder errors instead of hanging', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(
            code: 'geocoder_failed',
            message: 'Service not available',
          );
        });

    await expectLater(
      const CityGeocoder().cityAndCountry(latitude: 39.96, longitude: -82.99),
      throwsA(
        isA<CityGeocoderException>().having(
          (error) => error.message,
          'message',
          'Service not available',
        ),
      ),
    );
  });
}
