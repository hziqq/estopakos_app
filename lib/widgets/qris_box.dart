import 'package:flutter/material.dart';
import '../utils/formatters.dart';

/// Widget kartu QRIS Standar Nasional (Sandbox) dengan matriks QR deterministik dari payload.
/// Digunakan untuk QR Pemesanan 20 Menit (FR-14) dan QR Tagihan 24 Jam (FR-03).
class QrisPaymentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String qrPayload;
  final int totalAmount;
  final String expiryLabel;
  final bool isBookingQr;

  const QrisPaymentCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.qrPayload,
    required this.totalAmount,
    required this.expiryLabel,
    required this.isBookingQr,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        isBookingQr ? Colors.deepOrange.shade700 : Colors.teal.shade800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header QRIS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBookingQr ? 'QRIS PEMESANAN (20M)' : 'QRIS TAGIHAN (24J)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const Text(
                'NMID: ID2026ESTOPAKOS039',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 14),

          // Matriks QR Code deterministik dari qrPayload
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black87, width: 2.5),
            ),
            child: CustomPaint(
              size: const Size(176, 176),
              painter: _DeterministicQrPainter(payload: qrPayload),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppFormatters.currency(totalAmount),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expiryLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              qrPayload,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontFamily: 'monospace',
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeterministicQrPainter extends CustomPainter {
  final String payload;

  _DeterministicQrPainter({required this.payload});

  @override
  void paint(Canvas canvas, Size size) {
    const int gridCount = 21;
    final double cellSize = size.width / gridCount;
    final Paint darkPaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    bool isFinderPattern(int r, int c) {
      final topLeft = r < 7 && c < 7;
      final topRight = r < 7 && c >= gridCount - 7;
      final bottomLeft = r >= gridCount - 7 && c < 7;
      return topLeft || topRight || bottomLeft;
    }

    void drawFinder(int startR, int startC) {
      for (int r = 0; r < 7; r++) {
        for (int c = 0; c < 7; c++) {
          final isBorder = r == 0 || r == 6 || c == 0 || c == 6;
          final isInner = r >= 2 && r <= 4 && c >= 2 && c <= 4;
          if (isBorder || isInner) {
            canvas.drawRect(
              Rect.fromLTWH(
                (startC + c) * cellSize,
                (startR + r) * cellSize,
                cellSize,
                cellSize,
              ),
              darkPaint,
            );
          }
        }
      }
    }

    drawFinder(0, 0);
    drawFinder(0, gridCount - 7);
    drawFinder(gridCount - 7, 0);

    final codeUnits = payload.codeUnits;
    for (int r = 0; r < gridCount; r++) {
      for (int c = 0; c < gridCount; c++) {
        if (isFinderPattern(r, c)) continue;
        // Timing pattern
        if (r == 6 || c == 6) {
          if ((r + c) % 2 == 0) {
            canvas.drawRect(
              Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
              darkPaint,
            );
          }
          continue;
        }
        final idx = (r * gridCount + c) % codeUnits.length;
        final charVal = codeUnits[idx];
        final hash = ((charVal * 31) + (r * 17) + (c * 13)) % 7;
        if (hash < 3) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            darkPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DeterministicQrPainter oldDelegate) {
    return oldDelegate.payload != payload;
  }
}
