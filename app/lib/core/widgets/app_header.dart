import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// En-tête turquoise arrondi du design, avec bouton retour optionnel.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 8,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              tooltip: 'Retour',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
