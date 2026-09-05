import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({this.maxWidth = 340, super.key});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Barbatum, Barberia Sartoriale',
      image: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/branding/barbatum_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.content_cut_rounded, size: 20),
        SizedBox(width: 10),
        Text('BARBATUM'),
      ],
    );
  }
}
