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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OffDataRoot());
}

class OffDataRoot extends StatefulWidget {
  const OffDataRoot({super.key});

  @override
  State<OffDataRoot> createState() => _OffDataRootState();
}

class _OffDataRootState extends State<OffDataRoot> {
  bool _initialized = false;
  String _statusMessage = 'Iniciando OffData...';
  String? _errorMessage;

  AuthProvider? _authProvider;
  SyncController? _syncController;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _errorMessage = null;
      _statusMessage = 'Cargando configuración...';
    });

    try {
      // 1. Cargar .env de forma segura
      try {
        await dotenv.load(fileName: ".env");
      } catch (e) {
        debugPrint('Aviso .env: $e');
      }

      // 2. Iniciar base de datos local (SQLite / PowerSync)
      setState(() => _statusMessage = 'Iniciando base de datos local...');
      final appDb = AppDatabase();
      await appDb.initialize();

      // 3. Crear usuarios predeterminados si la BD está limpia
      setState(() => _statusMessage = 'Verificando cuentas de usuario...');
      final usuarioRepo = UsuarioRepository();
      await usuarioRepo.inicializarUsuariosPorDefecto();

      // 4. Iniciar Supabase en segundo plano sin bloquear
      try {
        await SupabaseService.init();
      } catch (e) {
        debugPrint('Aviso Supabase: $e');
      }

      // 5. Iniciar controladores de sincronización y sesión
      _syncController = SyncController();
      try {
        _syncController!.connect();
      } catch (e) {
        debugPrint('Aviso Sync connect: $e');
      }

      _authProvider = AuthProvider();

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, stack) {
      debugPrint('Error crítico en inicialización: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al Iniciar Base de Datos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _initializeApp,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized || _authProvider == null || _syncController == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.dataset_outlined, size: 38, color: Colors.blueAccent),
                ),
                const SizedBox(height: 20),
                const Text(
                  'OffData',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider!),
        ChangeNotifierProvider.value(value: _syncController!),
        Provider(create: (_) => UsuarioRepository()),
        Provider(create: (_) => PersonaRepository()),
        Provider(create: (_) => ContactoRepository()),
      ],
      child: const OffDataApp(),
    );
  }
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
