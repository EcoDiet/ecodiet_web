import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'pages/profil_page.dart';
import 'pages/creer_compte_page.dart';
import 'pages/home_page.dart';
import 'pages/historique_page.dart';
import 'services/mongodb_service.dart';

final logger = Logger(
  level: Level.debug,
  printer: PrettyPrinter(),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await MongoDBService.connect(); // Connexion à MongoDB au démarrage
    logger.i('Connexion à MongoDB établie');
  } catch (e) {
    logger.e('Erreur de connexion à MongoDB : $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoDiet',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFBF4E4),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFEA853D),
          secondary: const Color(0xFF6DA157),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBF4E4),
          iconTheme: IconThemeData(color: Color(0xFFEA853D)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6DA157)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6DA157), width: 2),
          ),
          prefixIconColor: const Color(0xFFEA853D),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = const HistoriquePage();
        break;
      case 1:
        page = const HomePage();
        break;
      case 2:
        page = const ProfilPage();
        break;
      default:
        throw UnimplementedError('Page non trouvée');
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        selectedItemColor: const Color(0xFFEA853D),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
