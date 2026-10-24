import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String bankKey(String name) {
  final value = name.toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e')
      .replaceAll('í', 'i').replaceAll('ó', 'o').replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (value.contains('lafise') || value.contains('bancentro')) return 'lafise';
  if (value.contains('avanz')) return 'avanz';
  if (value.contains('ficohsa')) return 'ficohsa';
  if (value.contains('atlantida')) return 'atlantida';
  if (value.contains('bdf') || value.contains('bancodefinanzas')) return 'bdf';
  if (value.contains('bfp') || value.contains('produzcamos') ||
      value.contains('fomento')) {
    return 'bfp';
  }
  if (value.contains('banpro') || value.contains('promerica') ||
      value.contains('bancodelaproduccion')) {
    return 'banpro';
  }
  if (value.contains('bac') || value.contains('americacentral')) return 'bac';
  return '';
}

List<Color> bankGradient(String name) => switch (bankKey(name)) {
  'bac' => const [Color(0xFF790D19), Color(0xFFE31837)],
  'banpro' => const [Color(0xFF064D35), Color(0xFF23874D)],
  'lafise' => const [Color(0xFF003D35), Color(0xFF00866A)],
  'avanz' => const [Color(0xFF8A182F), Color(0xFFD7891F)],
  'bdf' => const [Color(0xFF064779), Color(0xFF056EB5)],
  'ficohsa' => const [Color(0xFF00357D), Color(0xFF0058CB)],
  'atlantida' => const [Color(0xFF991B23), Color(0xFFDC242D)],
  'bfp' => const [Color(0xFF005780), Color(0xFF009B96)],
  _ => const [Color(0xFF153368), Color(0xFF2563EB)],
};

class BankLogo extends StatelessWidget {
  const BankLogo({
    super.key, required this.name, this.width = 110, this.height = 32,
    this.fallbackIcon = Icons.account_balance_outlined,
  });
  final String name;
  final double width, height;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final key = bankKey(name);
    final path = switch (key) {
      'banpro' => 'assets/banks/banpro.webp',
      'atlantida' => 'assets/banks/atlantida.png',
      'bac' || 'lafise' || 'avanz' || 'bdf' || 'ficohsa' || 'bfp'
      => 'assets/banks/$key.svg',
      _ => null,
    };
    return SizedBox(
      width: width, height: height,
      child: path == null
          ? Icon(fallbackIcon, color: const Color(0xFF2563EB))
          : path.endsWith('.svg')
          ? SvgPicture.asset(path, fit: BoxFit.contain, semanticsLabel: name)
          : Image.asset(path, fit: BoxFit.contain, semanticLabel: name),
    );
  }
}