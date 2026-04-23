import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api.dart';
import '../services/pdf_service.dart';

class ReceiptScreen extends StatelessWidget {
  final ReceiptResponse receipt;

  const ReceiptScreen({Key? key, required this.receipt}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final r = receipt.receipt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF2E2E3E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, size: 36, color: Color(0xFF11A36A)),
                      const SizedBox(width: 12),
                      Text('Receipt', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF11A36A))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Receipt number & date
                  if (r != null) ...[
                    Text('Receipt No: ${r.receiptNo}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Issued At: ${r.issuedAt.toLocal().toString().split('.').first}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    const Divider(height: 32),
                    // Payment details
                    Text('Order ID: ${receipt.orderId}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Status: ${r.paymentStatus}', style: const TextStyle(fontSize: 16, color: Color(0xFF11A36A), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Method: ${r.paymentMethod}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Amount: LKR ${r.paidAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6A00))),
                    const SizedBox(height: 8),
                    Text('Currency: ${r.currency}', style: const TextStyle(fontSize: 14)),
                  ] else ...[
                    const Text('No receipt data available', style: TextStyle(fontSize: 16, color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final api = ApiClient();
                            final fullOrder = await api.getOrderDetails(id: receipt.orderId);
                            await PdfService.generateAndDownloadReceipt(fullOrder);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to generate PDF: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF6A00),
                          side: const BorderSide(color: Color(0xFFFF6A00)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF6A00),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
