import 'package:flutter/material.dart';

/// Centraliza o conteúdo e limita a largura máxima.
///
/// No celular ocupa a tela toda; em tablet, web ou celular deitado o conteúdo
/// não fica esticado de ponta a ponta.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 480,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
