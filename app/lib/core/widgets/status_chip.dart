import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pastille de statut (Publié, Brouillon...).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  const StatusChip.success(this.label, {super.key})
      : background = AppColors.successBg,
        foreground = AppColors.successInk;

  const StatusChip.neutral(this.label, {super.key})
      : background = AppColors.neutralBg,
        foreground = AppColors.neutralInk;

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
