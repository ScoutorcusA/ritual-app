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
  });

  final int id;
  final String imagePath;
  final MealType mealType;
  final List<String> feelings;
  final String note;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  MealEntry copyWith({
    MealType? mealType,
    List<String>? feelings,
    String? note,
    double? latitude,
    double? longitude,
    bool clearLocation = false,
  }) {
    return MealEntry(
      id: id,
      imagePath: imagePath,
      mealType: mealType ?? this.mealType,
      feelings: feelings ?? this.feelings,
      note: note ?? this.note,
      createdAt: createdAt,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
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
  });

  final String imagePath;
  final MealType mealType;
  final List<String> feelings;
  final String note;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
}
