import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models.dart';

class PdfService {
  static Future<void> generateAndDownloadReceipt(OrderSummary order) async {
    final pdf = pw.Document();
    
    // Check for items
    final items = order.items ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context _) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RECEIPT',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange800,
                        ),
                      ),
                      pw.Text('Food Delivery Management'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Order ID: #${order.orderId}'),
                      pw.Text('Date: ${order.createdAt.toString().substring(0, 16)}'),
                      pw.Text('Status: ${order.status}'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // Items Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                headers: ['Item', 'Qty', 'Unit Price', 'Total'],
                data: items.map((it) => [
                  it.name,
                  it.qty.toString(),
                  '${order.currency} ${it.unitPrice.toStringAsFixed(2)}',
                  '${order.currency} ${it.lineTotal.toStringAsFixed(2)}',
                ]).toList(),
              ),
              pw.Divider(),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildSummaryRow('Subtotal', '${order.currency} ${order.subtotal.toStringAsFixed(2)}'),
                      _buildSummaryRow('Delivery Fee', '${order.currency} ${order.deliveryFee.toStringAsFixed(2)}'),
                      pw.Divider(),
                      pw.Text(
                        'Total: ${order.currency} ${order.total.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.orange800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Thank you for your order!',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey700),
                ),
              ),
            ],
          );
        },
      ),
    );

    // Preview/Download
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdf.save(),
      name: 'receipt_order_${order.orderId}.pdf',
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value),
        ],
      ),
    );
  }

  /// Full fleet: all restaurants in the current list (e.g. owner fleet or all stores).
  static Future<void> generateRestaurantFleetPdf({
    required List<Store> stores,
    String? titleSuffix,
  }) async {
    final pdf = pw.Document();
    final generated = DateTime.now().toString().substring(0, 19);
    final sub = titleSuffix != null && titleSuffix.isNotEmpty
        ? ' — $titleSuffix'
        : '';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context _) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RESTAURANT FLEET$sub',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.Text('Restaurant management dashboard — export', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10)),
                ],
              ),
              pw.Text('Generated: $generated', style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text('Total locations: ${stores.length}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          if (stores.isEmpty)
            pw.Text('No restaurants in this list.')
          else
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange800),
              cellHeight: 28,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
              },
              headers: const ['ID', 'Name', 'Address', 'Updated'],
              data: stores.map((s) {
                return [
                  s.id.toString(),
                  s.name,
                  s.address?.trim().isNotEmpty == true ? s.address! : '—',
                  s.updatedAt.toString().substring(0, 16),
                ];
              }).toList(),
            ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Per-location photos and ratings are in the app only.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    final safe = generated.replaceAll(RegExp(r'[^\w\-]'), '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdf.save(),
      name: 'restaurant_fleet_$safe.pdf',
    );
  }

  /// One restaurant: detail sheet for download / print.
  static Future<void> generateStoreDetailsPdf(Store s) async {
    final pdf = pw.Document();
    final generated = DateTime.now().toString().substring(0, 19);

    String d(String? v) =>
        (v != null && v.trim().isNotEmpty) ? v : '—';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context _) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RESTAURANT DETAILS',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange800,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('ID #${s.id} · $generated', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              pw.Text(s.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              _buildSummaryRow('Address', d(s.address)),
              _buildSummaryRow(
                'Coordinates',
                s.latitude != null && s.longitude != null
                    ? '${s.latitude}, ${s.longitude}'
                    : '—',
              ),
              if (s.ownerUserId != null) _buildSummaryRow('Owner user ID', s.ownerUserId.toString()),
              _buildSummaryRow('Created', s.createdAt.toString().substring(0, 16)),
              _buildSummaryRow('Updated', s.updatedAt.toString().substring(0, 16)),
              if (s.imageUrl != null && s.imageUrl!.isNotEmpty)
                _buildSummaryRow('Image URL', s.imageUrl!),
              pw.SizedBox(height: 24),
              pw.Text(
                'Use the Menu action in the app to see dishes and prices.',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ],
          );
        },
      ),
    );

    final safe = s.name.replaceAll(RegExp(r'[^\w\-\s]'), '').trim().replaceAll(RegExp(r'\s+'), '_');
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => pdf.save(),
      name: 'restaurant_${s.id}_$safe.pdf',
    );
  }
}
