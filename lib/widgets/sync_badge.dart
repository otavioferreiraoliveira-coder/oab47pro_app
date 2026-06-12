import 'package:flutter/material.dart';
import '../config/theme.dart';

class SyncBadge extends StatelessWidget {
  final bool synced;
  const SyncBadge({super.key, required this.synced});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: synced ? green : textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}
