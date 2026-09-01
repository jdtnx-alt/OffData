import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../sync/sync_controller.dart';

class NetworkBadge extends StatelessWidget {
  const NetworkBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final syncController = context.watch<SyncController>();
    final hasInternet = syncController.hasInternet;
    final isSyncing = syncController.isSyncing;

    final Color badgeColor = hasInternet
        ? (isSyncing ? Colors.blueAccent : Colors.green)
        : Colors.orange;

    final IconData badgeIcon = hasInternet
        ? (isSyncing ? Icons.sync : Icons.cloud_done)
        : Icons.cloud_off;

    final String badgeText = hasInternet
        ? (isSyncing ? 'SINCRONIZANDO' : 'ONLINE')
        : 'OFFLINE';

    return GestureDetector(
      onTap: () {
        if (hasInternet) {
          syncController.syncNow();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sincronizando datos con la nube...'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sin conexión a Internet. Los datos se guardan localmente.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: badgeColor,
                ),
              )
            else
              Icon(
                badgeIcon,
                size: 13,
                color: badgeColor,
              ),
            const SizedBox(width: 5),
            Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
