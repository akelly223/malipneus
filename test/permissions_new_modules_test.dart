import 'package:flutter_test/flutter_test.dart';
import 'package:mali_pneus/core/permissions/permissions.dart';
import 'package:mali_pneus/domain/entities/user.dart';

/// Vérifie que les nouveaux modules (Personnel, Paie, Commissions,
/// Dépenses, Chargements) sont réservés admin par construction : la
/// liste blanche de [Permissions] n'a pas été modifiée pour les
/// autoriser, donc un employé doit en être exclu par défaut.
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

  const nouveauxModules = [
    '/employees',
    '/payroll',
    '/commissions',
    '/expenses',
    '/loadings',
  ];

  test('un employé n\'accède à aucun des nouveaux modules internes', () {
    for (final route in nouveauxModules) {
      expect(Permissions.peutAccederRoute(employe, route), isFalse,
          reason: 'employé ne devrait pas accéder à $route');
    }
  });

  test('un admin accède à tous les nouveaux modules', () {
    for (final route in nouveauxModules) {
      expect(Permissions.peutAccederRoute(admin, route), isTrue,
          reason: 'admin devrait accéder à $route');
    }
  });
}
