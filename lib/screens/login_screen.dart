import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/estopa_store.dart';
import 'admin_dashboard_screen.dart';
import 'tenant_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  final EstopaStore store;

  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Jika sudah login dari alur pemesanan baru, langsung arahkan ke dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _redirectIfAuthenticated();
    });
  }

  void _redirectIfAuthenticated() {
    if (widget.store.currentUserRole == UserRole.admin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(store: widget.store),
        ),
      );
    } else if (widget.store.currentUserRole == UserRole.tenant &&
        widget.store.currentTenant != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TenantDashboardScreen(store: widget.store),
        ),
      );
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _attemptLogin([String? quickId, String? quickPwd]) {
    if (quickId != null && quickPwd != null) {
      _idCtrl.text = quickId;
      _pwdCtrl.text = quickPwd;
    }

    setState(() => _errorMessage = null);
    final res = widget.store.login(_idCtrl.text, _pwdCtrl.text);
    if (!res.success) {
      setState(() => _errorMessage = res.message);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res.message)),
    );
    _redirectIfAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Masuk Akun Estopa Kos (FR-29)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selamat Datang di Estopa Kos',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Masuk menggunakan Email atau Nomor HP beserta kata sandi Anda. Menu otomatis menyesuaikan peran (Admin / Penghuni).',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            TextField(
              controller: _idCtrl,
              decoration: const InputDecoration(
                labelText: 'Email atau Nomor HP',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Kata Sandi',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                helperText:
                    'Lupa kata sandi? Hubungi Admin Estopa Kos untuk direset (FR-22).',
              ),
              onSubmitted: (_) => _attemptLogin(),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _attemptLogin(),
                icon: const Icon(Icons.login),
                label: const Text('Masuk Sekarang'),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black38,
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
                onPressed: () => _attemptLogin(
                  EstopaStore.adminEmail,
                  EstopaStore.adminPassword,
                ),
                child: const Text('Akses Pengelola / Admin'),
              ),
            ),
            const SizedBox(height: 18),

            // Panel Akun Demo Satu-Klik Penghuni
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bolt, size: 18, color: Colors.deepOrange),
                      SizedBox(width: 6),
                      Text(
                        'Pintasan Akun Penghuni (Demo Uji)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _QuickLoginTile(
                    title: 'Nadia Salsabila (Kamar 101 - Putri)',
                    subtitle: 'nadia@gmail.com • Tagihan Belum Bayar (H-2)',
                    badge: 'BELUM BAYAR',
                    badgeColor: Colors.orange.shade800,
                    onTap: () => _attemptLogin(
                      'nadia@gmail.com',
                      'password123',
                    ),
                  ),
                  _QuickLoginTile(
                    title: 'Rizky Pratama (Kamar 301 - Putra)',
                    subtitle: 'rizky@gmail.com • Terlambat 3 Hari (+Rp150.000)',
                    badge: 'TERLAMBAT',
                    badgeColor: Colors.red.shade700,
                    onTap: () => _attemptLogin(
                      'rizky@gmail.com',
                      'password123',
                    ),
                  ),
                  _QuickLoginTile(
                    title: 'Kevin Immanuel (Kamar 305 - Putra)',
                    subtitle: 'kevin@gmail.com • Tagihan Sudah Lunas',
                    badge: 'LUNAS',
                    badgeColor: Colors.green.shade700,
                    onTap: () => _attemptLogin(
                      'kevin@gmail.com',
                      'password123',
                    ),
                  ),
                  _QuickLoginTile(
                    title: 'Dinda Maharani (Kamar 202 Dikosongkan)',
                    subtitle: 'dinda@gmail.com • Akun Nonaktif (FR-21)',
                    badge: 'NONAKTIF',
                    badgeColor: Colors.grey.shade700,
                    onTap: () => _attemptLogin(
                      'dinda@gmail.com',
                      'password123',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLoginTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _QuickLoginTile({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      child: ListTile(
        dense: true,
        onTap: onTap,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
