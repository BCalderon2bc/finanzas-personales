import 'package:flutter/material.dart';

const categoryIconOptions = {
  'category': (Icons.category_outlined, 'General'),
  'food': (Icons.restaurant_outlined, 'Alimentación'),
  'groceries': (Icons.shopping_cart_outlined, 'Supermercado'),
  'transport': (Icons.directions_car_outlined, 'Transporte'),
  'home': (Icons.home_outlined, 'Hogar'),
  'health': (Icons.favorite_border_rounded, 'Salud'),
  'education': (Icons.school_outlined, 'Educación'),
  'shopping': (Icons.shopping_bag_outlined, 'Compras'),
  'entertainment': (Icons.sports_esports_outlined, 'Entretenimiento'),
  'travel': (Icons.flight_outlined, 'Viajes'),
  'pets': (Icons.pets_outlined, 'Mascotas'),
  'services': (Icons.bolt_outlined, 'Servicios'),
  'phone': (Icons.phone_android_outlined, 'Telefonía'),
  'work': (Icons.work_outline_rounded, 'Trabajo'),
  'salary': (Icons.payments_outlined, 'Salario'),
  'business': (Icons.storefront_outlined, 'Negocio'),
  'gift': (Icons.card_giftcard_outlined, 'Regalos'),
  'savings': (Icons.savings_outlined, 'Ahorro'),
};

const categoryColorOptions = [
  '#2563EB', '#7C3AED', '#DB2777', '#DC2626',
  '#C2410C', '#A16207', '#047857', '#0F766E',
  '#0369A1', '#475569',
];

IconData categoryIcon(dynamic key) {
  final option = categoryIconOptions[key?.toString()];
  return option == null ? Icons.category_outlined : option.$1;
}

Color categoryColor(dynamic value, {bool income = false}) {
  final hex = value?.toString().replaceAll('#', '').trim() ?? '';
  if (RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(hex)) {
    return Color(int.parse('FF$hex', radix: 16));
  }
  return income ? const Color(0xFF047857) : const Color(0xFF2563EB);
}