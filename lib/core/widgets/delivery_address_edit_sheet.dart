import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/auth_provider.dart';

class DeliveryAddressEditSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialCustomer;
  final Function(Map<String, dynamic> updatedCustomer)? onSaved;

  const DeliveryAddressEditSheet({
    super.key,
    this.initialCustomer,
    this.onSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? initialCustomer,
    Function(Map<String, dynamic> updatedCustomer)? onSaved,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryAddressEditSheet(
        initialCustomer: initialCustomer,
        onSaved: onSaved,
      ),
    );
  }

  @override
  ConsumerState<DeliveryAddressEditSheet> createState() => _DeliveryAddressEditSheetState();
}

class _DeliveryAddressEditSheetState extends ConsumerState<DeliveryAddressEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _addressController;

  String? _selectedAreaId;
  String? _selectedRoadId;
  String? _selectedSubRoadId;

  String _areaName = '';
  String _roadName = '';
  String _subRoadName = '';

  bool _isLoadingData = true;
  bool _isSaving = false;

  static const Color primaryGreen = Color(0xFF1B3624);
  static const Color textMuted = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    final cust = widget.initialCustomer ?? ref.read(authProvider).customer;

    String initialAddr = (cust?['address'] as String? ?? '').trim();
    if (initialAddr.toUpperCase() == 'N/A') {
      initialAddr = '';
    }
    _addressController = TextEditingController(text: initialAddr);

    _selectedAreaId = cust?['area_id']?.toString();
    _selectedRoadId = cust?['road_id']?.toString();
    _selectedSubRoadId = cust?['sub_road_id']?.toString();

    _areaName = (cust?['area_name'] as String? ?? '').trim();
    _roadName = (cust?['road_name'] as String? ?? '').trim();
    _subRoadName = (cust?['sub_road_name'] as String? ?? '').trim();

    _loadInitialData(cust);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData(Map<String, dynamic>? cust) async {
    try {
      final client = Supabase.instance.client;

      // If area name is missing but areaId exists, fetch area name
      if (_areaName.isEmpty && _selectedAreaId != null && _selectedAreaId!.isNotEmpty) {
        try {
          final res = await client
              .from('areas')
              .select('name')
              .eq('id', _selectedAreaId!)
              .maybeSingle();
          if (res != null && res['name'] != null) {
            _areaName = res['name'].toString();
          }
        } catch (_) {}
      }

      // If road name is missing but roadId exists, fetch road name
      if (_roadName.isEmpty && _selectedRoadId != null && _selectedRoadId!.isNotEmpty) {
        try {
          final res = await client
              .from('roads')
              .select('name')
              .eq('id', _selectedRoadId!)
              .maybeSingle();
          if (res != null && res['name'] != null) {
            _roadName = res['name'].toString();
          }
        } catch (_) {}
      }

      // If sub-road name is missing but subRoadId exists, fetch sub-road name
      if (_subRoadName.isEmpty && _selectedSubRoadId != null && _selectedSubRoadId!.isNotEmpty) {
        try {
          final res = await client
              .from('sub_roads')
              .select('name')
              .eq('id', _selectedSubRoadId!)
              .maybeSingle();
          if (res != null && res['name'] != null) {
            _subRoadName = res['name'].toString();
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      debugPrint('DeliveryAddressEditSheet: Failed to load area/road names: $e');
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final enteredAddress = _addressController.text.trim();
    if (enteredAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your delivery address.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cust = widget.initialCustomer ?? ref.read(authProvider).customer;
      final currentName = (cust?['name'] as String? ?? 'Valued Customer').trim();
      final currentPhone = (cust?['phone'] as String? ?? '').trim();

      await ref.read(authProvider.notifier).updateProfile(
            name: currentName,
            phone: currentPhone,
            address: enteredAddress,
            areaId: _selectedAreaId,
            roadId: _selectedRoadId,
            subRoadId: _selectedSubRoadId,
          );

      final updatedCust = ref.read(authProvider).customer;
      if (updatedCust != null) {
        widget.onSaved?.call(updatedCust);
      }

      if (!mounted) return;
      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text('Delivery address updated successfully!'),
            ],
          ),
          backgroundColor: primaryGreen,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update delivery address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayArea = _areaName.isNotEmpty ? _areaName : 'Assigned with Area';
    final displayRoute = _roadName.isNotEmpty
        ? (_subRoadName.isNotEmpty ? '$_roadName ($_subRoadName)' : _roadName)
        : 'Assigned Route';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Delivery Address',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Update your house, flat, building, or landmark details',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (_isLoadingData) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: primaryGreen),
                    ),
                  ),
                ] else ...[
                  // Read-Only Delivery Area & Route Information Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_outline_rounded, size: 16, color: textMuted),
                            const SizedBox(width: 6),
                            Text(
                              'STORE ASSIGNED DELIVERY ROUTE',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 18, color: primaryGreen),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Area',
                                    style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                                  ),
                                  Text(
                                    displayArea,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.alt_route_outlined, size: 18, color: primaryGreen),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Delivery Route / Road',
                                    style: GoogleFonts.inter(fontSize: 11, color: textMuted),
                                  ),
                                  Text(
                                    displayRoute,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Editable Delivery Address Text Field
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'House No / Flat / Building / Landmark *',
                      labelStyle: const TextStyle(fontSize: 14, color: primaryGreen),
                      prefixIcon: const Icon(Icons.home_outlined, color: primaryGreen),
                      hintText: 'e.g. Flat 302, Green Heights, Opp. Garden',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: textMuted),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: primaryGreen, width: 2),
                      ),
                    ),
                    maxLines: 3,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your delivery address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              'Save Delivery Address',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
