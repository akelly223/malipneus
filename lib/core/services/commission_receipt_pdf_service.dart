import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/commission.dart';
import '../constants/app_identity.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

/// Génère la preuve papier des commissions d'un commercial, vente par
/// vente (client, date, article, montant) — utilisée aussi bien pour
/// un état "dû" (avant règlement) qu'un reçu de règlement déjà payé.
/// Sert de justificatif en cas de contestation sur ce qui a été payé.
class CommissionReceiptPdfService {
  CommissionReceiptPdfService._();

  static const PdfColor _couleurPrimaire = PdfColor.fromInt(0xFF1E6F46);
  static const PdfColor _couleurTexteSecondaire = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _couleurBordure = PdfColor.fromInt(0xFFBFC5CC);
  static const PdfColor _couleurFond = PdfColor.fromInt(0xFFE7F4ED);

  static Future<void> print({
    required String employeeNomComplet,
    required DateTime periodeDebut,
    required DateTime periodeFin,
    required List<CommissionLigneDetailEntity> lignes,
    required double montantCommission,
    required AppSettingsEntity settings,
    DateTime? datePaiement,
    String? modePaiement,
    String? payeParUserNom,
  }) async {
    final estRegle = datePaiement != null;
    final bytes = await compute(
        _buildPdfBytesSync,
        (
          employeeNomComplet: employeeNomComplet,
          periodeDebut: periodeDebut,
          periodeFin: periodeFin,
          lignes: lignes,
          montantCommission: montantCommission,
          settings: settings,
          datePaiement: datePaiement,
          modePaiement: modePaiement,
          payeParUserNom: payeParUserNom,
        ));
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: estRegle ? 'Reçu de commission' : 'Relevé de commissions dues',
    );
  }

  static Future<Uint8List> _buildPdfBytesSync(
      ({
        String employeeNomComplet,
        DateTime periodeDebut,
        DateTime periodeFin,
        List<CommissionLigneDetailEntity> lignes,
        double montantCommission,
        AppSettingsEntity settings,
        DateTime? datePaiement,
        String? modePaiement,
        String? payeParUserNom,
      }) args) {
    return _buildPdfBytes(
      employeeNomComplet: args.employeeNomComplet,
      periodeDebut: args.periodeDebut,
      periodeFin: args.periodeFin,
      lignes: args.lignes,
      montantCommission: args.montantCommission,
      settings: args.settings,
      datePaiement: args.datePaiement,
      modePaiement: args.modePaiement,
      payeParUserNom: args.payeParUserNom,
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required String employeeNomComplet,
    required DateTime periodeDebut,
    required DateTime periodeFin,
    required List<CommissionLigneDetailEntity> lignes,
    required double montantCommission,
    required AppSettingsEntity settings,
    DateTime? datePaiement,
    String? modePaiement,
    String? payeParUserNom,
  }) async {
    final estRegle = datePaiement != null;
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
          _buildEntete(settings, logo, estRegle),
          pw.SizedBox(height: 14),
          pw.Divider(color: _couleurBordure, thickness: 1),
          pw.SizedBox(height: 14),
          _buildInfos(employeeNomComplet, periodeDebut, periodeFin,
              datePaiement, modePaiement, payeParUserNom),
          pw.SizedBox(height: 18),
          pw.Text('Ventes commissionnées (${lignes.length})',
              style:
                  pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _buildTableau(lignes),
          pw.SizedBox(height: 16),
          _buildTotal(montantCommission, estRegle),
          pw.SizedBox(height: 40),
          _buildSignatures(employeeNomComplet, cachet),
          pw.SizedBox(height: 20),
          _mentionEditeur(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildEntete(
      AppSettingsEntity settings, pw.MemoryImage? logo, bool estRegle) {
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
            pw.Text(
                estRegle
                    ? 'REÇU DE RÈGLEMENT DE COMMISSION'
                    : 'RELEVÉ DE COMMISSIONS DUES',
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _couleurPrimaire)),
            pw.Text(
                estRegle
                    ? 'Preuve de paiement au commercial'
                    : 'Montant non encore réglé — document informatif',
                style:
                    pw.TextStyle(fontSize: 9, color: _couleurTexteSecondaire)),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildInfos(
      String employeeNomComplet,
      DateTime periodeDebut,
      DateTime periodeFin,
      DateTime? datePaiement,
      String? modePaiement,
      String? payeParUserNom) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Commercial : $employeeNomComplet',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Période : ${DateFormatter.formatDate(periodeDebut)} '
                '- ${DateFormatter.formatDate(periodeFin)}',
                style: const pw.TextStyle(fontSize: 10)),
            if (datePaiement != null)
              pw.Text(
                  'Payé le ${DateFormatter.formatDate(datePaiement)}'
                  '${modePaiement != null ? ' · $modePaiement' : ''}',
                  style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        if (payeParUserNom != null)
          pw.Text('Réglé par : $payeParUserNom',
              style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildTableau(List<CommissionLigneDetailEntity> lignes) {
    return pw.Table(
      border: pw.TableBorder(
        top: pw.BorderSide(color: _couleurBordure, width: 1),
        bottom: pw.BorderSide(color: _couleurBordure, width: 1),
        horizontalInside: pw.BorderSide(color: _couleurBordure, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(1.0),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _couleurFond),
          children: [
            _cellHeader('Date'),
            _cellHeader('Client'),
            _cellHeader('Article'),
            _cellHeader('Qté', align: pw.TextAlign.right),
            _cellHeader('Commission', align: pw.TextAlign.right),
          ],
        ),
        ...lignes.map((l) => pw.TableRow(children: [
              _cell(DateFormatter.formatDate(l.dateDocument)),
              _cell(l.clientNom ?? 'Vente comptoir'),
              _cell(l.articleNom),
              _cell(l.quantite.toStringAsFixed(0), align: pw.TextAlign.right),
              _cell(CurrencyFormatter.format(l.commissionMontant),
                  align: pw.TextAlign.right),
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

  static pw.Widget _buildTotal(double montantCommission, bool estRegle) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
            color: _couleurFond, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Text(
            '${estRegle ? "TOTAL PAYÉ" : "TOTAL DÛ"} : '
            '${CurrencyFormatter.format(montantCommission)}',
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: _couleurPrimaire)),
      ),
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
