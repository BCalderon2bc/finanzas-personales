import 'core/appearance.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tzafbupjhxrqgeptiust.supabase.co',
    publishableKey: 'sb_publishable_IBVixyyRA3n97aBh2GUN_A_zAsGal8S',
  );

  await AppearanceController.instance.load();
  runApp(const FinanzasApp());
}
