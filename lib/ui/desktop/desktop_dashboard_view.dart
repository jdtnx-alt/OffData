import 'package:flutter/material.dart';
import '../responsive_scaffold.dart';
import '../widgets/network_badge.dart';
import '../widgets/terminal_logs.dart';
import 'desktop_personas_view.dart';

class DesktopDashboardView extends StatefulWidget {
  const DesktopDashboardView({super.key});

  @override
  State<DesktopDashboardView> createState() => _DesktopDashboardViewState();
}

class _DesktopDashboardViewState extends State<DesktopDashboardView> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: 'OffData Desktop Suite',
      actions: const [
        Center(child: NetworkBadge()),
        SizedBox(width: 24),
      ],
      drawer: NavigationRail(
        extended: true,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationRailDestination(
            icon: Icon(Icons.dashboard_outlined), 
            selectedIcon: Icon(Icons.dashboard),
            label: Text('Dashboard'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.people_outline), 
            selectedIcon: Icon(Icons.people),
            label: Text('Personas'),
          ),
          NavigationRailDestination(
            icon: Icon(Icons.sync_outlined), 
            selectedIcon: Icon(Icons.sync),
            label: Text('Sincronización'),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: _selectedIndex == 1 
              ? const DesktopPersonasView() 
              : Container(
                  padding: const EdgeInsets.all(32),
                  child: const Text('Welcome to OffData Dashboard', style: TextStyle(fontSize: 24)),
                ),
          ),
          const VerticalDivider(width: 1),
          const Expanded(
            flex: 1,
            child: TerminalLogs(logs: [
              'System initialized successfully',
              'PowerSync connected to Supabase',
              'Local database: offdata.db',
              'Ready for data entry...',
            ]),
          ),
        ],
      ),
    );
  }
}
