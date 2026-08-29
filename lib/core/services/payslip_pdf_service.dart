import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/payroll.dart';
import '../constants/app_identity.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

/// Génère le bulletin de paie en PDF — reçu remis à l'employé comme
/// preuve du calcul (salaire de base, absences, avances, bonus) et
/// des règlements déjà effectués.
class PayslipPdfService {
  PayslipPdfService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFond = PdfColor.fromInt(0xFFE7F4ED);

  static Future<void> print({
    required PayslipEntity payslip,
    required PayrollPeriodEntity periode,
    required List<PayslipPaymentEntity> paiements,
    required AppSettingsEntity settings,
  }) async {
    final bytes = await compute(
        _buildPdfBytesSync,
        (
          payslip: payslip,
          periode: periode,
          paiements: paiements,
          settings: settings,
        ));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Bulletin de paie',
    );
  }

  static Future<Uint8List> _buildPdfBytesSync(
      ({
        PayslipEntity payslip,
        PayrollPeriodEntity periode,
        List<PayslipPaymentEntity> paiements,
        AppSettingsEntity settings,
      }) args) {
    return _buildPdfBytes(
      payslip: args.payslip,
      periode: args.periode,
      paiements: args.paiements,
      settings: args.settings,
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required PayslipEntity payslip,
    required PayrollPeriodEntity periode,
    required List<PayslipPaymentEntity> paiements,
    required AppSettingsEntity settings,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    if (settings.logoPath != null) {
      final logoFile = File(settings.logoPath!);
      if (await logoFile.exists()) {
        logo = pw.MemoryImage(await logoFile.readAsBytes());
      }
    }
    pw.MemoryImage? cachet;
    if (settings.cachetPath != null) {
      final cachetFile = File(settings.cachetPath!);
      if (await cachetFile.exists()) {
        cachet = pw.MemoryImage(await cachetFile.readAsBytes());
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          _buildEntete(settings, logo),
          pw.SizedBox(height: 14),
          pw.Divider(color: _couleurBordure, thickness: 1),
          pw.SizedBox(height: 14),
          _buildInfos(payslip, periode),
          pw.SizedBox(height: 18),
          _buildDetailCalcul(payslip),
          pw.SizedBox(height: 16),
          _buildNet(payslip),
          if (paiements.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text('Règlements effectués',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _buildPaiements(paiements),
          ],
          pw.SizedBox(height: 40),
          _buildSignatures(payslip.employeeNomComplet ?? '—', cachet),
          pw.SizedBox(height: 20),
          _mentionEditeur(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEntete(AppSettingsEntity settings, pw.MemoryImage? logo) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        if (logo != null) ...[
          pw.Container(
              width: 56,
              height: 56,
              child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.SizedBox(width: 14),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(settings.nomEntreprise.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: _couleurPrimaire)),
              pw.SizedBox(height: 2),
              if (settings.adresse != null)
                pw.Text(settings.adresse!,
                    style: pw.TextStyle(
                        fontSize: 9, color: _couleurTexteSecondaire)),
              if (settings.telephone != null)
                pw.Text('Tél : ${settings.telephone}',
                    style: pw.TextStyle(
                        fontSize: 9, color: _couleurTexteSecondaire)),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('BULLETIN DE PAIE',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
            pw.Text('Preuve de calcul et de paiement',
                style:
                    pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfos(
      PayslipEntity payslip, PayrollPeriodEntity periode) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Employé : ${payslip.employeeNomComplet ?? "—"}',
            style:
                pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(
            'Période : ${periode.libelle} '
            '(${DateFormatter.formatDate(periode.dateDebut)} - '
            '${DateFormatter.formatDate(periode.dateFin)})',
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildDetailCalcul(PayslipEntity payslip) {
    final lignes = <(String, double)>[
      ('Salaire de base', payslip.salaireBase),
      if (payslip.retenueAbsence > 0)
        ('Retenue absence (${payslip.joursAbsence.toStringAsFixed(1)} j)',
            -payslip.retenueAbsence),
      if (payslip.avancesDeduites > 0)
        ('Avances déduites', -payslip.avancesDeduites),
      if (payslip.bonus > 0) ('Bonus', payslip.bonus),
      if (payslip.autresDeductions > 0)
        ('Autres déductions', -payslip.autresDeductions),
      if (payslip.ajustementManuel != 0)
        ('Ajustement manuel', payslip.ajustementManuel),
    ];
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFond),
          children: [
            _cellHeader('Élément'),
            _cellHeader('Montant', align: pw.TextAlign.right),
          ],
        ),
        ...lignes.map((l) => pw.TableRow(children: [
              _cell(l.$1),
              _cell(CurrencyFormatter.format(l.$2), align: pw.TextAlign.right),
            ])),
      ],
    );
  }

  static pw.Widget _cellHeader(String text, {pw.TextAlign? align}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style:
                pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _cell(String text, {pw.TextAlign? align}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: pw.Text(text,
            textAlign: align, style: const pw.TextStyle(fontSize: 9.5)),
      );

  static pw.Widget _buildNet(PayslipEntity payslip) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
              color: _couleurFond, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Text(
              'SALAIRE NET : ${CurrencyFormatter.format(payslip.salaireNet)}',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _couleurPrimaire)),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Payé : ${CurrencyFormatter.format(payslip.montantPaye)}',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
                'Reste à payer : '
                '${CurrencyFormatter.format(payslip.resteAPayer)}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPaiements(List<PayslipPaymentEntity> paiements) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFond),
          children: [
            _cellHeader('Date'),
            _cellHeader('Montant', align: pw.TextAlign.right),
            _cellHeader('Mode'),
            _cellHeader('Payé par'),
          ],
        ),
        ...paiements.map((p) => pw.TableRow(children: [
              _cell(DateFormatter.formatDate(p.datePaiement)),
              _cell(CurrencyFormatter.format(p.montant),
                  align: pw.TextAlign.right),
              _cell(p.modePaiement),
              _cell(p.payeParUserNom ?? '—'),
            ])),
      ],
    );
  }

  static pw.Widget _buildSignatures(
      String employeeNomComplet, pw.MemoryImage? cachet) {
    final ligneVide = pw.Container(
      width: 160,
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _couleurBordure)),
      ),
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reçu par ($employeeNomComplet) :',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 30),
            ligneVide,
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('Payé par :', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: cachet != null ? 4 : 30),
            if (cachet != null)
              pw.Container(
                  width: 80,
                  height: 60,
                  child: pw.Image(cachet, fit: pw.BoxFit.contain))
            else
              ligneVide,
          ],
        ),
      ],
    );
  }

  static pw.Widget _mentionEditeur() {
    return pw.Center(
      child: pw.Text(
        AppIdentity.mentionPdf,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
            fontSize: 7,
            color: const PdfColor.fromInt(0xFFBFC5CC),
            fontStyle: pw.FontStyle.italic),
      ),
    );
  }
}
