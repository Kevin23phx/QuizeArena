/// Format court jj/MM HH:mm, en heure locale. Affichage uniquement :
/// le serveur reste l'autorité pour toutes les dates de quiz.
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}
