import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../../core/utils/string_utils.dart';
import '../../core/widgets/ambient_background.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final bool showAppBar;

  const ProfileScreen({super.key, this.showAppBar = true});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Theme constants matching 'Your Harvest' theme
  static const Color bgScaffold = Color(0xFFF7F5EE);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textColorPrimary = Color(0xFF1B3624);
  static const Color textColorSecondary = Color(0xFF6E7E73);
  static const Color borderPillColor = Color(0xFFD4AF37);

  void _showHelpBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Customer Support',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColorPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textColorSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'How can we help you today? Connect with our store directly.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColorSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                // WhatsApp button
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final customer = ref.read(authProvider).customer;
                    final String rawName = sanitizeCustomerName(customer?['name']);
                    final String msg = 'Hello Orderkart Support! I am $rawName, and I need assistance with my order.';
                    final String encodedMsg = Uri.encodeComponent(msg);
                    final whatsappUri = Uri.parse('whatsapp://send?phone=919021107009&text=$encodedMsg');
                    final webUri = Uri.parse('https://wa.me/919021107009?text=$encodedMsg');
                    
                    try {
                      bool launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                      if (!launched) {
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {
                      try {
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not launch WhatsApp Support')),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                  label: const Text('Chat on WhatsApp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Call button
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('tel:+919021107009');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch Phone Dial')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.phone_outlined, color: Colors.white),
                  label: const Text('Call Us Directly', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColorPrimary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: textColorPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Welcome to Orderkart! By accessing this shopping app, you agree to comply with and be bound by the following terms:',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                '1. Account & Security\nCustomer accounts are manually assigned unique codes by the shop admin. Keep your login code secure. Any order placed under your account code is assumed to be authorized by you.',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColorPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '2. Product Quality & Weights\nVegetables and fruits are sold fresh. The weights may vary slightly due to natural weight loss during transit. Prices are updated daily based on wholesale market rates.',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '3. Delivery & Payments\nOrders are delivered to your registered home address. Payment terms are configured individually for cash or digital settlement on delivery.',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: borderPillColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: textColorPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Orderkart is committed to safeguarding your privacy. Our data collection and storage rules are detailed below:',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                '1. Personal Information Collected\nWe collect and store your name, phone number, delivery address, and order transaction history. This data is used solely to manage deliveries, payments, and balances.',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: textColorPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                '2. Data Portability & Storage\nYour profile details and transaction logs are stored securely on the Supabase database. Local Order history data remains in the shop merchant app SQLite system for offline accounting.',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '3. Third-party Sharing\nWe do not sell, rent, or trade customer information with third parties. Data is only accessible to authorized Orderkart admins and delivery personnel.',
                style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: borderPillColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }


  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Change Password',
                style: GoogleFonts.playfairDisplay(
                  fontWeight: FontWeight.bold,
                  color: textColorPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Set a new password for your Orderkart customer account.',
                        style: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: textColorPrimary),
                        ),
                        validator: (val) {
                          if (val == null || val.length < 4) {
                            return 'Password must be at least 4 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: Icon(Icons.lock_outline, color: textColorPrimary),
                        ),
                        validator: (val) {
                          if (val != newPassCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChanging ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: textColorSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: textColorPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isChanging
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => isChanging = true);
                            final success = await ref.read(authProvider.notifier).changePassword(newPassCtrl.text);
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            final err = ref.read(authProvider).error;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success
                                    ? 'Password changed successfully!'
                                    : (err != null && err.isNotEmpty ? err : 'Failed to update password. Please try again.')),
                                backgroundColor: success ? textColorPrimary : Colors.red,
                              ),
                            );
                          }
                        },
                  child: isChanging
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: bgCard,
        title: Text(
          'Logout',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: textColorPrimary,
          ),
        ),
        content: const Text('Are you sure you want to log out of Orderkart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: textColorSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[850],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.customer == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your profile.')),
      );
    }

    final String name = sanitizeCustomerName(authState.customer!['name']);
    final String phone = authState.customer!['phone'] ?? 'N/A';
    final String address = authState.customer!['address'] ?? 'N/A';
    final String code = authState.customer!['customer_code'] ?? 'N/A';
    final String areaName = authState.customer!['area_name'] ?? 'N/A';
    final String roadName = authState.customer!['road_name'] ?? 'N/A';
    final String subRoadName = authState.customer!['sub_road_name'] ?? '';
    final String routeDetails = subRoadName.isNotEmpty ? '$roadName ($subRoadName)' : roadName;

    Widget content = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant Header Profile Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: textColorPrimary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: textColorPrimary.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                )
              ]
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/orderkart_logo.png',
                    height: 34,
                    width: 125,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 38,
                  backgroundColor: bgScaffold,
                  child: Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: textColorPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: borderPillColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Code: $code',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 28),

          // static customer details list
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Account Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColorPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColorSecondary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_outlined, color: textColorPrimary),
                  title: const Text('Registered Mobile', style: TextStyle(fontSize: 12, color: textColorSecondary)),
                  subtitle: Text(
                    phone,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary, fontSize: 15),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: textColorPrimary),
                  title: const Text('Delivery Address', style: TextStyle(fontSize: 12, color: textColorSecondary)),
                  subtitle: Text(
                    address,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary, fontSize: 14),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.map_outlined, color: textColorPrimary),
                  title: const Text('Delivery Area', style: TextStyle(fontSize: 12, color: textColorSecondary)),
                  subtitle: Text(
                    areaName,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary, fontSize: 14),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.route_outlined, color: textColorPrimary),
                  title: const Text('Delivery Route', style: TextStyle(fontSize: 12, color: textColorSecondary)),
                  subtitle: Text(
                    routeDetails,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Support & Policies Section
          Text(
            'Information & Support',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColorPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColorSecondary.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined, color: textColorPrimary),
                  title: const Text('Contact Help & Support', style: TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColorSecondary),
                  onTap: () => _showHelpBottomSheet(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: textColorPrimary),
                  title: const Text('Terms & Conditions', style: TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColorSecondary),
                  onTap: () => _showTermsDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: textColorPrimary),
                  title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColorSecondary),
                  onTap: () => _showPrivacyDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: textColorPrimary),
                  title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, color: textColorPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textColorSecondary),
                  onTap: () => _showChangePasswordDialog(context, ref),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.showAppBar) {
      return AmbientBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle.dark,
            title: Text(
              'My Profile',
              style: GoogleFonts.playfairDisplay(
                fontWeight: FontWeight.bold,
                color: textColorPrimary,
              ),
            ),
          ),
          body: content,
        ),
      );
    } else {
      return AmbientBackground(child: content);
    }
  }
}
