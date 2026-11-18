import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailDeliveryResult {
  final bool sentViaSmtp;
  final bool smtpConfigured;
  final String recipient;
  final String subject;
  final String statusMessage;
  final String savedHtmlPath;

  const EmailDeliveryResult({
    required this.sentViaSmtp,
    required this.smtpConfigured,
    required this.recipient,
    required this.subject,
    required this.statusMessage,
    required this.savedHtmlPath,
  });

  Map<String, dynamic> toJson() => {
        'sentViaSmtp': sentViaSmtp,
        'smtpConfigured': smtpConfigured,
        'recipient': recipient,
        'subject': subject,
        'statusMessage': statusMessage,
        'savedHtmlPath': savedHtmlPath,
      };
}

class EstopaEmailService {
  String smtpHost;
  int smtpPort;
  String smtpUser;
  String smtpPass;
  String fromName;

  EstopaEmailService({
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUser,
    required this.smtpPass,
    this.fromName = 'Manajemen Estopa Kos',
  });

  bool get isSmtpConfigured =>
      smtpUser.trim().isNotEmpty && smtpPass.trim().isNotEmpty;

  factory EstopaEmailService.fromEnv() {
    final envMap = <String, String>{};
    for (final path in ['backend/.env', '.env']) {
      final f = File(path);
      if (f.existsSync()) {
        for (final line in f.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final idx = trimmed.indexOf('=');
          if (idx > 0) {
            final key = trimmed.substring(0, idx).trim();
            final val = trimmed.substring(idx + 1).trim();
            envMap[key] = val;
          }
        }
        break;
      }
    }

    String readKey(String key, String fallback) {
      return Platform.environment[key] ?? envMap[key] ?? fallback;
    }

    return EstopaEmailService(
      smtpHost: readKey('SMTP_HOST', 'smtp.gmail.com'),
      smtpPort: int.tryParse(readKey('SMTP_PORT', '587')) ?? 587,
      smtpUser: readKey('SMTP_USER', 'haziqalfareza06@gmail.com'),
      smtpPass: readKey('SMTP_PASS', ''),
      fromName: readKey('SMTP_FROM_NAME', 'Manajemen Estopa Kos'),
    );
  }

  /// Simpan konfigurasi SMTP ke backend/.env secara persisten.
  void updateSmtpConfig({
    required String host,
    required int port,
    required String user,
    required String pass,
  }) {
    smtpHost = host.trim().isEmpty ? 'smtp.gmail.com' : host.trim();
    smtpPort = port <= 0 ? 587 : port;
    smtpUser = user.trim();
    smtpPass = pass.replaceAll(' ', '').trim();

    final envFile = File(
      File('backend/.env').existsSync() ? 'backend/.env' : '.env',
    );
    final lines = envFile.existsSync() ? envFile.readAsLinesSync() : <String>[];
    final updatedKeys = <String>{};
    final newLines = <String>[];

    final targetMap = {
      'SMTP_HOST': smtpHost,
      'SMTP_PORT': smtpPort.toString(),
      'SMTP_USER': smtpUser,
      'SMTP_PASS': smtpPass,
    };

    for (final line in lines) {
      final trimmed = line.trim();
      final idx = trimmed.indexOf('=');
      if (!trimmed.startsWith('#') && idx > 0) {
        final key = trimmed.substring(0, idx).trim();
        if (targetMap.containsKey(key)) {
          newLines.add('$key=${targetMap[key]}');
          updatedKeys.add(key);
          continue;
        }
      }
      newLines.add(line);
    }

    for (final entry in targetMap.entries) {
      if (!updatedKeys.contains(entry.key)) {
        newLines.add('${entry.key}=${entry.value}');
      }
    }

    envFile.writeAsStringSync('${newLines.join('\n')}\n');
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<EmailDeliveryResult> sendWelcomeBookingEmail({
    required String fullName,
    required String email,
    required String phone,
    required String roomNumber,
    required int months,
    required int roomCost,
    required int waterCost,
    required int transactionFee,
    required int totalAmount,
    String? plainPassword,
  }) async {
    final subject =
        '[Estopa Kos] Bukti Pembayaran Lunas & Aktivasi Akun Kamar $roomNumber';
    final passwordDisplay =
        (plainPassword != null && plainPassword.trim().isNotEmpty)
            ? plainPassword.trim()
            : 'Sesuai yang Anda daftarkan saat pemesanan';
    final escapedPassword = _escapeHtml(passwordDisplay);

    final htmlBody = '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <title>$subject</title>
</head>
<body style="font-family: Arial, sans-serif; background-color: #f4f7f6; padding: 24px; color: #222;">
  <div style="max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 12px; overflow: hidden; border: 1px solid #d9e4e0;">
    <div style="background-color: #0F6B58; color: #ffffff; padding: 20px 24px;">
      <h2 style="margin: 0; font-size: 20px;">Estopa Kos • Konfirmasi Pembayaran</h2>
      <p style="margin: 4px 0 0 0; font-size: 13px; opacity: 0.9;">Jl. Sei Padang, Kec. Medan Baru, Kota Medan</p>
    </div>
    <div style="padding: 24px;">
      <p style="margin-top: 0;">Halo <strong>$fullName</strong>,</p>
      <p>Terima kasih! Pembayaran pemesanan <strong>Kamar $roomNumber</strong> telah kami terima secara lunas dan akun penghuni Anda kini <strong>aktif otomatis</strong>.</p>

      <div style="background-color: #f0f9f6; border-left: 4px solid #0F6B58; padding: 14px; margin: 18px 0; border-radius: 6px;">
        <h4 style="margin: 0 0 8px 0; color: #0F6B58;">Informasi Login Akun Penghuni</h4>
        <p style="margin: 4px 0; font-size: 14px;">• <strong>Email Login:</strong> $email</p>
        <p style="margin: 4px 0; font-size: 14px;">• <strong>No. HP Login:</strong> $phone</p>
        <p style="margin: 4px 0; font-size: 14px;">• <strong>Kata Sandi:</strong> <code style="background: #e2f1ec; padding: 2px 6px; border-radius: 4px;">$escapedPassword</code></p>
        <p style="margin: 4px 0; font-size: 14px;">• <strong>Status Kamar $roomNumber:</strong> TERISI (Aktif)</p>
      </div>

      <h4 style="margin-bottom: 8px;">Rincian Pembayaran QRIS ($months Bulan)</h4>
      <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
        <tr>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee;">Sewa Kamar ($months bln)</td>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee; text-align: right;">Rp ${_fmtRupiah(roomCost)}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee;">Biaya Air (Rp35.000 × $months bln)</td>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee; text-align: right;">Rp ${_fmtRupiah(waterCost)}</td>
        </tr>
        <tr>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee;">Biaya Transaksi Payment Gateway</td>
          <td style="padding: 6px 0; border-bottom: 1px solid #eee; text-align: right;">Rp ${_fmtRupiah(transactionFee)}</td>
        </tr>
        <tr>
          <td style="padding: 10px 0; font-weight: bold;">Total Dibayar (LUNAS)</td>
          <td style="padding: 10px 0; font-weight: bold; text-align: right; color: #0F6B58;">Rp ${_fmtRupiah(totalAmount)}</td>
        </tr>
      </table>

      <p style="font-size: 12px; color: #666; margin-top: 24px;">
        Email ini dikirim secara otomatis oleh Sistem Informasi Manajemen Estopa Kos (FR-16).
      </p>
    </div>
  </div>
</body>
</html>
''';

    final plainText = '''
Halo $fullName,

Terima kasih! Pembayaran pemesanan Kamar $roomNumber di Estopa Kos telah berhasil dan lunas.

INFORMASI LOGIN AKUN PENGHUNI:
- Kamar       : Kamar $roomNumber (Status: Terisi)
- Email Login : $email
- No. HP Login: $phone
- Kata Sandi  : $passwordDisplay

RINCIAN PEMBAYARAN ($months Bulan):
- Sewa Kamar ($months bln)        : Rp ${_fmtRupiah(roomCost)}
- Biaya Air (Rp35.000 x $months)  : Rp ${_fmtRupiah(waterCost)}
- Biaya Transaksi Gateway         : Rp ${_fmtRupiah(transactionFee)}
- TOTAL DIBAYAR (LUNAS)           : Rp ${_fmtRupiah(totalAmount)}

Salam hangat,
Manajemen Estopa Kos
Jl. Sei Padang, Medan Baru
''';

    // Simpan arsip HTML email ke folder outbox lokal
    final outDir = Directory(
      Directory('backend').existsSync() ? 'backend/sent_emails' : 'sent_emails',
    );
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }
    final safeTs = DateTime.now().millisecondsSinceEpoch;
    final htmlFile = File('${outDir.path}/email_${safeTs}_kamar_$roomNumber.html');
    await htmlFile.writeAsString(htmlBody);

    if (!isSmtpConfigured) {
      stdout.writeln(
        '[EMAIL OUTBOX] Email konfirmasi untuk $email disimpan di ${htmlFile.path} (SMTP_USER/SMTP_PASS belum diisi).',
      );
      return EmailDeliveryResult(
        sentViaSmtp: false,
        smtpConfigured: false,
        recipient: email,
        subject: subject,
        statusMessage:
            'Email konfirmasi tersimpan di Outbox Server (${htmlFile.path}). Isi SMTP Gmail di pengaturan untuk mengirim ke inbox email asli.',
        savedHtmlPath: htmlFile.path,
      );
    }

    try {
      final smtpServer = smtpHost.toLowerCase().contains('gmail.com')
          ? gmail(smtpUser, smtpPass)
          : SmtpServer(
              smtpHost,
              port: smtpPort,
              username: smtpUser,
              password: smtpPass,
            );

      final message = Message()
        ..from = Address(smtpUser, fromName)
        ..recipients.add(email.trim())
        ..subject = subject
        ..text = plainText
        ..html = htmlBody;

      await send(message, smtpServer);
      stdout.writeln(
        '[SMTP EMAIL SENT] Berhasil mengirim email konfirmasi ke $email via $smtpHost ($smtpUser)!',
      );
      return EmailDeliveryResult(
        sentViaSmtp: true,
        smtpConfigured: true,
        recipient: email,
        subject: subject,
        statusMessage:
            'Email konfirmasi berhasil dikirim ke inbox $email melalui SMTP ($smtpUser).',
        savedHtmlPath: htmlFile.path,
      );
    } catch (e) {
      stderr.writeln('[SMTP ERROR] Gagal mengirim email ke $email: $e');
      return EmailDeliveryResult(
        sentViaSmtp: false,
        smtpConfigured: true,
        recipient: email,
        subject: subject,
        statusMessage:
            'Gagal kirim SMTP ($e). Salinan email tetap tersimpan di ${htmlFile.path}.',
        savedHtmlPath: htmlFile.path,
      );
    }
  }

  static String _fmtRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) {
        buf.write('.');
      }
    }
    return buf.toString();
  }
}
