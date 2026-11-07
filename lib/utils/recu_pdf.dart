import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/client.dart';
import '../models/vente.dart';
import '../models/vente_item.dart';
import '../services/parametres_service.dart';
import 'format.dart';

String _fcfa(num valeur) {
  final entier = valeur.round().toString();
  final negatif = entier.startsWith('-');
  final chiffres = negatif ? entier.substring(1) : entier;
  final buffer = StringBuffer();
  for (var i = 0; i < chiffres.length; i++) {
    if (i > 0 && (chiffres.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(chiffres[i]);
  }
  return '${negatif ? '-' : ''}$buffer FCFA';
}

pw.Document construireRecuPdf({
  required Vente vente,
  required List<VenteItem> items,
  Client? client,
  required Parametres parametres,
}) {
  final pdf = pw.Document();
  final sousTotal = items.fold<double>(
    0,
    (s, item) => s + item.prixUnitaire * item.quantite,
  );
  final pointsRemise = vente.pointsUtilises * parametres.valeurPoint;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  parametres.nomSalon,
                  style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (parametres.adresse.trim().isNotEmpty)
                  pw.Text(parametres.adresse,
                      style: const pw.TextStyle(fontSize: 9)),
                if (parametres.telephone.trim().isNotEmpty)
                  pw.Text('Tel : ${parametres.telephone}',
                      style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 6),
                pw.Text('RECU DE CAISSE',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2,
                    )),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 8),
          _ligne('Recu', '#${vente.id ?? '-'}'),
          _ligne('Date', formatDateHeure(vente.dateVente)),
          if (client != null) _ligne('Client', client.nom),
          if (client != null) _ligne('Telephone', client.telephone),
          _ligne('Paiement', _mode(vente.modePaiement)),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Text('Article',
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(
                width: 34,
                child: pw.Text('Qte',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(
                width: 58,
                child: pw.Text('P.U.',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(
                width: 66,
                child: pw.Text('Total',
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          for (final item in items) ...[
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 5,
                  child: pw.Text(item.designation,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(
                  width: 34,
                  child: pw.Text('${item.quantite}',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9)),
                ),
                pw.SizedBox(
                  width: 58,
                  child: pw.Text(_fcfa(item.prixUnitaire),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
                pw.SizedBox(
                  width: 66,
                  child: pw.Text(_fcfa(item.prixUnitaire * item.quantite),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
          ],
          pw.SizedBox(height: 8),
          pw.Divider(),
          pw.SizedBox(height: 8),
          _ligne('Sous-total', _fcfa(sousTotal)),
          if (vente.remise > 0) _ligne('Remise', '- ${_fcfa(vente.remise)}'),
          if (pointsRemise > 0)
            _ligne(
              'Points (${vente.pointsUtilises})',
              '- ${_fcfa(pointsRemise)}',
            ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('NET A PAYER',
                  style: const pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                _fcfa(vente.montant),
                style: const pw.TextStyle(
                    fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Text(
              parametres.messageRecu,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Genere le ${DateFormat('dd/MM/yyyy a HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    ),
  );
  return pdf;
}

pw.Widget _ligne(String label, String valeur) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(valeur,
            style: const pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ],
    ),
  );
}

String _mode(String mode) => switch (mode) {
      'orange_money' => 'Orange Money',
      'moov_money' => 'Moov Money',
      'mix_yas' => 'Mix by Yas',
      _ => 'Especes',
    };

Future<void> partagerRecuPdf({
  required Vente vente,
  required List<VenteItem> items,
  Client? client,
  required Parametres parametres,
}) async {
  final pdf = construireRecuPdf(
    vente: vente,
    items: items,
    client: client,
    parametres: parametres,
  );
  await Printing.sharePdf(
    bytes: await pdf.save(),
    filename: 'recu_${vente.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
  );
}

String messageRecuTexte({
  required Vente vente,
  required List<VenteItem> items,
  Client? client,
  required Parametres parametres,
}) {
  final buffer = StringBuffer()
    ..writeln('*${parametres.nomSalon}*')
    ..writeln('Recu #${vente.id ?? '-'} • ${formatDateHeure(vente.dateVente)}')
    ..writeln('');
  for (final item in items) {
    buffer.writeln(
      '${item.quantite} x ${item.designation} : '
      '${_fcfa(item.prixUnitaire * item.quantite)}',
    );
  }
  buffer.writeln('');
  if (vente.remise > 0) buffer.writeln('Remise : -${_fcfa(vente.remise)}');
  if (vente.pointsUtilises > 0) {
    buffer.writeln('Points utilises : ${vente.pointsUtilises}');
  }
  buffer
    ..writeln('*Total : ${_fcfa(vente.montant)}*')
    ..writeln('Paiement : ${_mode(vente.modePaiement)}')
    ..writeln('');
  if (client != null) buffer.writeln('Merci ${client.nom} !');
  buffer.write(parametres.messageRecu);
  return buffer.toString();
}
