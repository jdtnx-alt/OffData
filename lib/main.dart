import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'config/responsive.dart';
import 'database/app_database.dart';
import 'providers/auth_provider.dart';
import 'sync/supabase_service.dart';
import 'sync/sync_controller.dart';
import 'repositories/persona_repository.dart';
import 'repositories/contacto_repository.dart';
import 'repositories/usuario_repository.dart';
import 'ui/auth/login_view.dart';
import 'ui/mobile/mobile_home_view.dart';
import 'ui/desktop/desktop_dashboard_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not loaded: $e');
  }
  
  // 1. Initialize Supabase Connection
  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Warning: Supabase init error: $e');
  }

  // 2. Initialize Database Singleton
  try {
    final appDb = AppDatabase();
    await appDb.initialize();

    // Initialize default users if not existing
    final usuarioRepo = UsuarioRepository();
    await usuarioRepo.inicializarUsuariosPorDefecto();
  } catch (e) {
    debugPrint('Warning: Database init error: $e');
  }
  
  // 3. Setup Sync Controller
  final syncController = SyncController();
  try {
    syncController.connect();
  } catch (e) {
    debugPrint('Warning: Sync connect error: $e');
  }

  final authProvider = AuthProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: syncController),
        Provider(create: (_) => UsuarioRepository()),
        Provider(create: (_) => PersonaRepository()),
        Provider(create: (_) => ContactoRepository()),
      ],
      child: const OffDataApp(),
    ),
  );
}

class OffDataApp extends StatelessWidget {
  const OffDataApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'OffData',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es', ''),
        Locale('en', ''),
      ],
      home: !auth.initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.isLoggedIn
              ? const Responsive(
                  mobile: MobileHomeView(),
                  desktop: DesktopDashboardView(),
                )
              : const LoginView(),
    );
  }
}
