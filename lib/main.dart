import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'pages/login_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/recipe_infos_page.dart';
import 'pages/profile_page.dart';
import 'pages/quiz_page.dart';
import 'pages/folder_page.dart';

final logger = Logger(
  level: Level.debug,
  printer: PrettyPrinter(),
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Définir Inter comme base pour tout le texte
    final baseTextTheme = GoogleFonts.interTextTheme();
    
    // 2. Définir Montserrat spécifiquement pour les titres
    final titleTextTheme = GoogleFonts.montserratTextTheme();

    // 3. Fusionner : Appliquer Montserrat aux styles de titres (Display, Headline, Title)
    final mainTextTheme = baseTextTheme.copyWith(
      displayLarge: titleTextTheme.displayLarge,
      displayMedium: titleTextTheme.displayMedium,
      displaySmall: titleTextTheme.displaySmall,
      headlineLarge: titleTextTheme.headlineLarge,
      headlineMedium: titleTextTheme.headlineMedium,
      headlineSmall: titleTextTheme.headlineSmall,
      titleLarge: titleTextTheme.titleLarge,
      titleMedium: titleTextTheme.titleMedium,
      titleSmall: titleTextTheme.titleSmall,
    );

    return MaterialApp(
      title: 'EcoDiet',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5ECD9), 
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2F6B3F), 
          secondary: Color(0xFFF4A259), 
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF5ECD9),
          iconTheme: const IconThemeData(color: Color(0xFFF4A259)),
          titleTextStyle: GoogleFonts.montserrat(
            color: const Color(0xFF1F2E1F),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF63A96E)), 
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF63A96E), width: 2),
          ),
          prefixIconColor: const Color(0xFFF4A259),
        ),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/create_account': (context) => const CreateAccountPage(),
        '/home': (context) => const MyHomePage(),
        '/profile': (context) => const ProfilePage(),
        '/recipe': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return RecipeInfosPage(
            title: args?['title'] as String?,
            description: args?['description'] as String?,
          );
        },
        '/quiz': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return QuizPage(
            id: args?['id'] as String?,
            title: args?['title'] as String?,
            description: args?['description'] as String?,
          );
        },
        '/folder': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return FolderPage(
            id: args?['id'] as String?,
            label: args?['label'] as String?,
            color: args?['color'] as Color?,
          );
        },
      },
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
        page = const HomePage();
        break;
      case 1:
        page = const ProfilePage();
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
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
