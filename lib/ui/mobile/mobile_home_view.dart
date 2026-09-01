import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/persona.dart';
import '../../repositories/persona_repository.dart';
import '../../sync/sync_controller.dart';
import 'mobile_persona_list_view.dart';
import 'mobile_offline_sync_view.dart';
import 'mobile_stats_view.dart';
import 'mobile_profile_view.dart';

class MobileHomeView extends StatefulWidget {
  const MobileHomeView({super.key});

  @override
  State<MobileHomeView> createState() => _MobileHomeViewState();
}

class _MobileHomeViewState extends State<MobileHomeView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final syncController = context.watch<SyncController>();
    final repo = context.watch<PersonaRepository>();

    final pages = [
      const MobilePersonaListView(),
      const MobileOfflineSyncView(),
      MobileStatsView(isOnline: syncController.hasInternet),
      const MobileProfileView(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: StreamBuilder<List<Persona>>(
        stream: repo.watchOfflinePersonas(),
        builder: (context, snapshot) {
          final offlineCount = snapshot.data?.length ?? 0;

          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people, color: Colors.blueAccent),
                label: 'Registros',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: offlineCount > 0,
                  label: Text('$offlineCount'),
                  child: const Icon(Icons.cloud_sync_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: offlineCount > 0,
                  label: Text('$offlineCount'),
                  child: const Icon(Icons.cloud_sync, color: Colors.blueAccent),
                ),
                label: 'Offline',
              ),
              const NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart, color: Colors.blueAccent),
                label: 'Estadísticas',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: Colors.blueAccent),
                label: 'Perfil',
              ),
            ],
          );
        },
      ),
    );
  }
}
