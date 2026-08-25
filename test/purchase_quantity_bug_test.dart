import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/app/providers/repository_providers.dart';
import 'package:mali_pneus/app/providers/session_provider.dart';
import 'package:mali_pneus/data/local/database.dart';
import 'package:mali_pneus/data/repositories/purchase_repository_impl.dart';
import 'package:mali_pneus/domain/entities/purchase_cart_item_input.dart';
import 'package:mali_pneus/domain/entities/user.dart';
import 'package:mali_pneus/presentation/purchases/purchase_form_screen.dart';

/// Régression du bug audité : modifier la quantité d'une ligne d'achat en
/// effaçant le champ puis en retapant un nombre (comportement normal d'un
/// utilisateur qui sélectionne tout et retape) perdait la saisie — le
/// champ vidé momentanément déclenchait une valeur de repli (1) qui,
/// réinjectée dans le widget, écrasait le contrôleur texte PENDANT que
/// l'utilisateur tapait encore (voir _PurchaseLineTileState.didUpdateWidget
/// dans purchase_form_screen.dart). Ce test reproduit exactement cette
/// séquence (champ vidé puis retapé progressivement) et vérifie la
/// quantité réellement enregistrée EN BASE, pas seulement à l'écran.
void main() {
  // Cet écran a un débordement de layout préexistant (InputDecorator des
  // champs Fournisseur/Qté/Prix trop étroits sur ce banc de test), sans
  // rapport avec le bug de quantité testé ici : on le neutralise pour ne
  // pas faire échouer le test sur un problème cosmétique déjà présent
  // avant ce correctif.
  void ignorerDebordementsConnus(WidgetTester tester) {
    while (tester.takeException() != null) {}
  }

  Future<AppDatabase> creerBase() async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    return db;
  }

  Future<void> pumperFormulaire(
    WidgetTester tester,
    AppDatabase db,
    int userId,
    int purchaseId,
  ) async {
    // Le formulaire d'achat (dropdowns fournisseur/magasin + lignes
    // qté/prix) déborde sur la taille par défaut du banc de test —
    // agrandit la surface, comme pour le même type de débordement déjà
    // rencontré sur le menu latéral (voir sidebar_menu_widget_test.dart).
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWith((ref) => SessionNotifier()
            ..setUser(UserEntity(
              id: userId,
              nom: 'Responsable',
              login: 'resp',
              role: 'admin',
              actif: true,
              dateCreation: DateTime(2026),
            ))),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('fr', 'FR')],
          locale: const Locale('fr', 'FR'),
          home: PurchaseFormScreen(purchaseId: purchaseId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ignorerDebordementsConnus(tester);
  }

  /// Simule un utilisateur qui sélectionne tout le champ Qté, l'efface
  /// (état vide transitoire — le déclencheur exact du bug audité), puis
  /// retape le nouveau nombre progressivement.
  Future<void> retaperQuantite(WidgetTester tester, String nouvelleValeur) async {
    // Le champ Qté est identifié par son InputDecoration labelText 'Qté'.
    final finder = find.byWidgetPredicate((w) =>
        w is TextField && w.decoration?.labelText == 'Qté');
    expect(finder, findsOneWidget);

    await tester.enterText(finder, '');
    await tester.pump();
    ignorerDebordementsConnus(tester);
    var partiel = '';
    for (final caractere in nouvelleValeur.split('')) {
      partiel += caractere;
      await tester.enterText(finder, partiel);
      await tester.pump();
      ignorerDebordementsConnus(tester);
    }
  }

  testWidgets(
      'effacer puis retaper la quantité (500) l\'enregistre correctement '
      'en base, sans troncature', (tester) async {
    final db = await creerBase();
    addTearDown(db.close);

    final storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Magasin principal'),
        );
    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Responsable',
            login: 'resp',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final supplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(nom: 'Fournisseur Test'),
        );
    final articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
              code: 'ART-QTE', nom: 'Article test quantité', prixVente: 9000),
        );

    final purchaseRepo = PurchaseRepositoryImpl(db);
    final purchaseId = await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Article test quantité',
          quantite: 50,
          prixAchatUnitaire: 1000,
        ),
      ],
    );

    await pumperFormulaire(tester, db, userId, purchaseId);

    // 1/10/50/100/500/1000 : chaque nouvelle valeur remplace la
    // précédente en passant par un état vide, comme un utilisateur qui
    // sélectionne tout puis retape.
    for (final valeur in ['1', '10', '50', '100', '500', '1000']) {
      await retaperQuantite(tester, valeur);
      final champQte = find.byWidgetPredicate((w) =>
          w is TextField && w.decoration?.labelText == 'Qté');
      final texteAffiche =
          (tester.widget<TextField>(champQte)).controller!.text;
      expect(texteAffiche, valeur,
          reason: 'le champ affiché doit refléter fidèlement la saisie, '
              'pas une valeur tronquée par une resynchronisation');
    }

    // Valeur finale : 1000. Enregistre et vérifie EN BASE (pas
    // seulement à l'écran).
    final bouton = find.widgetWithText(ElevatedButton, 'Enregistrer les modifications');
    await tester.ensureVisible(bouton);
    await tester.tap(bouton);
    await tester.pumpAndSettle();
    ignorerDebordementsConnus(tester);
    expect(find.text('Confirmer la modification ?'), findsOneWidget,
        reason: 'la boîte de dialogue de confirmation doit s\'ouvrir');
    await tester.tap(find.text('Confirmer la modification'));
    await tester.pumpAndSettle();
    ignorerDebordementsConnus(tester);

    final lignes = await db.purchasesDao.getItemsForPurchase(purchaseId);
    expect(lignes, hasLength(1));
    expect(lignes.single.quantite, 1000);
    expect(lignes.single.totalLigne, 1000 * 1000);

    // Le stock doit refléter la nouvelle quantité (50 initiaux → 1000).
    final stock =
        await db.articlesDao.getStockForArticleInStore(articleId, storeId);
    expect(stock, 1000);

    final achat = await purchaseRepo.getPurchaseById(purchaseId);
    expect(achat!.totalFinal, 1000 * 1000);
  });

  testWidgets('diminuer la quantité après sauvegarde recalcule bien le stock',
      (tester) async {
    final db = await creerBase();
    addTearDown(db.close);

    final storeId = await db.into(db.stores).insert(
          StoresCompanion.insert(nom: 'Magasin principal'),
        );
    final userId = await db.into(db.users).insert(
          UsersCompanion.insert(
            nom: 'Responsable',
            login: 'resp',
            motDePasseHash: 'x',
            role: 'admin',
          ),
        );
    final supplierId = await db.into(db.suppliers).insert(
          SuppliersCompanion.insert(nom: 'Fournisseur Test'),
        );
    final articleId = await db.into(db.articles).insert(
          ArticlesCompanion.insert(
              code: 'ART-QTE2', nom: 'Article test 2', prixVente: 9000),
        );

    final purchaseRepo = PurchaseRepositoryImpl(db);
    final purchaseId = await purchaseRepo.createPurchase(
      supplierId: supplierId,
      storeId: storeId,
      userId: userId,
      items: [
        PurchaseCartItemInput(
          articleId: articleId,
          articleNom: 'Article test 2',
          quantite: 500,
          prixAchatUnitaire: 2000,
        ),
      ],
    );

    await pumperFormulaire(tester, db, userId, purchaseId);
    await retaperQuantite(tester, '20');

    final bouton = find.widgetWithText(ElevatedButton, 'Enregistrer les modifications');
    await tester.ensureVisible(bouton);
    await tester.tap(bouton);
    await tester.pumpAndSettle();
    ignorerDebordementsConnus(tester);
    expect(find.text('Confirmer la modification ?'), findsOneWidget,
        reason: 'la boîte de dialogue de confirmation doit s\'ouvrir');
    await tester.tap(find.text('Confirmer la modification'));
    await tester.pumpAndSettle();
    ignorerDebordementsConnus(tester);

    final lignes = await db.purchasesDao.getItemsForPurchase(purchaseId);
    expect(lignes.single.quantite, 20);

    final stock =
        await db.articlesDao.getStockForArticleInStore(articleId, storeId);
    expect(stock, 20); // 500 annulés puis 20 réappliqués
  });
}
