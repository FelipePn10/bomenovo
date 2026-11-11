import 'package:flutter/material.dart';

import '../theme.dart';

/// Logo + título mostrados no topo das telas de login e cadastro.
class AppLogo extends StatelessWidget {
  final String title;
  final String subtitle;
  const AppLogo({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: appGradient),
          child: const Icon(Icons.task_alt_rounded, size: 46, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: colors.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
