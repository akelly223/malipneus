import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app.dart';
import 'app/providers/launch_file_provider.dart';
import 'app/providers/licence_provider.dart';
import 'core/container/temp_workspace_service.dart';
import 'core/licence/licence_config.dart';
import 'core/licence/licence_service.dart';
import 'core/licence/licence_write_guard.dart';

/// Diagnostic temporaire : la toute première exception (Flutter ou Dart)
/// est noyée en pratique dans les centaines de répétitions de l'erreur
/// MouseTracker qui la suivent une fois `_debugDuringDeviceUpdate` resté
/// bloqué à `true`. Ce marqueur ne change AUCUN comportement (l'erreur
/// est toujours affichée normalement ensuite) : il rend juste la
/// première occurrence facile à repérer/copier dans la console.
bool _premiereErreurDejaSignalee = false;

void _signalerPremiereErreur(String origine, Object error, StackTrace? stack) {
  if (_premiereErreurDejaSignalee) return;
  _premiereErreurDejaSignalee = true;
  dev.log(
    '\n'
    '=========================== PREMIÈRE ERREUR ($origine) ===========================\n'
    '$error\n'
    '$stack\n'
    '====================================================================================\n',
    name: 'MaliPneus.diagnostic',
  );
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Requis par `CloseSaveGuard` (lib/presentation/container/widgets/
  // close_save_guard.dart) pour intercepter le bouton X et forcer une
  // sauvegarde du conteneur .mstk ouvert avant de quitter réellement.
  await windowManager.ensureInitialized();

  // Sûr uniquement parce que le mutex d'instance unique (côté natif,
  // windows/runner/main.cpp) a déjà garanti qu'aucune autre instance
  // de MaliPneus ne tourne avant même que ce code Dart ne s'exécute :
  // tout dossier "mstk_session_*" encore présent ne peut venir que
  // d'un crash précédent.
  await TempWorkspaceService.nettoyerDossiersOrphelins();

  final cheminLancement = args.isNotEmpty ? args.first : null;

  // Essai / licence : calculé avant tout affichage pour que le verrou
  // lecture seule (LicenceWriteGuard) soit posé avant l'ouverture d'un
  // fichier. En cas d'erreur imprévue, on reste en essai plutôt que de
  // bloquer un client honnête.
  final serviceLicence = LicenceService.windows();
  EtatLicence etatLicence;
  try {
    etatLicence = await serviceLicence.charger();
  } catch (_) {
    etatLicence = EtatLicence(
      statut: StatutLicence.essai,
      codePc: serviceLicence.codePc,
      joursRestants: LicenceConfig.joursEssai,
    );
  }
  LicenceWriteGuard.lectureSeule = etatLicence.lectureSeule;

  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _signalerPremiereErreur('FlutterError', details.exception, details.stack);
    (originalOnError ?? FlutterError.presentError)(details);
  };

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            licenceServiceProvider.overrideWithValue(serviceLicence),
            etatLicenceInitialProvider.overrideWithValue(etatLicence),
            if (cheminLancement != null)
              launchFileProvider.overrideWithValue(cheminLancement),
          ],
          child: const MaliPneusApp(),
        ),
      );
    },
    (error, stack) {
      _signalerPremiereErreur('Zone non gérée', error, stack);
    },
  );
}
