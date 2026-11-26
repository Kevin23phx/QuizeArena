import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Décoration commune des champs de saisie. `errorText` reçoit l'erreur 422
/// du serveur pour le champ concerné (ValidationFailure.fieldErrors).
InputDecoration appInput(String label, {String? errorText, String? hint}) {
  OutlineInputBorder border(Color color, [double width = 1.5]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary, 2),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error, 2),
  );
}
