import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({this.maxWidth = 340, super.key});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Alessio Garreffa Hair',
      image: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/branding/agh_primary.png',
                width: 230,
                height: 230,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
              const SizedBox(height: 10),
              Text(
                'ALESSIO  GARREFFA',
                style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 4.2),
              ),
              const SizedBox(height: 5),
              Text(
                'H A I R',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 7,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'HAIR IS A FORM OF EXPRESSION.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 8,
                  letterSpacing: 2.1,
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    return Semantics(
      label: 'Alessio Garreffa Hair',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ALESSIO GARREFFA',
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              fontFamily: 'Cinzel',
              fontWeight: FontWeight.w600,
              letterSpacing: 2.2,
            ),
          ),
          Text(
            'H A I R',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: 8,
              letterSpacing: 3.5,
            ),
          ),
        ],
      ),
    );
  }
}
