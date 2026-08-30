import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_provider.dart';
import 'password_rules_helper.dart';
import '../dashboard/home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  List<Map<String, dynamic>> _areas = [];
  List<Map<String, dynamic>> _roads = [];
  List<Map<String, dynamic>> _subRoads = [];
  String? _selectedAreaId;
  String? _selectedRoadId;
  String? _selectedSubRoadId;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  void _loadAreas() async {
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('areas')
          .select()
          .order('name', ascending: true);
      setState(() {
        _areas = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Failed to load areas: $e');
    }
  }

  void _loadRoads(String areaId) async {
    setState(() {
      _roads = [];
      _subRoads = [];
      _selectedRoadId = null;
      _selectedSubRoadId = null;
    });
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('roads')
          .select()
          .eq('area_id', areaId)
          .order('name', ascending: true);
      setState(() {
        _roads = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Failed to load roads: $e');
    }
  }

  void _loadSubRoads(String roadId) async {
    setState(() {
      _subRoads = [];
      _selectedSubRoadId = null;
    });
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('sub_roads')
          .select()
          .eq('road_id', roadId)
          .order('name', ascending: true);
      setState(() {
        _subRoads = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('Failed to load sub-roads: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please agree to the Terms of Service & Privacy Policy to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your delivery Area.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedRoadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your delivery Road.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final success = await ref.read(authProvider.notifier).register(
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            address: _addressController.text.trim(),
            areaId: _selectedAreaId,
            roadId: _selectedRoadId,
            subRoadId: _selectedSubRoadId,
          );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Welcome to Orderkart.')),
        );
      } else {
        final err = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Registration failed. The mobile number may already be in use.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Create Account',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1B3624),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1B3624), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Sign Up',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B3624),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Register to order farm-fresh vegetables weekly',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1B3624)),
                        hintText: 'e.g. Priya Patel',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Mobile Number
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20, color: Color(0xFF1B3624)),
                        hintText: 'Enter 10-digit mobile number',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your mobile number';
                        }
                        if (val.trim().length < 10) {
                          return 'Enter valid 10-digit number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Password
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      onChanged: (val) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Set Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1B3624)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (!PasswordRulesHelper.isPasswordStrong(val)) {
                          return 'Password does not meet strength requirements';
                        }
                        return null;
                      },
                    ),
                    PasswordRulesHelper(password: _passwordController.text),
                    const SizedBox(height: 16),

                    // Confirm Password
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF1B3624)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      validator: (val) {
                        if (val != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Area Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAreaId,
                      decoration: InputDecoration(
                        labelText: 'Select Area',
                        prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF1B3624)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      items: _areas.map((a) {
                        return DropdownMenuItem<String>(
                          value: a['id'] as String,
                          child: Text(a['name'] as String),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAreaId = val;
                          });
                          _loadRoads(val);
                        }
                      },
                      validator: (val) => val == null ? 'Please select an area' : null,
                    ),
                    const SizedBox(height: 16),

                    // Road Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoadId,
                      decoration: InputDecoration(
                        labelText: 'Select Road',
                        prefixIcon: const Icon(Icons.alt_route_outlined, color: Color(0xFF1B3624)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      disabledHint: const Text('Select an Area first'),
                      items: _selectedAreaId == null
                          ? []
                          : _roads.map((r) {
                              return DropdownMenuItem<String>(
                                value: r['id'] as String,
                                child: Text(r['name'] as String),
                              );
                            }).toList(),
                      onChanged: _selectedAreaId == null
                          ? null
                          : (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRoadId = val;
                                });
                                _loadSubRoads(val);
                              }
                            },
                      validator: (val) => val == null ? 'Please select a road' : null,
                    ),
                    const SizedBox(height: 16),

                    // Sub-Road Dropdown (Optional)
                    if (_selectedRoadId != null && _subRoads.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selectedSubRoadId,
                        decoration: InputDecoration(
                          labelText: 'Select Sub-Road (Optional)',
                          prefixIcon: const Icon(Icons.subdirectory_arrow_right_outlined, color: Color(0xFF1B3624)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        ),
                        items: _subRoads.map((sr) {
                          return DropdownMenuItem<String>(
                            value: sr['id'] as String,
                            child: Text(sr['name'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedSubRoadId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Delivery Address / Flat / Landmark',
                        prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF1B3624)),
                        hintText: 'e.g. Flat 302, Green Heights, Baner, Pune',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      maxLines: 2,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your delivery address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          activeColor: const Color(0xFF1B3624),
                          onChanged: (val) {
                            setState(() {
                              _agreeToTerms = val ?? false;
                            });
                          },
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Terms of Service & Privacy Policy',
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B3624),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        onPressed: authState.isLoading ? null : _submit,
                        child: authState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text(
                                'CREATE ACCOUNT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

