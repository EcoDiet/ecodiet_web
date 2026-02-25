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

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEA853D).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: const Color(0xFFEA853D).withOpacity(0.3))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? const Color(0xFFEA853D) : const Color(0xFF8FBF97),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFFEA853D) : const Color(0xFF8FBF97),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFF8FBF97), size: 20),
            SizedBox(width: 14),
            Text(
              'Déconnexion',
              style: TextStyle(
                color: Color(0xFF8FBF97),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget page = selectedIndex == 0 ? const HomePage() : const ProfilePage();

    if (isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 220,
              color: const Color(0xFF1F3A24),
              child: Column(
                children: [
                  // Logo + titre
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                    child: Column(
                      children: [
                        Image.asset(
                          'lib/assets/logo/EcoDiet-Logo.png',
                          height: 52,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'EcoDiet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Text(
                          'Mangez naturellement',
                          style: TextStyle(
                            color: Color(0xFF8FBF97),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF2F5435), height: 1),
                  const SizedBox(height: 16),

                  // Navigation items
                  _buildNavItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Accueil',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profil',
                    index: 1,
                  ),

                  const Spacer(),

                  // Déconnexion
                  const Divider(color: Color(0xFF2F5435), height: 1),
                  _buildLogoutButton(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Container(width: 1, color: const Color(0xFFD8D0C0)),
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
