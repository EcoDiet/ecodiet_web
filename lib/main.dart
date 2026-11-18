import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'pages/login_page.dart';
import 'pages/login/reset_password_page.dart';
import 'pages/create_account_page.dart';
import 'pages/home_page.dart';
import 'pages/recipe_infos_page.dart';
import 'pages/profile_page.dart';
import 'pages/quiz_page.dart';
import 'pages/folder_page.dart';
import 'pages/taste_swipe_page.dart';
import 'services/ecodiet_api.dart';
import 'utils/responsive.dart';

final logger = Logger(
  level: Level.debug,
  printer: PrettyPrinter(),
);

/// Instance globale de l'API
final api = EcoDietApi();

Future<void> _loadEnvironment() async {
  if (kIsWeb) {
    try {
      await dotenv.load(
        fileName: kDebugMode ? 'assets/env.development' : 'assets/env.production',
      );
      return;
    } catch (_) {
      await dotenv.load(fileName: 'assets/env.production');
      return;
    }
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    await dotenv.load(fileName: 'assets/env.production');
  }
}

String _environmentValue(String name) {
  var compileTimeValue = '';
  if (name == 'DATA_PROVIDER') {
    compileTimeValue = const String.fromEnvironment('DATA_PROVIDER').trim();
  } else if (name == 'GCP_BRIDGE_URL') {
    compileTimeValue = const String.fromEnvironment('GCP_BRIDGE_URL').trim();
  } else if (name == 'GCP_BRIDGE_API_KEY') {
    compileTimeValue = const String.fromEnvironment('GCP_BRIDGE_API_KEY').trim();
  } else if (name == 'AUTH_URL') {
    compileTimeValue = const String.fromEnvironment('AUTH_URL').trim();
  }
  if (compileTimeValue.isNotEmpty) return compileTimeValue;
  return dotenv.env[name]?.trim() ?? '';
}

/// Adresse demandée au lancement (ex. `/reset_password?token=…`), lue avant
/// que l'écran de chargement ne remette l'adresse du navigateur à `/`.
String _launchRoute = '/';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _launchRoute = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<void> _startup = _initialize();

  Future<void> _initialize() async {
    await _loadEnvironment().timeout(const Duration(seconds: 5));

    final bridgeUrl = _environmentValue('GCP_BRIDGE_URL');
    final bridgeApiKey = _environmentValue('GCP_BRIDGE_API_KEY');
    final useGcpBridge = bridgeUrl.isNotEmpty;

    api.configureDataBridge(
      enabled: useGcpBridge,
      baseUrl: bridgeUrl,
      apiKey: bridgeApiKey,
      authUrl: _environmentValue('AUTH_URL'),
    );
    kDisableNetworkImages = false;
    logger.i(
      'Data provider: gcp_bridge (debug: $kDebugMode)',
    );

    if (!useGcpBridge) {
      throw StateError(
        'Configuration manquante : GCP_BRIDGE_URL non défini.',
      );
    }
    logger.i('Supabase desactive: mode gcp_bridge strict');

  // Restaure la session utilisateur si elle existe.
  try {
    await api.restoreSession().timeout(const Duration(seconds: 5));
  } catch (e) {
    logger.w('Session non restauree au demarrage: $e');
  }

  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorApp('Erreur au démarrage d\'EcoDiet : ${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return const MyApp();
        }
        return const MaterialApp(
          home: Scaffold(
            backgroundColor: Color(0xFFF5ECD9),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2F6B3F)),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.interTextTheme();
    final titleTextTheme = GoogleFonts.montserratTextTheme();

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
        textTheme: mainTextTheme,
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
      initialRoute: _launchRoute != '/'
          ? _launchRoute
          : (api.isLoggedIn ? '/home' : '/login'),
      // L'adresse du navigateur prime : un lien `#/reset_password?token=…`
      // ouvre directement la page du nouveau mot de passe.
      onGenerateInitialRoutes: (initialRoute) {
        final uri = Uri.parse(initialRoute);
        if (uri.path == '/reset_password') {
          return [
            MaterialPageRoute(
              settings: const RouteSettings(name: '/reset_password'),
              builder: (_) =>
                  ResetPasswordPage(token: uri.queryParameters['token'] ?? ''),
            ),
          ];
        }
        final fallback = api.isLoggedIn ? '/home' : '/login';
        final name = _initialRoutes.containsKey(uri.path) ? uri.path : fallback;
        return [
          MaterialPageRoute(
            settings: RouteSettings(name: name),
            builder: _initialRoutes[name]!,
          ),
        ];
      },
      routes: {
        '/login': (context) => const LoginPage(),
        '/create_account': (context) => const CreateAccountPage(),
        '/home': (context) => const MyHomePage(),
        '/profile': (context) => const ProfilePage(),
        '/taste': (context) => const TasteSwipePage(),
        '/recipe': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return RecipeInfosPage(
            id: args?['id'] as String?,
            title: args?['title'] as String?,
            description: args?['description'] as String?,
            duration: args?['duration'] as String?,
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

/// Pages qu'on peut ouvrir directement depuis l'adresse du navigateur (les
/// autres attendent des arguments).
final Map<String, WidgetBuilder> _initialRoutes = {
  '/login': (_) => const LoginPage(),
  '/create_account': (_) => const CreateAccountPage(),
  '/home': (_) => const MyHomePage(),
  '/profile': (_) => const ProfilePage(),
  '/taste': (_) => const TasteSwipePage(),
};

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
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () => setState(() => selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected ? Colors.white : const Color(0xFFF5ECD9),
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFF5ECD9),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Déconnexion',
      child: InkWell(
        onTap: () async {
          await api.logout();
          if (!context.mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.logout, color: Color(0xFFF5ECD9), size: 20),
              SizedBox(width: 14),
              Text(
                'Déconnexion',
                style: TextStyle(
                  color: Color(0xFFF5ECD9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget page = selectedIndex == 0
        ? const HomePage()
        : selectedIndex == 1
            ? const FolderPage(
                id: 'favorites',
                label: 'Favoris',
                color: Color(0xFFEA853D),
                showBackButton: false,
              )
            : const ProfilePage();

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
                          'lib/assets/logo/EcoDiet-Logo-beige.png',
                          height: 52,
                          semanticLabel: 'Logo EcoDiet',
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Mangez naturellement',
                          style: TextStyle(
                            color: Color(0xFFF5ECD9),
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
                    icon: Icons.favorite_border,
                    selectedIcon: Icons.favorite,
                    label: 'Favoris',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: 'Profil',
                    index: 2,
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
      extendBody: true,
      body: page,
      bottomNavigationBar: _buildFloatingNavBar(),
    );
  }

  Widget _buildFloatingNavBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavPillItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Accueil',
                index: 0,
              ),
              _buildNavPillItem(
                icon: Icons.favorite_border_rounded,
                selectedIcon: Icons.favorite_rounded,
                label: 'Favoris',
                index: 1,
              ),
              _buildNavPillItem(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profil',
                index: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavPillItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isSelected = selectedIndex == index;
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: () => setState(() => selectedIndex = index),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEA853D).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSelected ? selectedIcon : icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? const Color(0xFFEA853D)
                    : const Color(0xFFB0B0B0),
                size: 24,
              ),
            ),
            AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isSelected
                    ? Row(
                        children: [
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFFEA853D),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
