import 'package:flutter_test/flutter_test.dart';
import 'package:ritual/services/debug_log_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('persists copyable diagnostics without journal details', () async {
    final log = DebugLogService();
    await log.record('location', 'attempt 1 started; provider=fused');
    await log.record('location', 'position timed out; fallback=false');

    final copied = await DebugLogService().copyableText();

    expect(copied, contains('provider=fused'));
    expect(copied, contains('position timed out'));
    expect(copied, contains('coordinates are not logged'));
  });
}
