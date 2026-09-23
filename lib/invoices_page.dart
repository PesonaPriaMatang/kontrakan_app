import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'utils/formatters.dart';
import 'widgets/app_ui.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _invoices = [];
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('invoices')
          .select('*, units(unit_name), profiles(full_name)')
          .order('due_date', ascending: false);

      setState(() {
        _invoices = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil data tagihan: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMonthlyInvoices() async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();

      final activeTenants = await supabase
          .from('profiles')
          .select('*, units(monthly_price)')
          .eq('role', 'tenant')
          .not('unit_id', 'is', null);

      int createdCount = 0;

      for (var tenant in activeTenants) {
        final unitId = tenant['unit_id'];
        final tenantId = tenant['id'];
        final amount = tenant['units']?['monthly_price'] ?? 0;

        final existing = await supabase
            .from('invoices')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('period_month', now.month)
            .eq('period_year', now.year);

        if (existing.isEmpty) {
          final dueDate = DateTime(now.year, now.month, 10);
          await supabase.from('invoices').insert({
            'tenant_id': tenantId,
            'unit_id': unitId,
            'amount': amount,
            'due_date': dueDate.toIso8601String().split('T')[0],
            'period_month': now.month,
            'period_year': now.year,
            'status': 'unpaid',
          });
          createdCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berhasil membuat $createdCount tagihan baru')),
        );
      }
      _fetchInvoices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat tagihan: $e')),
        );
      }
    }
  }

  Future<void> _markAsPaid(String invoiceId) async {
    try {
      await Supabase.instance.client.from('invoices').update({
        'status': 'paid',
        'payment_date': DateTime.now().toIso8601String(),
      }).eq('id', invoiceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan ditandai lunas')),
        );
      }
      _fetchInvoices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui status: $e')),
        );
      }
    }
  }

  Future<void> _deleteInvoice(String invoiceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tagihan?'),
        content: const Text('Tagihan ini akan dihapus permanen.'),
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
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('invoices')
            .delete()
            .eq('id', invoiceId);

        _fetchInvoices();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus tagihan: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _invoices.where((inv) {
      if (_filterStatus == 'paid') return inv['status'] == 'paid';
      if (_filterStatus == 'unpaid') return inv['status'] == 'unpaid';
      return true;
    }).toList();

    final paidCount = _invoices.where((inv) => inv['status'] == 'paid').length;
    final unpaidCount =
        _invoices.where((inv) => inv['status'] == 'unpaid').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tagihan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchInvoices,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoading()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _miniStat('Semua', '${_invoices.length}'),
                            ),
                            Expanded(
                              child: _miniStat('Belum bayar', '$unpaidCount'),
                            ),
                            Expanded(
                              child: _miniStat('Lunas', '$paidCount'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _generateMonthlyInvoices,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: const Text('Generate tagihan bulan ini'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _filterChip('Semua', 'all'),
                      const SizedBox(width: 8),
                      _filterChip('Belum bayar', 'unpaid'),
                      const SizedBox(width: 8),
                      _filterChip('Lunas', 'paid'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: filteredInvoices.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Tidak ada tagihan',
                            message:
                                'Generate tagihan bulan ini atau ubah filter untuk melihat data lain.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          itemCount: filteredInvoices.length,
                          itemBuilder: (context, index) {
                            final inv = filteredInvoices[index];
                            final isPaid = inv['status'] == 'paid';
                            final unitName =
                                inv['units']?['unit_name'] ?? 'Unit';
                            final tenantName =
                                inv['profiles']?['full_name'] ?? 'Penyewa';
                            final period =
                                '${monthName(inv['period_month'] as num?)} ${inv['period_year']}';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
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
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                unitName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                tenantName,
                                                style: const TextStyle(
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        StatusBadge(
                                          label: isPaid ? 'Lunas' : 'Belum bayar',
                                          color: isPaid
                                              ? AppColors.success
                                              : AppColors.danger,
                                          background: isPaid
                                              ? AppColors.successSoft
                                              : AppColors.dangerSoft,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      formatRupiah(inv['amount']),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Periode $period · Jatuh tempo ${formatDate(inv['due_date'])}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        if (!isPaid)
                                          Expanded(
                                            child: FilledButton(
                                              onPressed: () =>
                                                  _markAsPaid(inv['id']),
                                              style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(44),
                                              ),
                                              child: const Text('Tandai lunas'),
                                            ),
                                          )
                                        else
                                          const Expanded(
                                            child: Text(
                                              'Pembayaran sudah dicatat',
                                              style: TextStyle(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        IconButton(
                                          tooltip: 'Hapus tagihan',
                                          onPressed: () =>
                                              _deleteInvoice(inv['id']),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filterStatus = value),
      selectedColor: AppColors.primarySoft,
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryDark : AppColors.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
