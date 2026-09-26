import 'package:flutter/material.dart';

class StaffAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final Color backgroundColor;
  final Color textColor;
  final double fontSize;

  const StaffAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 20,
    this.backgroundColor = const Color(0xFFEEEEFF),
    this.textColor = const Color(0xFF4345E6),
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'S';

    final Widget fallbackText = Center(
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
          fontSize: fontSize,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: (imageUrl != null && imageUrl!.trim().isNotEmpty)
            ? Image.network(
                imageUrl!.trim(),
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return fallbackText;
                },
              )
            : fallbackText,
      ),
    );
  }
}
