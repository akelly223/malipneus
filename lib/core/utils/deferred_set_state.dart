import 'package:flutter/widgets.dart';

/// À mixer dans un State pour remplacer `setState()` par
/// `deferSetState()` quand le changement fait disparaître (ou remplace)
/// le widget qui vient d'être cliqué — typiquement un bouton qui bascule
/// l'affichage d'un formulaire sur le même écran. Faire ce changement
/// tout de suite, dans le même passage que le clic, plante le
/// MouseTracker sur desktop pendant qu'il traite encore cet événement :
/// "'!_debugDuringDeviceUpdate': is not true" (bug Flutter connu et
/// documenté, ex. flutter/flutter#93233). Différer au frame suivant
/// évite ce crash.
mixin DeferredSetStateMixin<T extends StatefulWidget> on State<T> {
  void deferSetState(VoidCallback fn) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(fn);
    });
  }
}
