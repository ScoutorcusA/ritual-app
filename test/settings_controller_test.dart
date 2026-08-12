import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/controllers/settings_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('reflection scale choices persist independently', () async {
    final settings = SettingsController();
    await settings.initialize();

    await settings.setHungerScaleEnabled(true);
    await settings.setCravingScaleEnabled(true);

    final reloaded = SettingsController();
    await reloaded.initialize();

    expect(reloaded.hungerScaleEnabled, isTrue);
    expect(reloaded.cravingScaleEnabled, isTrue);
    expect(reloaded.fullnessScaleEnabled, isFalse);
  });
}
