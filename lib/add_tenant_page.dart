import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'utils/formatters.dart';
import 'widgets/app_ui.dart';

class AddTenantPage extends StatefulWidget {
  const AddTenantPage({super.key});

  @override
  State<AddTenantPage> createState() => _AddTenantPageState();
}

class _AddTenantPageState extends State<AddTenantPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  List<Map<String, dynamic>> _availableUnits = [];
  String? _selectedUnitId;
  String _billingScheme = 'exact_date';
  bool _isLoadingUnits = true;
  bool _isSaving = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _fetchAvailableUnits();
  }

  Future<void> _fetchAvailableUnits() async {
    try {
      final response = await Supabase.instance.client
          .from('units')
          .select()
          .or('status.eq.vacant,status.eq.available,status.eq.Kosong,status.eq.kosong');

      setState(() {
        _availableUnits = List<Map<String, dynamic>>.from(response);
        _isLoadingUnits = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil daftar unit: $e')),
        );
      }
      setState(() => _isLoadingUnits = false);
    }
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih unit kontrakan terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      final res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final newUserId = res.user?.id;
      if (newUserId != null) {
        await supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'role': 'tenant',
          'unit_id': _selectedUnitId,
          'entry_date': DateTime.now().toIso8601String().split('T')[0],
          'billing_scheme': _billingScheme,
        });

        await supabase.from('tenants').insert({
          'unit_id': _selectedUnitId,
          'profile_id': newUserId,
          'tenant_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'start_date': DateTime.now().toIso8601String().split('T')[0],
        });

        await supabase
            .from('units')
            .update({'status': 'occupied'})
            .eq('id', _selectedUnitId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Penyewa berhasil didaftarkan dan unit terisi'),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendaftarkan penyewa: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Penyewa baru')),
      body: _isLoadingUnits
          ? const AppLoading()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Daftarkan hunian',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Isi data penyewa, pilih unit kosong, lalu buat akun login.',
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 22),
                    if (_availableUnits.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Belum ada unit kosong. Tambah unit baru di dashboard terlebih dahulu.',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unit kontrakan kosong',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        items: _availableUnits.map((unit) {
                          return DropdownMenuItem<String>(
                            value: unit['id'].toString(),
                            child: Text(
                              '${unit['unit_name']} · ${formatRupiah(unit['monthly_price'])}',
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => _selectedUnitId = val,
                      ),
                    const SizedBox(height: 22),
                    const Text(
                      'Data penyewa',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama lengkap',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nama tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WhatsApp / HP',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nomor HP tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Akun login',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Email tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Kata sandi',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (val) => val == null || val.length < 6
                          ? 'Password minimal 6 karakter'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Skema tagihan',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _schemeCard(
                      value: 'exact_date',
                      title: 'Tanggal masuk',
                      subtitle:
                          'Tagihan jatuh tempo setiap bulan di tanggal yang sama.',
                    ),
                    const SizedBox(height: 10),
                    _schemeCard(
                      value: 'prorated',
                      title: 'Prorata',
                      subtitle:
                          'Hari pertama dipotong, lalu tagihan serentak setiap tanggal 1.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSaving ? null : _saveTenant,
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Daftarkan penyewa'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _schemeCard({
    required String value,
    required String title,
    required String subtitle,
  }) {
    final selected = _billingScheme == value;
    return Material(
      color: selected ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => setState(() => _billingScheme = value),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : AppColors.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
