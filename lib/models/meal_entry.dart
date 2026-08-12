import 'dart:typed_data';

enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeLabel on MealType {
  String get label => switch (this) {
    MealType.breakfast => 'Breakfast',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
    MealType.snack => 'Snack',
  };

  String get prompt => switch (this) {
    MealType.breakfast => 'A gentle start',
    MealType.lunch => 'A midday pause',
    MealType.dinner => 'The day at your table',
    MealType.snack => 'A little moment',
  };
}

const feelingLabels = <String>[
  'Happy',
  'Calm',
  'Energized',
  'Comforted',
  'Satisfied',
  'Social',
  'Rushed',
  'Distracted',
  'Still hungry',
];

class MealEntry {
  const MealEntry({
    required this.id,
    required this.imagePath,
    required this.mealType,
    required this.feelings,
    required this.note,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.hungerLevel,
    this.fullnessLevel,
    this.cravingLevel,
  });

  final int id;
  final String imagePath;
  final MealType mealType;
  final List<String> feelings;
  final String note;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final int? hungerLevel;
  final int? fullnessLevel;
  final int? cravingLevel;

  bool get hasLocation => latitude != null && longitude != null;

  MealEntry copyWith({
    MealType? mealType,
    List<String>? feelings,
    String? note,
    double? latitude,
    double? longitude,
    String? locationLabel,
    bool clearCoordinates = false,
    bool clearLocationLabel = false,
    int? hungerLevel,
    int? fullnessLevel,
    int? cravingLevel,
    bool clearHungerLevel = false,
    bool clearFullnessLevel = false,
    bool clearCravingLevel = false,
  }) {
    return MealEntry(
      id: id,
      imagePath: imagePath,
      mealType: mealType ?? this.mealType,
      feelings: feelings ?? this.feelings,
      note: note ?? this.note,
      createdAt: createdAt,
      latitude: clearCoordinates ? null : latitude ?? this.latitude,
      longitude: clearCoordinates ? null : longitude ?? this.longitude,
      locationLabel: clearLocationLabel
          ? null
          : locationLabel ?? this.locationLabel,
      hungerLevel: clearHungerLevel ? null : hungerLevel ?? this.hungerLevel,
      fullnessLevel: clearFullnessLevel
          ? null
          : fullnessLevel ?? this.fullnessLevel,
      cravingLevel: clearCravingLevel
          ? null
          : cravingLevel ?? this.cravingLevel,
    );
  }
}

class MealDraft {
  const MealDraft({
    required this.imagePath,
    required this.mealType,
    required this.feelings,
    required this.note,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.locationLabel,
    this.hungerLevel,
    this.fullnessLevel,
    this.cravingLevel,
  });

  final String imagePath;
  final MealType mealType;
  final List<String> feelings;
  final String note;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final int? hungerLevel;
  final int? fullnessLevel;
  final int? cravingLevel;
}

class MealImport {
  const MealImport({
    required this.draft,
    required this.photoBytes,
    required this.photoExtension,
    required this.fingerprint,
  });

  final MealDraft draft;
  final Uint8List photoBytes;
  final String photoExtension;
  final String fingerprint;
}
