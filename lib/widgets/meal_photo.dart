import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/ritual_theme.dart';

class MealPhoto extends StatelessWidget {
  const MealPhoto({
    super.key,
    required this.path,
    this.borderRadius = 24,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(path),
        fit: fit,
        width: double.infinity,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: RitualColors.mist,
          child: Center(
            child: Icon(Icons.image_not_supported_outlined, size: 36),
          ),
        ),
      ),
    );
  }
}
