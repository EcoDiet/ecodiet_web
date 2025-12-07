import 'package:flutter/material.dart';

class HistoriquePage extends StatelessWidget {
  const HistoriquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HistoriquE')),
      body: const Center(child: Text('Contenu de la page Historique')),
    );
  }
}
