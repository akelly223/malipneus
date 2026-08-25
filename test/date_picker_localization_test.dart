import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Régression pour le bug "écran rouge au clic sur une date" : tous les
/// champs date de l'app appellent showDatePicker(locale: Locale('fr','FR'))
/// (chargements, achats, ventes, dépenses, absences, avances, paie,
/// règlements...). Sans flutter_localizations + supportedLocales déclarés
/// sur MaterialApp, cette locale ne peut pas être résolue et
/// DatePickerDialog plante avec "No MaterialLocalizations found".
void main() {
  Widget appAvecChampDate({required bool localizationConfiguree}) {
    final bouton = Builder(
      builder: (context) => ElevatedButton(
        onPressed: () => showDatePicker(
          context: context,
          initialDate: DateTime(2026, 1, 15),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          locale: const Locale('fr', 'FR'),
        ),
        child: const Text('Choisir une date'),
      ),
    );

    if (!localizationConfiguree) {
      // Reproduit fidèlement la config d'origine de lib/app/app.dart :
      // aucun localizationsDelegates/supportedLocales déclaré.
      return MaterialApp(home: Scaffold(body: bouton));
    }

    // Reproduit la config corrigée de lib/app/app.dart.
    return MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR')],
      locale: const Locale('fr', 'FR'),
      home: Scaffold(body: bouton),
    );
  }

  testWidgets(
      'sans flutter_localizations configuré, ouvrir le date picker fr_FR '
      'plante (reproduit le bug signalé)', (tester) async {
    await tester.pumpWidget(appAvecChampDate(localizationConfiguree: false));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNotNull);
  });

  testWidgets(
      'avec flutter_localizations + supportedLocales fr_FR (config '
      "corrigée de app.dart), le date picker s'ouvre sans erreur et "
      'permet de choisir une autre date', (tester) async {
    await tester.pumpWidget(appAvecChampDate(localizationConfiguree: true));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    // Choisir le 20 janvier 2026 dans la grille de jours puis valider.
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
