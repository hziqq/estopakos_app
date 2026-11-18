import 'package:flutter/material.dart';
import 'screens/public_home_screen.dart';
import 'state/estopa_store.dart';

void main() {
  runApp(const EstopaKosApp());
}

class EstopaKosApp extends StatefulWidget {
  const EstopaKosApp({super.key});

  @override
  State<EstopaKosApp> createState() => _EstopaKosAppState();
}

class _EstopaKosAppState extends State<EstopaKosApp> {
  final EstopaStore _store = EstopaStore();

  @override
  void initState() {
    super.initState();
    _store.syncFromBackend();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Informasi Manajemen Estopa Kos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E), // Teal profesional Estopa Kos
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
      ),
      home: PublicHomeScreen(store: _store),
    );
  }
}
