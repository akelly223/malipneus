import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/app/providers/session_provider.dart';
import 'package:mali_pneus/domain/entities/user.dart';
import 'package:mali_pneus/presentation/shell/sidebar_menu.dart';

/// Vérifie ce qu'un compte employé voit réellement dans le menu latéral
/// (widget de production, pas une relecture du code) : exactement les
/// modules listés dans la demande, rien de plus.
void main() {
  final admin = UserEntity(
    id: 1,
    nom: 'Admin',
    login: 'admin',
    role: 'admin',
    actif: true,
    dateCreation: DateTime(2026),
  );

  final employe = UserEntity(
    id: 2,
    nom: 'Employé',
    login: 'employe',
    role: 'employe',
    actif: true,
    dateCreation: DateTime(2026),
  );

  Future<void> pump(WidgetTester tester, UserEntity user) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith((ref) => SessionNotifier()..setUser(user)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SidebarMenu(currentRoute: '/dashboard')),
        ),
      ),
    );
  }

  testWidgets('employé ne voit que Tableau de bord, Ventes, Articles, Clients',
      (tester) async {
    await pump(tester, employe);

    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Ventes'), findsOneWidget);
    expect(find.text('Articles'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);

    expect(find.text('Achats'), findsNothing);
    expect(find.text('Fournisseurs'), findsNothing);
    expect(find.text('Dettes'), findsNothing);
    expect(find.text('Historique paiements'), findsNothing);
    expect(find.text('Stock'), findsNothing);
    expect(find.text('Documents'), findsNothing);
    expect(find.text('Paramètres'), findsNothing);
  });

  testWidgets('admin voit tous les modules', (tester) async {
    // Le menu latéral compte désormais assez d'entrées (Personnel, Paie,
    // Commissions, Dépenses, Chargements...) pour dépasser la hauteur par
    // défaut de la surface de test (600px logiques) : sans agrandir la
    // surface, les entrées en bas de liste (Stock, Documents, Paramètres)
    // ne sont jamais construites par le ListView et le finder ne les
    // trouve pas, alors qu'elles s'affichent normalement dans l'app réelle
    // une fois défilées.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pump(tester, admin);

    for (final label in [
      'Tableau de bord', 'Ventes', 'Achats', 'Articles', 'Clients',
      'Dettes', 'Historique paiements', 'Fournisseurs', 'Stock',
      'Documents', 'Paramètres',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });
}
