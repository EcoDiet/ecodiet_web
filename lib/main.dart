import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'pages/login_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/recipe_infos_page.dart';
import 'pages/profile_page.dart';
import 'pages/quiz_page.dart';
import 'pages/folder_page.dart';
import 'utils/responsive.dart';

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
        scaffoldBackgroundColor: const Color(0xFFF5ECD9), 
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2F6B3F), 
          secondary: Color(0xFFF4A259), 
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
    Widget page = selectedIndex == 0 ? const HomePage() : const ProfilePage();

    if (isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: const Color(0xFFF5ECD9),
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme:
                  const IconThemeData(color: Color(0xFFEA853D)),
              selectedLabelTextStyle:
                  const TextStyle(color: Color(0xFFEA853D)),
              unselectedIconTheme:
                  const IconThemeData(color: Colors.grey),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Image.asset(
                  'lib/assets/logo/EcoDiet-Logo.png',
                  height: 48,
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('Accueil'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profil'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        selectedItemColor: const Color(0xFFEA853D),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
