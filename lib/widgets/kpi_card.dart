import 'package:flutter/material.dart';
import '../config/theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final Color? valueColor;
  final IconData? icon;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: navyLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: navyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: textMuted),
                const SizedBox(width: 4),
              ],
              Text(label,
                  style: const TextStyle(color: textMuted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(color: textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
