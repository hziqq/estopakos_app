import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/formatters.dart';

class PaymentReceiptDialog extends StatelessWidget {
  final PaymentRecord payment;

  const PaymentReceiptDialog({super.key, required this.payment});

  static void show(BuildContext context, PaymentRecord payment) {
    showDialog(
      context: context,
      builder: (_) => PaymentReceiptDialog(payment: payment),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.verified, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Kwitansi Digital Estopa Kos',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(
                child: Column(
                  children: [
                    Text(
                      'ESTOPA KOS MEDAN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'Jl. Sei Padang, Medan Baru, Kota Medan',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),
              _ReceiptLine('ID Pembayaran', payment.id),
              _ReceiptLine('Ref Gateway', payment.gatewayReference),
              _ReceiptLine('Waktu Lunas', AppFormatters.dateTime(payment.paidAt)),
              _ReceiptLine('Nama Penghuni', payment.tenantName),
              _ReceiptLine('Nomor Kamar', 'Kamar ${payment.roomNumber}'),
              _ReceiptLine('Jenis Transaksi', payment.type),
              const Divider(height: 20),
              _ReceiptLine(
                'Sewa Kamar (${payment.months} bln)',
                AppFormatters.currency(payment.roomCost),
              ),
              _ReceiptLine(
                'Biaya Air (Rp35.000 × ${payment.months})',
                AppFormatters.currency(payment.waterCost),
              ),
              _ReceiptLine(
                'Biaya Transaksi Gateway',
                AppFormatters.currency(payment.transactionFee),
              ),
              if (payment.lateFee > 0)
                _ReceiptLine(
                  'Denda Keterlambatan',
                  AppFormatters.currency(payment.lateFee),
                ),
              const Divider(height: 16),
              _ReceiptLine(
                'TOTAL LUNAS',
                AppFormatters.currency(payment.totalAmount),
                isBold: true,
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup Kwitansi'),
        ),
      ],
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _ReceiptLine(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isBold ? 14 : 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
