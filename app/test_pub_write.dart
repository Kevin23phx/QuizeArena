import 'dart:io';

void main() {
  final path = Platform.environment['TEMP'];
  final file = File('$path\\dart_test.txt');

  print('Chemin : ${file.path}');

  try {
    file.writeAsStringSync('Dart fonctionne');
    print('Ecriture reussie !');
    print('Fichier existe : ${file.existsSync()}');
  } catch (e) {
    print('Erreur : $e');
  }
}
