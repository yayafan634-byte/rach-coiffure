import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth/auth_provider.dart';
import 'auth/login_screen.dart';
import 'navigation/app_section.dart';
import 'screens/admin/gestion_users.dart';
import 'screens/admin/historique_screen.dart';
import 'screens/caisse/caisse_screen.dart';
import 'screens/clients/clients_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/rdv/rdv_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/stock/stock_screen.dart';
import 'services/cloud_sync.dart';
import 'theme/app_theme.dart';
import 'utils/son.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SonService.instance.initialiser();
  await CloudSync.instance.init();
  await CloudSync.instance.synchroniser();
  final auth = AuthProvider();
  await auth.creerPremierAdmin();
  runApp(MyApp(auth: auth));
}

class MyApp extends StatefulWidget {
  final AuthProvider auth;
  const MyApp({super.key, required this.auth});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      CloudSync.instance.pushMaintenant();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.auth,
      child: MaterialApp(
        title: 'Rach Coiffure',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const LoginScreen(),
        routes: {
          AppSection.dashboard.route: (_) => const DashboardScreen(),
          AppSection.stock.route: (_) => const StockScreen(),
          AppSection.clients.route: (_) => const ClientsScreen(),
          AppSection.caisse.route: (_) => const CaisseScreen(),
          AppSection.rdv.route: (_) => const RdvScreen(),
          AppSection.stats.route: (_) => const StatsScreen(),
          AppSection.utilisateurs.route: (_) => const GestionUsersScreen(),
          AppSection.historique.route: (_) => const HistoriqueScreen(),
        },
      ),
    );
  }
}
