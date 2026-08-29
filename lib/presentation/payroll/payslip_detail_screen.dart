import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/providers/repository_providers.dart';
import '../../app/providers/session_provider.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/services/payslip_pdf_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/deferred_set_state.dart';
import '../../domain/entities/payroll.dart';
import '../settings/providers/settings_provider.dart';
import 'providers/payroll_provider.dart';

class PayslipDetailScreen extends ConsumerWidget {
  final int payslipId;
  const PayslipDetailScreen({super.key, required this.payslipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payslipAsync = ref.watch(payslipByIdProvider(payslipId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulletin de paie'),
        actions: [
          payslipAsync.maybeWhen(
            data: (payslip) => payslip == null
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Exporter le bulletin en PDF',
                    onPressed: () => _exporterPdf(context, ref, payslip),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: payslipAsync.when(
        data: (payslip) {
          if (payslip == null) {
            return const Center(child: Text('Bulletin introuvable.'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailCard(payslip: payslip),
                const SizedBox(height: 24),
                _AjustementCard(payslip: payslip),
                const SizedBox(height: 24),
                _ReglementCard(payslip: payslip),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }

  Future<void> _exporterPdf(
      BuildContext context, WidgetRef ref, PayslipEntity payslip) async {
    try {
      final periode = await ref
          .read(payrollPeriodByIdProvider(payslip.payrollPeriodId).future);
      final paiements =
          await ref.read(payslipPaymentsProvider(payslip.id).future);
      final settings = await ref.read(appSettingsProvider.future);
      if (periode == null) {
        throw Exception('Période de paie introuvable.');
      }
      await PayslipPdfService.print(
        payslip: payslip,
        periode: periode,
        paiements: paiements,
        settings: settings,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur export PDF : $e')));
      }
    }
  }
}

class _DetailCard extends StatelessWidget {
  final PayslipEntity payslip;
  const _DetailCard({required this.payslip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(payslip.employeeNomComplet ?? '—', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          _ligne('Salaire de base', payslip.salaireBase),
          _ligne('Jours théoriques', null, texte: payslip.joursTheoriques.toStringAsFixed(0)),
          _ligne('Jours d\'absence', null, texte: payslip.joursAbsence.toStringAsFixed(1)),
          _ligne('Retenue absence', -payslip.retenueAbsence),
          _ligne('Avances déduites', -payslip.avancesDeduites),
          _ligne('Bonus', payslip.bonus),
          _ligne('Autres déductions', -payslip.autresDeductions),
          _ligne('Ajustement manuel', payslip.ajustementManuel),
          if (payslip.justificationAjustement != null &&
              payslip.justificationAjustement!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text('Justification : ${payslip.justificationAjustement}',
                  style: AppTextStyles.caption),
            ),
          const Divider(height: 24),
          Row(
            children: [
              const Expanded(
                  child: Text('Salaire net', style: AppTextStyles.bodyBold)),
              Text(CurrencyFormatter.format(payslip.salaireNet),
                  style: AppTextStyles.bodyBold
                      .copyWith(fontSize: 18, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligne(String label, double? montant, {String? texte}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.caption)),
            Text(
              texte ??
                  (montant != null ? CurrencyFormatter.format(montant) : ''),
              style: AppTextStyles.body,
            ),
          ],
        ),
      );
}

class _AjustementCard extends ConsumerStatefulWidget {
  final PayslipEntity payslip;
  const _AjustementCard({required this.payslip});

  @override
  ConsumerState<_AjustementCard> createState() => _AjustementCardState();
}

class _AjustementCardState extends ConsumerState<_AjustementCard>
    with DeferredSetStateMixin<_AjustementCard> {
  bool _showForm = false;
  late final bonusCtrl =
      TextEditingController(text: widget.payslip.bonus.toStringAsFixed(0));
  late final deductionsCtrl = TextEditingController(
      text: widget.payslip.autresDeductions.toStringAsFixed(0));
  late final ajustementCtrl = TextEditingController(
      text: widget.payslip.ajustementManuel.toStringAsFixed(0));
  final justificationCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Ajustements manuels', style: AppTextStyles.h3)),
              if (!_showForm)
                AppButton(
                  label: 'Modifier',
                  isOutlined: true,
                  onPressed: () => deferSetState(() => _showForm = true),
                ),
            ],
          ),
          if (_showForm) ...[
            const SizedBox(height: 16),
            AppTextField(
                label: 'Bonus (FCFA)',
                controller: bonusCtrl,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            AppTextField(
                label: 'Autres déductions (FCFA)',
                controller: deductionsCtrl,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            AppTextField(
                label: 'Ajustement manuel (+/-, FCFA)',
                controller: ajustementCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true)),
            const SizedBox(height: 12),
            AppTextField(
                label: 'Justification (obligatoire si ajustement)',
                controller: justificationCtrl,
                maxLines: 2),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => deferSetState(() => _showForm = false),
                    child: const Text('Annuler')),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Enregistrer',
                  onPressed: () async {
                    final ajustement =
                        double.tryParse(ajustementCtrl.text.trim()) ?? 0;
                    if (ajustement != 0 &&
                        justificationCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Une justification est requise pour un ajustement manuel.')),
                      );
                      return;
                    }
                    try {
                      await ref
                          .read(payrollRepositoryProvider)
                          .ajusterBulletin(
                            payslipId: widget.payslip.id,
                            bonus: double.tryParse(bonusCtrl.text.trim()) ?? 0,
                            autresDeductions:
                                double.tryParse(deductionsCtrl.text.trim()) ??
                                    0,
                            ajustementManuel: ajustement,
                            justificationAjustement:
                                justificationCtrl.text.trim().isEmpty
                                    ? null
                                    : justificationCtrl.text.trim(),
                          );
                      ref.invalidate(payslipByIdProvider(widget.payslip.id));
                      deferSetState(() => _showForm = false);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReglementCard extends ConsumerStatefulWidget {
  final PayslipEntity payslip;
  const _ReglementCard({required this.payslip});

  @override
  ConsumerState<_ReglementCard> createState() => _ReglementCardState();
}

class _ReglementCardState extends ConsumerState<_ReglementCard>
    with DeferredSetStateMixin<_ReglementCard> {
  bool _showForm = false;
  final montantCtrl = TextEditingController();
  DateTime _datePaiement = DateTime.now();
  String _modePaiement = 'especes';

  static const _modes = [
    ('especes', 'Espèces'),
    ('orange_money', 'Orange Money'),
    ('moov_money', 'Moov Money'),
    ('virement', 'Virement'),
    ('cheque', 'Chèque'),
  ];

  @override
  Widget build(BuildContext context) {
    final paymentsAsync =
        ref.watch(payslipPaymentsProvider(widget.payslip.id));
    final resteAPayer = widget.payslip.resteAPayer;
    final estSolde = resteAPayer <= 0.01;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Règlements', style: AppTextStyles.h3)),
              if (!estSolde && !_showForm)
                AppButton(
                  label: 'Régler',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    montantCtrl.text = resteAPayer.toStringAsFixed(0);
                    deferSetState(() => _showForm = true);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            estSolde
                ? 'Bulletin entièrement payé.'
                : 'Reste à payer : ${CurrencyFormatter.format(resteAPayer)}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          paymentsAsync.when(
            data: (payments) {
              if (payments.isEmpty) return const SizedBox.shrink();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: payments.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, i) {
                  final p = payments[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(CurrencyFormatter.format(p.montant),
                                  style: AppTextStyles.bodyBold),
                              Text(
                                  '${p.modePaiement} · par ${p.payeParUserNom ?? '—'}',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        Text(DateFormatter.formatDate(p.datePaiement),
                            style: AppTextStyles.caption),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (_showForm) ...[
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Montant (FCFA)',
                    controller: montantCtrl,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _modePaiement,
                    decoration: const InputDecoration(labelText: 'Mode'),
                    items: _modes
                        .map((m) => DropdownMenuItem(
                            value: m.$1, child: Text(m.$2)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _modePaiement = v ?? 'especes'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _datePaiement,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (picked != null) {
                        setState(() => _datePaiement = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date'),
                      child: Text(DateFormatter.formatDate(_datePaiement)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => deferSetState(() => _showForm = false),
                    child: const Text('Annuler')),
                const SizedBox(width: 12),
                AppButton(
                  label: 'Confirmer le paiement',
                  onPressed: () async {
                    final montant =
                        double.tryParse(montantCtrl.text.trim()) ?? 0;
                    if (montant <= 0) return;
                    final confirme = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Confirmer le règlement'),
                        content: Text(
                            'Enregistrer un paiement de '
                            '${CurrencyFormatter.format(montant)} pour '
                            '${widget.payslip.employeeNomComplet} ?'),
                        actions: [
                          TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Annuler')),
                          AppButton(
                              label: 'Confirmer',
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true)),
                        ],
                      ),
                    );
                    if (confirme != true) return;

                    final user = ref.read(sessionProvider);
                    if (user == null) return;
                    try {
                      await ref
                          .read(payrollRepositoryProvider)
                          .enregistrerPaiementBulletin(
                            payslipId: widget.payslip.id,
                            montant: montant,
                            datePaiement: _datePaiement,
                            modePaiement: _modePaiement,
                            payeParUserId: user.id,
                            payeParUserNom: user.nom,
                          );
                      ref.invalidate(payslipByIdProvider(widget.payslip.id));
                      ref.invalidate(
                          payslipPaymentsProvider(widget.payslip.id));
                      deferSetState(() => _showForm = false);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
