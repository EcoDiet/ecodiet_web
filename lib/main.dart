import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'pages/login_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/recipe_infos_page.dart';
import 'pages/profile_page.dart';

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
    return MaterialApp(
      title: 'EcoDiet',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5ECD9), // #F5ECD9
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2F6B3F), // #2F6B3F (première couleur principale)
          secondary: Color(0xFFF4A259), // #F4A259 (seconde couleur principale)
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5ECD9),
          iconTheme: IconThemeData(color: Color(0xFFF4A259)),
          titleTextStyle: TextStyle(color: Color(0xFF1F2E1F), fontSize: 18),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF63A96E)), // #63A96E
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
        '/create-account': (context) => const CreateAccountPage(),
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
