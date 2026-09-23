import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_tenant_page.dart';
import 'invoices_page.dart';
import 'login_page.dart';
import 'theme/app_theme.dart';
import 'utils/formatters.dart';
import 'widgets/app_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _units = [];
  double _totalPaidThisMonth = 0;
  double _totalUnpaidThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUnits(),
      _fetchFinancialSummary(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUnits() async {
    try {
      final response = await Supabase.instance.client
          .from('units')
          .select()
          .order('unit_name', ascending: true);

      setState(() {
        _units = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data unit: $e')),
        );
      }
    }
  }

  Future<void> _fetchFinancialSummary() async {
    try {
      final now = DateTime.now();
      final response = await Supabase.instance.client
          .from('invoices')
          .select('amount, status')
          .eq('period_month', now.month)
          .eq('period_year', now.year);

      double paid = 0;
      double unpaid = 0;

      for (var inv in response) {
        final amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
        if (inv['status'] == 'paid') {
          paid += amount;
        } else {
          unpaid += amount;
        }
      }

      setState(() {
        _totalPaidThisMonth = paid;
        _totalUnpaidThisMonth = unpaid;
      });
    } catch (e) {
      // Abaikan jika tabel tagihan belum dibuat/kosong
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text('Anda perlu masuk lagi untuk mengelola kontrakan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(88, 44),
            ),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  void _showAddUnitDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DEDB),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Tambah unit baru',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unit kosong siap disewakan akan muncul di dashboard.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama / nomor unit',
                    hintText: 'Contoh: Unit A1',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Nama unit wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga sewa / bulan',
                    hintText: '1500000',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Harga sewa wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    try {
                      await Supabase.instance.client.from('units').insert({
                        'unit_name': nameController.text.trim(),
                        'monthly_price':
                            double.parse(priceController.text.trim()),
                        'status': 'vacant',
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Unit baru berhasil ditambahkan'),
                          ),
                        );
                      }
                      _loadDashboardData();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal menambah unit: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan unit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    final occupiedUnits = _units.where((u) => u['status'] == 'occupied').length;
    final vacantUnits = _units.length - occupiedUnits;
    final occupancy = _units.isEmpty ? 0.0 : occupiedUnits / _units.length;
    final now = DateTime.now();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddUnitDialog,
        icon: const Icon(Icons.add_home_work_outlined),
        label: const Text('Tambah unit'),
      ),
      body: _isLoading
          ? const AppLoading()
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadDashboardData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.of(context).padding.top + 12,
                        20,
                        24,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0F766E), Color(0xFF115E59)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _greeting(),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Dashboard kontrakan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _headerIcon(
                                icon: Icons.refresh_rounded,
                                onTap: _loadDashboardData,
                              ),
                              const SizedBox(width: 8),
                              _headerIcon(
                                icon: Icons.logout_rounded,
                                onTap: _logout,
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _heroMetric(
                                  label: 'Pemasukan ${monthName(now.month)}',
                                  value: formatRupiah(_totalPaidThisMonth),
                                  icon: Icons.trending_up_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _heroMetric(
                                  label: 'Belum dibayar',
                                  value: formatRupiah(_totalUnpaidThisMonth),
                                  icon: Icons.schedule_rounded,
                                  muted: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    sliver: SliverList.list(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _statTile(
                                'Total unit',
                                '${_units.length}',
                                Icons.apartment_rounded,
                                AppColors.primarySoft,
                                AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statTile(
                                'Terisi',
                                '$occupiedUnits',
                                Icons.home_work_outlined,
                                AppColors.successSoft,
                                AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statTile(
                                'Kosong',
                                '$vacantUnits',
                                Icons.vpn_key_outlined,
                                AppColors.warningSoft,
                                AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Tingkat hunian',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(occupancy * 100).round()}%',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: occupancy,
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFFE7EEEC),
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        const SectionHeader(
                          title: 'Aksi cepat',
                          subtitle: 'Kelola penyewa dan tagihan harian',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _actionCard(
                                title: 'Tambah penyewa',
                                subtitle: 'Daftarkan hunian baru',
                                icon: Icons.person_add_alt_1_rounded,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddTenantPage(),
                                    ),
                                  );
                                  if (result == true) {
                                    _loadDashboardData();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _actionCard(
                                title: 'Tagihan',
                                subtitle: 'Generate & tandai lunas',
                                icon: Icons.receipt_long_rounded,
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const InvoicesPage(),
                                    ),
                                  );
                                  _loadDashboardData();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        SectionHeader(
                          title: 'Daftar unit',
                          subtitle: '${_units.length} unit terdaftar',
                          action: TextButton(
                            onPressed: _showAddUnitDialog,
                            child: const Text('Tambah'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_units.isEmpty)
                          const EmptyState(
                            icon: Icons.home_work_outlined,
                            title: 'Belum ada unit',
                            message:
                                'Tambah unit kontrakan untuk mulai mendaftarkan penyewa dan tagihan.',
                          )
                        else
                          ..._units.map(_unitCard),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _headerIcon({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _heroMetric({
    required String label,
    required String value,
    required IconData icon,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.08 : 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    String label,
    String value,
    IconData icon,
    Color bg,
    Color fg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: fg, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unitCard(Map<String, dynamic> unit) {
    final status = unit['status'] ?? 'vacant';
    final isOccupied = status == 'occupied';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isOccupied
                    ? AppColors.successSoft
                    : AppColors.warningSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isOccupied
                    ? Icons.home_work_rounded
                    : Icons.vpn_key_outlined,
                color: isOccupied ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit['unit_name'] ?? 'Unit tanpa nama',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatRupiah(unit['monthly_price'])} / bulan',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: isOccupied ? 'Terisi' : 'Kosong',
              color: isOccupied ? AppColors.success : AppColors.warning,
              background:
                  isOccupied ? AppColors.successSoft : AppColors.warningSoft,
            ),
          ],
        ),
      ),
    );
  }
}
