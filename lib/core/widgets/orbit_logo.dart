import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class OrbitLogo extends StatelessWidget {
  const OrbitLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        AppConstants.appLogoPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: 'Orbit app logo',
      ),
    );
  }
}
