import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';

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

void main() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _signalerPremiereErreur('FlutterError', details.exception, details.stack);
    (originalOnError ?? FlutterError.presentError)(details);
  };

  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: MaliPneusApp(),
        ),
      );
    },
    (error, stack) {
      _signalerPremiereErreur('Zone non gérée', error, stack);
    },
  );
}
