import 'dart:io';
import 'package:path/path.dart' as p;
import '../../data/local/database.dart';

/// Copie une pièce justificative de dépense dans le dossier de données
/// de l'application (même principe que [LogoService]), avec un nom de
/// fichier unique par dépense (contrairement au logo, chaque dépense a
/// son propre justificatif, aucun ne doit en écraser un autre).
class ExpenseAttachmentService {
  ExpenseAttachmentService._();

  static Future<String> importerJustificatif(String cheminSource) async {
    final dataDir = Directory(await AppDatabase.getDatabaseDirectory());
    final dir = Directory(p.join(dataDir.path, 'justificatifs_depenses'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final extension = p.extension(cheminSource);
    final horodatage = DateTime.now().microsecondsSinceEpoch;
    final dest = p.join(dir.path, 'justificatif_$horodatage$extension');
    await File(cheminSource).copy(dest);
    return dest;
  }
}
