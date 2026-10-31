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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/branding/agh_primary.png',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ALESSIO GARREFFA',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 3.8),
            ),
            const SizedBox(height: 5),
            Text(
              'H A I R',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                letterSpacing: 7,
              ),
            ),
          ],
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/branding/agh_primary.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALESSIO GARREFFA',
                  maxLines: 1,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontFamily: 'Cinzel',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.8,
                  ),
                ),
                Text(
                  'H A I R',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                    fontSize: 7,
                    letterSpacing: 3.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
