import 'package:flutter/services.dart';

import '../l10n/ritual_i18n.dart';

class LocalFileSaverException implements Exception {
  const LocalFileSaverException(this.message);

  final String message;
}

class LocalFileSaver {
  const LocalFileSaver();

  static const _channel = MethodChannel(
    'com.nishkamkhanna.ritual/local_file_saver',
  );

  Future<bool> save({
    required String sourcePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final saved = await _channel.invokeMethod<bool>('saveFile', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType,
      });
      return saved ?? false;
    } on PlatformException catch (error) {
      throw LocalFileSaverException(
        error.message ?? tr('Android could not save the selected file.'),
      );
    }
  }
}
