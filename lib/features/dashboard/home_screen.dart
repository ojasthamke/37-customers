import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../catalog/catalog_provider.dart';
import '../catalog/product_listing_screen.dart';
import '../cart/cart_provider.dart';
import '../cart/cart_screen.dart';
import '../order/my_orders_screen.dart';
import '../order/order_provider.dart';
import '../profile/profile_screen.dart';
import '../order/order_details_screen.dart';
import '../../core/utils/schedule_helper.dart';
import '../../core/widgets/quantity_selector.dart';
import '../../core/utils/string_utils.dart';
import '../../core/services/notification_service.dart';
import '../../core/database/providers.dart';
import '../../core/widgets/glass_container.dart';
import '../../core/widgets/skeleton_loader.dart';
import 'schedule_banner.dart';

final activeTabProvider = StateProvider<int>((ref) => 0);
final cartOriginTabProvider = StateProvider<int>((ref) => 0);

final lastOrderProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return null;
    
    final res = await client
        .from('orders')
        .select('*, order_items(*)')
        .eq('customer_id', userId)
        .order('order_date', ascending: false)
        .limit(1)
        .maybeSingle();
        
    return res;
  } catch (_) {
    return null;
  }
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int get _currentTab => ref.read(activeTabProvider);
  set _currentTab(int index) => ref.read(activeTabProvider.notifier).state = index;
  bool _shrinkActiveOrders = false;
  bool _userExpanded = false;
  bool _isLoadingReorder = false;
  DateTime? _lastActionTime;
  Timer? _shrinkTimer;
  Timer? _autoScrollTimer;
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _productsSectionKey = GlobalKey();

  bool _canPerformAction() {
    final now = DateTime.now();
    if (_lastActionTime != null && now.difference(_lastActionTime!) < const Duration(milliseconds: 400)) {
      return false;
    }
    _lastActionTime = now;
    return true;
  }

  void _scrollToProductsSection() {
    final ctx = _productsSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    } else if (_homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        600.0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _handleReorderTap(BuildContext context, WidgetRef ref, Map<String, dynamic> lastOrder) async {
    if (_isLoadingReorder || !_canPerformAction()) return;
    final items = lastOrder['order_items'] as List<dynamic>? ?? [];
    if (items.isEmpty) return;

    final productIds = items
        .map((i) => i['product_id']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toList();

    if (productIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No reorderable items found in this order.')),
      );
      return;
    }

    _isLoadingReorder = true;
    bool isDialogVisible = true;
    void dismissLoading() {
      if (isDialogVisible && context.mounted) {
        Navigator.pop(context);
        isDialogVisible = false;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final client = Supabase.instance.client;
      final response = await client.from('products').select().inFilter('id', productIds).timeout(const Duration(seconds: 10));
      if (!context.mounted) return;
      dismissLoading();
      final currentProducts = List<Map<String, dynamic>>.from(response);
      if (!context.mounted) return;
      _showReorderDialog(context, ref, items, currentProducts);
    } catch (_) {
      try {
        // Offline / fallback: Read cached products from local SQLite repository
        final localRepo = ref.read(catalogRepositoryProvider);
        final allLocal = await localRepo.getProducts();
        final currentProducts = allLocal.where((p) => productIds.contains(p['id']?.toString())).toList();
        if (!context.mounted) return;
        dismissLoading();
        if (currentProducts.isNotEmpty) {
          _showReorderDialog(context, ref, items, currentProducts);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load products. Please check your connection.')),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        dismissLoading();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load current prices: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      dismissLoading();
      _isLoadingReorder = false;
    }
  }

  void _startShrinkTimerIfNeeded(int count) {
    if (count == 1) {
      if (_shrinkTimer == null && !_shrinkActiveOrders) {
        _shrinkTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _shrinkActiveOrders = true;
            });
          }
        });
      }
    } else {
      if (_shrinkTimer != null) {
        _shrinkTimer?.cancel();
        _shrinkTimer = null;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupNotificationListener();
      }
    });
  }

  void _setupNotificationListener() {
    try {
      final customer = ref.read(authProvider).customer;
      final currentCustId = customer?['id']?.toString();
      final currentAreaId = customer?['area_id']?.toString();
      NotificationService.instance.startRealtimeNotificationSync(
        customerId: currentCustId,
        areaId: currentAreaId,
      );
    } catch (e) {
      debugPrint('Failed to set up notification sync: $e');
    }
  }

  void _showHelpBottomSheet(BuildContext context) {
    if (!_canPerformAction()) return;
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
                      tooltip: 'Close',
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
                    final String rawName = sanitizeCustomerName(customer?['name'], customerCode: customer?['customer_code']);
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
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
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

  // Color constants from the warm premium 'Your Harvest' theme
  static const Color bgScaffold = Color(0xFFF7F5EE);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textColorPrimary = Color(0xFF1B3624);
  static const Color textColorSecondary = Color(0xFF6E7E73);
  static const Color borderPillColor = Color(0xFFD4AF37);

  void _onTabChanged(int index) {
    if (_currentTab == index) return;

    if (index == 1) {
      ref.read(cartOriginTabProvider.notifier).state = _currentTab;
      ref.read(isViewingQuickOrderCartProvider.notifier).state = false;
    }

    setState(() {
      _currentTab = index;
    });
  }

  void _handleBackPressed() {
    if (_currentTab != 0) {
      final origin = ref.read(cartOriginTabProvider);
      if (_currentTab == 1 && origin != 1) {
        _onTabChanged(origin);
      } else {
        _onTabChanged(0);
      }
    }
  }

  @override
  void dispose() {
    _shrinkTimer?.cancel();
    _autoScrollTimer?.cancel();
    _homeScrollController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    ref.watch(activeTabProvider);
    ref.listen<AuthState?>(authProvider, (previous, next) {
      if (next != null && next.customer == null && !next.isLoading) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    });

    ref.listen<AsyncValue<Map<String, String>>>(appSettingsProvider, (previous, next) {
      final prevClosed = isStoreClosed(previous?.valueOrNull);
      final nextClosed = isStoreClosed(next.valueOrNull);
      if (!prevClosed && nextClosed) {
        NotificationService.instance.showNotification(
          id: 999,
          title: 'Store Closed 🔴',
          body: 'We will be back in some time.',
        );
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Store Closed 🔴',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'We are currently not accepting new orders. We will be back in some time.',
              style: GoogleFonts.inter(fontSize: 14.5, color: const Color(0xFF475569)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        );
      }
    });

    final normalCart = ref.watch(cartProvider);
    final normalCartCount = normalCart.itemCount;
    final normalCartSubtotal = normalCart.subtotal;

    // Body widgets corresponding to tabs
    final List<Widget> tabs = [
      _buildHomeTab(),
      CartScreen(
        showAppBar: false,
        onBrowseClicked: () => _onTabChanged(0),
      ),
      const MyOrdersScreen(showAppBar: false),
      const ProfileScreen(showAppBar: false),
    ];

    final List<String> appBarTitles = [
      'ApliBhaji',
      'My Cart',
      'My Orders',
      'My Profile',
    ];

    return PopScope(
      canPop: _currentTab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 62,
        titleSpacing: _currentTab == 0 ? 14 : 0,
        leading: _currentTab != 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorPrimary, size: 20),
                tooltip: 'Back',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _handleBackPressed();
                },
              )
            : null,
        title: _currentTab == 0
            ? GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _currentTab = 0;
                  });
                  ref.invalidate(categoriesProvider);
                  ref.invalidate(popularProductsProvider);
                  ref.invalidate(lastOrderProvider);
                  ref.invalidate(orderListProvider);
                  ref.invalidate(appSettingsProvider);
                  ref.invalidate(authProvider);
                  if (_homeScrollController.hasClients) {
                    _homeScrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/orderkart_logo.png',
                    height: 48,
                    width: 144,
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              )
            : Text(
                appBarTitles[_currentTab],
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: textColorPrimary,
                  fontSize: 22,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
        actions: [
          if (_currentTab == 0)
            ref.watch(lastOrderProvider).maybeWhen(
              data: (lastOrder) {
                if (lastOrder == null) return const SizedBox.shrink();
                final items = lastOrder['order_items'] as List<dynamic>? ?? [];
                if (items.isEmpty) return const SizedBox.shrink();

                return TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.history_rounded, color: textColorPrimary, size: 16),
                  label: Text(
                    'Reorder',
                    style: GoogleFonts.inter(
                      color: textColorPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  onPressed: () => _handleReorderTap(context, ref, lastOrder),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.headset_mic_rounded, color: textColorPrimary, size: 16),
            label: Text(
              'Help',
              style: GoogleFonts.inter(
                color: textColorPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            onPressed: () => _showHelpBottomSheet(context),
          ),
          const SizedBox(width: 8),
          if (_currentTab == 0) ...[
            // Quick cart button
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined, color: textColorPrimary, size: 26),
                  tooltip: 'Shopping Cart',
                  onPressed: () {
                    _onTabChanged(1);
                  },
                ),
                if (normalCartCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: borderPillColor, // gold count badge
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        normalCartCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
          ]
        ],
      ),
      body: Stack(
        children: [
          // Ambient background botanical mesh gradient (Feature 20)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8F5E9), // Soft fresh green
                    Color(0xFFF7F5EE), // Warm sand cream
                    Color(0xFFFFF8E7), // Sunny honeydew tint
                  ],
                ),
              ),
            ),
          ),
          // Multi-layer organic mesh blobs for glassmorphism refraction
          Positioned(
            top: -40,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFA5D6A7).withValues(alpha: 0.38),
                    const Color(0xFFA5D6A7).withValues(alpha: 0.14),
                    const Color(0xFFA5D6A7).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            top: 320,
            right: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD54F).withValues(alpha: 0.28),
                    const Color(0xFFFFD54F).withValues(alpha: 0.10),
                    const Color(0xFFFFD54F).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCE93D8).withValues(alpha: 0.20),
                    const Color(0xFFCE93D8).withValues(alpha: 0.06),
                    const Color(0xFFCE93D8).withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          IndexedStack(
            index: _currentTab,
            children: tabs,
          ),
          if (_currentTab == 0 && normalCartCount > 0)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildFloatingCartBar(normalCartCount, normalCartSubtotal),
            ),
        ],
      ),
      // Modern Floating Glass Dock Bottom Navigation Bar (Feature 3)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B3624).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFloatingDockItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _buildFloatingDockItem(1, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'Cart', badgeCount: normalCartCount),
                _buildFloatingDockItem(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Orders'),
                _buildFloatingDockItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildFloatingDockItem(int index, IconData outlineIcon, IconData filledIcon, String label, {int badgeCount = 0}) {
    final isSelected = _currentTab == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          _onTabChanged(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(vertical: isSelected ? 6.0 : 4.0, horizontal: 4.0),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B3624) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1B3624).withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isSelected ? filledIcon : outlineIcon,
                      color: isSelected ? Colors.white : textColorSecondary,
                      size: 22,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: borderPillColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 99 ? '99+' : badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    final categoriesAsync = ref.watch(categoriesProvider);
    final popularProductsAsync = ref.watch(popularProductsProvider);
    final customer = ref.watch(authProvider).customer;
    final welcomeName = sanitizeCustomerName(customer?['name'], customerCode: customer?['customer_code']);

    if (categoriesAsync.isLoading || popularProductsAsync.isLoading) {
      return Container(
        color: bgScaffold,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  'assets/orderkart_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome, $welcomeName!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColorPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Preparing your fresh produce...',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: textColorSecondary,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(textColorPrimary),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1B3624),
      backgroundColor: const Color(0xFFF7F5EE),
      strokeWidth: 2.8,
      displacement: 36,
      edgeOffset: 8,
      onRefresh: () async {
        ref.invalidate(categoriesProvider);
        ref.invalidate(popularProductsProvider);
        ref.invalidate(lastOrderProvider);
        ref.invalidate(orderListProvider);
        ref.invalidate(appSettingsProvider);
        await ref.read(authProvider.notifier).loadCurrentCustomer();
      },
      child: SingleChildScrollView(
        controller: _homeScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hello / Welcome bar (Feature 19)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Welcome, $welcomeName!',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColorPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ref.watch(appSettingsProvider).maybeWhen(
                  data: (settings) {
                    final isOpen = !isStoreClosed(settings);
                    final schedule = settings['store_schedule'] ?? '';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlassContainer(
                          borderRadius: 12,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isOpen ? 'OPEN' : 'CLOSED',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isOpen ? const Color(0xFF1B3624) : const Color(0xFFC62828),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (schedule.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            schedule,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFD4AF37),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                  orElse: () => GlassContainer(
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'OPEN',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B3624),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Making every house weekly shopping easy and affordable !',
              style: GoogleFonts.inter(color: textColorSecondary, fontSize: 13.5, fontWeight: FontWeight.w500),
            ),
            if (customer?['is_guest'] == true || customer?['is_guest'] == 1) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD54F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Logged in as Guest. Contact support to become a member!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF57F17),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse('https://wa.me/919021107009?text=Hi%20Orderkart%20Support!%20I%20want%20to%20become%20a%20member.');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                            label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF25D366),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse('tel:+919021107009');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            icon: const Icon(Icons.call, size: 16, color: Color(0xFF1B3624)),
                            label: const Text('Call', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1B3624),
                              side: const BorderSide(color: Color(0xFF1B3624)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ScheduleBanner(onStartPreOrderTap: _scrollToProductsSection),
            const SizedBox(height: 14),

            // Active Orders Banner with Live Step Tracker & Pulsing Beacon (Features 4 & 5)
            ref.watch(orderListProvider).when(
              data: (orders) {
                final activeOrders = orders.where((order) {
                  final status = (order['status'] ?? 'Pending').toString().toLowerCase();
                  return status != 'delivered' && status != 'cancelled';
                }).toList();

                if (activeOrders.isEmpty) return const SizedBox.shrink();
                
                // Set up shrink timer on frame complete
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startShrinkTimerIfNeeded(activeOrders.length);
                });

                final bool shouldCollapse = (activeOrders.length > 1 || _shrinkActiveOrders) && !_userExpanded;

                Widget buildFullOrderCard(dynamic order) {
                  final orderId = order['id'];
                  final orderNo = order['order_number'] ?? order['offline_order_no'] ?? 'N/A';
                  final orderType = order['order_type'] ?? 'Normal';
                  final status = order['status'] ?? 'Pending';
                  List<dynamic> items = [];
                  final rawItems = order['order_items'];
                  if (rawItems is List) {
                    items = rawItems;
                  } else if (rawItems is String && rawItems.trim().isNotEmpty) {
                    try {
                      final decoded = json.decode(rawItems);
                      if (decoded is List) items = decoded;
                    } catch (_) {}
                  }
                  final deliveryDateStr = order['delivery_date']?.toString();
                  
                  DateTime? deliveryDate;
                  if (deliveryDateStr != null && deliveryDateStr.isNotEmpty) {
                    deliveryDate = DateTime.tryParse(deliveryDateStr);
                  }
                  
                  String formattedDelivery = 'Scheduled soon';
                  if (deliveryDate != null) {
                    formattedDelivery = AreaScheduleHelper.formatDayAndDate(deliveryDate);
                  }
                  
                  final isPreOrder = orderType.toLowerCase() == 'pre-order';
                  
                  String displayStatus = status;
                  Color statusColor;
                  if (status.toLowerCase() == 'pending') {
                    if (isPreOrder) {
                      displayStatus = 'Pre-Ordered';
                      statusColor = Colors.orange[800]!;
                    } else {
                      displayStatus = 'Pending Approval';
                      statusColor = Colors.amber[800]!;
                    }
                  } else {
                    switch (status) {
                      case 'Confirmed': statusColor = const Color(0xFF2563EB); break;
                      case 'Preparing': statusColor = const Color(0xFF7C3AED); break;
                      case 'Out for Delivery': statusColor = const Color(0xFF0D9488); break;
                      default: statusColor = Colors.grey;
                    }
                  }

                  void onTap() {
                    if (orderId == null || !_canPerformAction()) return;
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OrderDetailsScreen(orderId: orderId.toString()),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GlassContainer(
                      borderRadius: 20,
                      padding: const EdgeInsets.all(16),
                      onTap: onTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isPreOrder ? Icons.event_available_rounded : Icons.local_shipping_rounded,
                                    color: textColorPrimary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isPreOrder ? 'Active Pre-Order' : 'Active Order',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: textColorPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 0.5),
                                ),
                                child: Text(
                                  displayStatus,
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${items.length} items • Order #$orderNo',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              color: textColorSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Step-by-Step Live Order Tracker (Feature 4)
                          _buildOrderStepTimeline(status, isPreOrder),
                          
                          const SizedBox(height: 8),
                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isPreOrder
                                    ? [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)]
                                    : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPreOrder ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Pulsing Realtime Delivery Beacon (Feature 5)
                                _buildPulsingBeacon(
                                  color: isPreOrder ? const Color(0xFFD97706) : const Color(0xFF059669),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'Delivery: ',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: isPreOrder ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                          ),
                                        ),
                                        TextSpan(
                                          text: formattedDelivery,
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: isPreOrder ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                          ),
                                        ),
                                      ],
                                    ),
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

                Widget buildConsolidatedRow({required bool isExpanded}) {
                  final count = activeOrders.length;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GlassContainer(
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      onTap: () {
                        setState(() {
                          _userExpanded = !isExpanded;
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.shopping_bag_rounded,
                              color: Color(0xFF059669),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  count == 1 ? 'You have 1 active order' : 'You have $count active orders',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                    color: textColorPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isExpanded ? 'Tap to collapse' : 'Tap to view details',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: textColorSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: textColorPrimary,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return AnimatedCrossFade(
                  duration: const Duration(milliseconds: 400),
                  firstCurve: Curves.easeInOutCubic,
                  secondCurve: Curves.easeInOutCubic,
                  sizeCurve: Curves.easeInOutCubic,
                  crossFadeState: shouldCollapse ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                  firstChild: buildConsolidatedRow(isExpanded: false),
                  secondChild: Column(
                    children: [
                      if (activeOrders.length > 1 || _shrinkActiveOrders)
                        buildConsolidatedRow(isExpanded: true),
                      ...activeOrders.map((order) => buildFullOrderCard(order)),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // "Buy Again" Quick Horizontal Ribbon (Feature 15)
            _buildBuyAgainSection(context, ref),



            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      'Shop by Category',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: textColorPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 68,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final name = cat['name'] ?? '';
                          final bgColor = _getCategoryColor(name);
                          final icon = _getCategoryIcon(name);
                          
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!_canPerformAction()) return;
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductListingScreen(
                                    initialCategoryId: cat['id'],
                                    initialCategoryName: cat['name'],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 84,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: bgColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      icon,
                                      color: textColorPrimary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      color: textColorPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10.5,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => SizedBox(
                height: 68,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  itemBuilder: (context, index) => Container(
                    width: 84,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SkeletonLoader.circle(radius: 14),
                        SizedBox(height: 4),
                        SkeletonLoader.text(height: 10, width: 42),
                      ],
                    ),
                  ),
                ),
              ),
              error: (err, stack) => _buildErrorRetryCard(
                message: 'Unable to load categories',
                onRetry: () => ref.refresh(categoriesProvider),
              ),
            ),

            // All Products header
            Text(
              'All Products',
              key: _productsSectionKey,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: textColorPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // Popular products list (Premium large vertical cards)
            popularProductsAsync.when(
              loading: () {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: SkeletonLoader.listTile(),
                  ),
                );
              },
              error: (err, stack) => _buildErrorRetryCard(
                message: 'Unable to load products',
                onRetry: () => ref.refresh(popularProductsProvider),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return const Center(child: Text('No products available.'));
                }

                final availableProducts = <Map<String, dynamic>>[];
                final unavailableProducts = <Map<String, dynamic>>[];

                for (final p in products) {
                  final rawStockNum = (p['stock'] is num)
                      ? (p['stock'] as num).toDouble()
                      : double.tryParse(p['stock']?.toString() ?? '');
                  final isAvailable = (p['is_available'] == null ||
                          p['is_available'] == true ||
                          p['is_available'] == 1 ||
                          p['is_available']?.toString() == '1' ||
                          p['is_available']?.toString().toLowerCase() == 'true') &&
                      (p['is_enabled'] != false &&
                          p['is_enabled'] != 0 &&
                          p['is_enabled']?.toString() != '0' &&
                          p['is_enabled']?.toString().toLowerCase() != 'false') &&
                      (rawStockNum == null || rawStockNum > 0);
                  if (isAvailable) {
                    availableProducts.add(p);
                  } else {
                    unavailableProducts.add(p);
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (availableProducts.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: availableProducts.length,
                        itemBuilder: (context, index) {
                          final p = availableProducts[index];
                          return PopularProductCard(p: p);
                        },
                      ),
                    if (unavailableProducts.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.remove_shopping_cart_rounded,
                                      size: 14, color: Colors.orange),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CURRENTLY UNAVAILABLE (${unavailableProducts.length})',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange.shade800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: unavailableProducts.length,
                        itemBuilder: (context, index) {
                          final p = unavailableProducts[index];
                          return PopularProductCard(p: p);
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
             const SizedBox(height: 76),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingCartBar(int itemCount, double subtotal) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(cartOriginTabProvider.notifier).state = 0;
        ref.read(isViewingQuickOrderCartProvider.notifier).state = false;
        _onTabChanged(1);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF1B3624), // Deep Emerald Green
              Color(0xFF0D2517),
            ],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.6), // Gold Accent Border
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1B3624).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Color(0xFFE5C158),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        AnimatedCounter(
                          value: itemCount,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          itemCount == 1 ? " item" : " items",
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    AnimatedCounter(
                      value: subtotal,
                      prefix: "₹",
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFE5C158),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    'VIEW CART',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF1B3624),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF1B3624),
                    size: 14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStepTimeline(String status, bool isPreOrder) {
    final statusLower = status.toLowerCase();
    int currentStep = 0;
    if (statusLower == 'pending') {
      currentStep = 0;
    } else if (statusLower == 'confirmed' || statusLower == 'preparing') {
      currentStep = 1;
    } else if (statusLower == 'out for delivery' || statusLower == 'dispatched') {
      currentStep = 2;
    } else if (statusLower == 'delivered') {
      currentStep = 3;
    }

    final steps = isPreOrder
        ? ['Pre-Ordered', 'Confirmed', 'Out for Delivery', 'Delivered']
        : ['Placed', 'Confirmed', 'Out for Delivery', 'Delivered'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = index ~/ 2;
            final isPassed = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2.5,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isPassed ? const Color(0xFF1B3624) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          } else {
            // Circle node
            final stepIndex = index ~/ 2;
            final isCompleted = stepIndex < currentStep;
            final isCurrent = stepIndex == currentStep;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? const Color(0xFF1B3624)
                        : (isCurrent ? const Color(0xFFD4AF37) : Colors.white),
                    border: Border.all(
                      color: isCompleted || isCurrent
                          ? (isCompleted ? const Color(0xFF1B3624) : const Color(0xFFD4AF37))
                          : const Color(0xFFCBD5E1),
                      width: 1.8,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                        : (isCurrent
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[stepIndex],
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: isCurrent ? FontWeight.bold : (isCompleted ? FontWeight.w600 : FontWeight.normal),
                    color: isCurrent
                        ? const Color(0xFF1B3624)
                        : (isCompleted ? const Color(0xFF2E6F40) : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildPulsingBeacon({Color color = const Color(0xFF059669)}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.5),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 14 * scale,
              height: 14 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: (1.5 - scale).clamp(0.0, 0.4)),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBuyAgainSection(BuildContext context, WidgetRef ref) {
    final lastOrderAsync = ref.watch(lastOrderProvider);
    return lastOrderAsync.maybeWhen(
      data: (lastOrder) {
        if (lastOrder == null) return const SizedBox.shrink();
        final items = lastOrder['order_items'] as List<dynamic>? ?? [];
        if (items.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFFB45309)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Buy Again',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColorPrimary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _handleReorderTap(context, ref, lastOrder),
                  child: Text(
                    'Reorder All →',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E6F40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 142,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final name = item['product_name'] ?? item['name'] ?? 'Product';
                  final pid = item['product_id']?.toString() ?? '';
                  final double price = (item['price'] is num)
                      ? (item['price'] as num).toDouble()
                      : (double.tryParse(item['price']?.toString() ?? '') ?? 0.0);
                  final unit = item['unit']?.toString() ?? 'kg';
                  final rawImg = item['image_path'] as String? ?? item['image_url'] as String?;
                  final imageUrl = getProductImage(name, rawImg);

                  return Container(
                    width: 116,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            imageUrl,
                            height: 58,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 58,
                              color: const Color(0xFFE8F5E9),
                              child: const Icon(Icons.eco_rounded, color: Color(0xFF2E6F40), size: 24),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: textColorPrimary,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '₹${_formatCurrency(price)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: textColorPrimary,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                ref.read(cartProvider.notifier).addItem(
                                  productId: pid,
                                  productName: name,
                                  price: price,
                                  unit: unit,
                                  quantity: 1.0,
                                  imagePath: rawImg,
                                );
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Added $name to cart!'),
                                    backgroundColor: const Color(0xFF1B3624),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1B3624),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildErrorRetryCard({required String message, required VoidCallback onRetry}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFF6E7E73), size: 28),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: textColorPrimary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Please check your internet connection.',
            style: GoogleFonts.inter(color: textColorSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onRetry();
            },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: textColorPrimary,
              side: const BorderSide(color: textColorPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('veg')) return Icons.eco_rounded;
    if (name.contains('fruit')) return Icons.apple_rounded;
    if (name.contains('flower') || name.contains('pooja') || name.contains('puja') || name.contains('phool')) {
      return Icons.local_florist_rounded;
    }
    if (name.contains('herb') || name.contains('season')) return Icons.spa_rounded;
    if (name.contains('dairy') || name.contains('milk')) return Icons.egg_alt_rounded;
    return Icons.category_rounded;
  }

  Color _getCategoryColor(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('veg')) return const Color(0xFFE8F5E9); // soft green
    if (name.contains('fruit')) return const Color(0xFFFFF1F1); // soft pink/orange
    if (name.contains('flower') || name.contains('pooja') || name.contains('puja') || name.contains('phool')) {
      return const Color(0xFFFFF3E0); // soft warm marigold/floral orange
    }
    if (name.contains('herb') || name.contains('season')) return const Color(0xFFE0F2F1); // soft teal
    if (name.contains('dairy') || name.contains('milk')) return const Color(0xFFFFF8E1); // soft cream
    return const Color(0xFFF5F5F5); // soft grey
  }

  void _showReorderDialog(BuildContext context, WidgetRef ref, List<dynamic> items, List<Map<String, dynamic>> currentProducts) {
    // Map to hold selected quantities of items
    final Map<String, Map<String, dynamic>> selectedItems = {};
    for (var item in items) {
      final pid = item['product_id']?.toString() ?? '';
      if (pid.isEmpty) continue;
      final currentProd = currentProducts.firstWhere(
        (p) => p['id']?.toString().trim().toLowerCase() == pid.trim().toLowerCase(),
        orElse: () => {},
      );
      final rawStockNum = (currentProd['stock'] is num)
          ? (currentProd['stock'] as num).toDouble()
          : double.tryParse(currentProd['stock']?.toString() ?? '');
      if (currentProd.isEmpty ||
          currentProd['is_enabled'] == false ||
          currentProd['is_enabled'] == 0 ||
          currentProd['is_available'] == false ||
          currentProd['is_available'] == 0 ||
          (rawStockNum != null && rawStockNum <= 0)) {
        continue; // Skip out-of-stock and unavailable products
      }
      final double rawQty = (item['quantity'] is num)
          ? (item['quantity'] as num).toDouble()
          : (double.tryParse(item['quantity']?.toString() ?? '') ?? 1.0);
      final double clampedQty = (rawStockNum != null && rawQty > rawStockNum) ? rawStockNum : rawQty;
      final double price = (currentProd['price'] is num)
          ? (currentProd['price'] as num).toDouble()
          : (double.tryParse(currentProd['price']?.toString() ?? '') ?? 0.0);

      selectedItems[pid] = {
        'product_id': pid,
        'product_name': currentProd['name'] ?? item['product_name'] ?? 'N/A',
        'price': price,
        'unit': currentProd['unit'] ?? item['unit'] ?? '',
        'quantity': (clampedQty * 1000).round() / 1000.0,
        'stock': rawStockNum,
        'image_path': currentProd['image_path'] ?? item['image_path'],
      };
    }

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('None of the items are currently available for purchase.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            List<double> getQuantitySteps(String unit) {
              final u = unit.toLowerCase();
              if (u.contains('kg')) {
                return [0.25, 0.5, 1.0, 2.0, 5.0];
              } else if (u.contains('doz')) {
                return [0.5, 1.0, 1.5, 2.0, 3.0];
              } else {
                return [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
              }
            }

            String formatQtyText(double qty, String unit) {
              final u = unit.toLowerCase();
              if (u.contains('kg')) {
                if (qty < 1.0) {
                  return '${(qty * 1000).toStringAsFixed(0)} g';
                } else {
                  return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} kg';
                }
              } else if (u.contains('doz')) {
                return '$qty Dozen';
              } else {
                return '${qty.toStringAsFixed(qty == qty.toInt() ? 0 : 1)} $unit';
              }
            }

            return Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F5EE),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))
                ],
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 1.5),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Reorder Items',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B3624),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF6E7E73)),
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Review and edit item quantities before adding to cart:',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6E7E73)),
                    ),
                    const Divider(height: 24),
                    
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: selectedItems.values.map((item) {
                            final pid = item['product_id']?.toString() ?? '';
                            final name = item['product_name']?.toString() ?? '';
                            final price = (item['price'] as num?)?.toDouble() ?? 0.0;
                            final unit = item['unit']?.toString() ?? '';
                            final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
                            final itemStock = (item['stock'] as num?)?.toDouble();

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3624)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${price.toStringAsFixed(2)} / $unit',
                                          style: const TextStyle(color: Color(0xFF6E7E73), fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF6E7E73)),
                                        tooltip: 'Decrease quantity',
                                        onPressed: () {
                                          setState(() {
                                            final double roundedQty = (qty * 1000).round() / 1000.0;
                                            final steps = getQuantitySteps(unit);
                                            final prevIndex = steps.lastIndexWhere((s) => s < roundedQty - 0.001);
                                            if (prevIndex != -1) {
                                              item['quantity'] = steps[prevIndex];
                                            } else {
                                              selectedItems.remove(pid);
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        formatQtyText(qty, unit),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.add_circle_outline_rounded,
                                          color: (itemStock != null && qty >= itemStock) ? const Color(0xFFCBD5E1) : const Color(0xFF1B3624),
                                        ),
                                        tooltip: 'Increase quantity',
                                        onPressed: (itemStock != null && qty >= itemStock)
                                            ? null
                                             : () {
                                                 setState(() {
                                                   final double roundedQty = (qty * 1000).round() / 1000.0;
                                                   final steps = getQuantitySteps(unit);
                                                   final nextIndex = steps.indexWhere((s) => s > roundedQty + 0.001);
                                                   double nextQty = (nextIndex != -1)
                                                       ? steps[nextIndex]
                                                       : ((roundedQty + 1.0) * 1000).round() / 1000.0;
                                                   if (itemStock != null && nextQty > itemStock) {
                                                     nextQty = itemStock;
                                                   }
                                                   item['quantity'] = nextQty;
                                                 });
                                               },
                                       ),
                                    ],
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(height: 24),
                    
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B3624),
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: selectedItems.isEmpty ? null : () {
                        final cartNotifier = ref.read(cartProvider.notifier);
                        for (var item in selectedItems.values) {
                          cartNotifier.addItem(
                            productId: item['product_id']?.toString() ?? '',
                            productName: item['product_name']?.toString() ?? '',
                            price: (item['price'] as num?)?.toDouble() ?? 0.0,
                            unit: item['unit']?.toString() ?? '',
                            quantity: (item['quantity'] as num?)?.toDouble() ?? 1.0,
                            imagePath: item['image_path']?.toString(),
                          );
                        }
                        
                        Navigator.pop(context); // Close bottom sheet
                        _onTabChanged(1); // Standard navigation to Cart tab
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Items added to cart successfully!'),
                            backgroundColor: Color(0xFF1B3624),
                          ),
                        );
                      },
                      child: const Text(
                        'CONFIRM & GO TO CART',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final int decimalPlaces;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.decimalPlaces = 0,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0.0;

  @override
  void initState() {
    super.initState();
    _oldValue = widget.value.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: _oldValue, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value.toDouble();
      _animation = Tween<double>(begin: _oldValue, end: widget.value.toDouble()).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${widget.prefix}${_animation.value.toStringAsFixed(widget.decimalPlaces)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

class PopularProductCard extends ConsumerWidget {
  final Map<String, dynamic> p;

  const PopularProductCard({super.key, required this.p});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String productId = p['id']?.toString() ?? '';
    final existingCartItem = ref.watch(cartProvider.select((state) => state.items[productId]));
    final isInCart = existingCartItem != null;
    final rawStockNum = (p['stock'] is num)
        ? (p['stock'] as num).toDouble()
        : double.tryParse(p['stock']?.toString() ?? '');
    final isAvailable = (p['is_available'] == null ||
            p['is_available'] == true ||
            p['is_available'] == 1 ||
            p['is_available']?.toString() == '1' ||
            p['is_available']?.toString().toLowerCase() == 'true') &&
        (p['is_enabled'] != false &&
            p['is_enabled'] != 0 &&
            p['is_enabled']?.toString() != '0' &&
            p['is_enabled']?.toString().toLowerCase() != 'false') &&
        (rawStockNum == null || rawStockNum > 0);
    final bool isExplicitlyUnavailable = !(p['is_available'] == null ||
            p['is_available'] == true ||
            p['is_available'] == 1 ||
            p['is_available']?.toString() == '1' ||
            p['is_available']?.toString().toLowerCase() == 'true') ||
        (p['is_enabled'] == false ||
            p['is_enabled'] == 0 ||
            p['is_enabled']?.toString() == '0' ||
            p['is_enabled']?.toString().toLowerCase() == 'false');
    final name = p['name']?.toString() ?? '';
    final double rawPrice = (p['price'] is num)
        ? (p['price'] as num).toDouble()
        : (double.tryParse(p['price']?.toString() ?? '') ?? 0.0);
    final double price = rawPrice < 0 ? 0.0 : rawPrice;
    final double rawMarketPrice = (p['market_price'] is num)
        ? (p['market_price'] as num).toDouble()
        : (double.tryParse(p['market_price']?.toString() ?? '') ?? 0.0);
    final double marketPrice = rawMarketPrice < 0 ? 0.0 : rawMarketPrice;
    final unit = p['unit']?.toString() ?? 'kg';
     
    final tags = _getProductTags(name);
    final dbImageUrl = p['image_path'] as String? ?? p['image_url'] as String?;
    final imageUrl = getProductImage(name, dbImageUrl);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 20),
      borderRadius: 24,
      padding: const EdgeInsets.all(18.0),
      isStockOut: !isAvailable,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tags & Low Stock Urgency Alert (Feature 13)
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tags.join('  |  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2E6F40),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (rawStockNum != null && rawStockNum > 0 && rawStockNum <= 4 && isAvailable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 9)),
                            const SizedBox(width: 3),
                            Text(
                              'Only ${rawStockNum.toInt()} left!',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFB45309),
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Title
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF1B3624),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Price & MRP Layout (Feature 19)
                if (unit.toLowerCase().contains('kg')) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${_formatCurrency(price / 4)}/250g',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1B3624),
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      if (marketPrice > price) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${_formatCurrency(marketPrice / 4)}',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${_formatCurrency(price)} per kg',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF2E6F40),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (marketPrice > price) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${_formatCurrency(marketPrice)}',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '₹${_formatCurrency(price)}/$unit',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF1B3624),
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      if (marketPrice > price) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${_formatCurrency(marketPrice)}',
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right side: Image & Action Button
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Product Image with Shimmer Loading & Shadow (Feature 11)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        height: 100,
                        width: 120,
                        child: Image.network(
                          imageUrl,
                          height: 100,
                          width: 120,
                          cacheWidth: 360,
                          cacheHeight: 300,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SkeletonLoader.rectangle(
                              height: 100,
                              width: 120,
                              borderRadius: 16,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Image.network(
                              _getProductImage(name),
                              height: 100,
                              width: 120,
                              cacheWidth: 360,
                              cacheHeight: 300,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SkeletonLoader.rectangle(
                                  height: 100,
                                  width: 120,
                                  borderRadius: 16,
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 100,
                                  width: 120,
                                  color: const Color(0xFFE8F5E9),
                                  child: const Icon(Icons.eco_rounded, color: Color(0xFF2E6F40), size: 36),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (!isAvailable)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black.withValues(alpha: 0.38),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                isExplicitlyUnavailable ? 'UNAVAILABLE' : 'OUT OF STOCK',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Button / Stepper (Feature 16)
              if (!isAvailable)
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 13),
                      const SizedBox(width: 4),
                      Text(
                        'OUT OF STOCK',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          color: const Color(0xFFDC2626),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else if (!isInCart)
                _MicroAnimatedAddButton(
                  onPressed: () {
                    showQuantitySelectionBottomSheet(
                      context: context,
                      ref: ref,
                      product: p,
                    );
                  },
                )
              else
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3624),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1B3624).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 14),
                        tooltip: 'Decrease quantity',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final step = _getStepSize(unit);
                          final nextQty = ((existingCartItem.quantity - step) * 1000).round() / 1000.0;
                          ref.read(cartProvider.notifier).updateQuantity(productId, nextQty);
                        },
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showQuantitySelectionBottomSheet(
                            context: context,
                            ref: ref,
                            product: p,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _formatSelectorQuantity(existingCartItem.quantity, unit),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                        tooltip: 'Increase quantity',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final step = _getStepSize(unit);
                          if (rawStockNum != null && (rawStockNum <= 0 || existingCartItem.quantity >= rawStockNum || existingCartItem.quantity + step > rawStockNum)) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(rawStockNum <= 0
                                    ? 'This item is currently out of stock.'
                                    : 'Cannot add more. Maximum available stock is ${_formatSelectorQuantity(rawStockNum, unit)}.'),
                                backgroundColor: const Color(0xFFDC2626),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          showQuantitySelectionBottomSheet(
                            context: context,
                            ref: ref,
                            product: p,
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicroAnimatedAddButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const _MicroAnimatedAddButton({
    required this.onPressed,
    this.label = 'Add to Cart',
  });

  @override
  State<_MicroAnimatedAddButton> createState() => _MicroAnimatedAddButtonState();
}

class _MicroAnimatedAddButtonState extends State<_MicroAnimatedAddButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.mediumImpact();
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3624),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B3624).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mappers for premium editorial mock details (moved to top-level for performance/scope access)
List<String> _getProductTags(String productName) {
  final n = productName.toLowerCase();
  if (n.contains('potato')) return ['Root Veg', 'Local'];
  if (n.contains('tomato')) return ['Vine Ripe', 'Fresh'];
  if (n.contains('onion')) return ['Crispy', 'Organic'];
  if (n.contains('apple')) return ['Premium', 'Sweet'];
  if (n.contains('banana')) return ['Energy', 'Ripe'];
  if (n.contains('milk')) return ['Dairy', 'Pure'];
  if (n.contains('paneer')) return ['Fresh', 'Dairy'];
  if (n.contains('coriander') || n.contains('dhania')) return ['Herb', 'Local'];
  if (n.contains('ginger') || n.contains('adrak')) return ['Organic', 'Spicy'];
  return ['Organic', 'Fresh'];
}

String _getProductImage(String productName) {
  final n = productName.toLowerCase();
  if (n.contains('potato')) {
    return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('tomato')) {
    return 'https://images.unsplash.com/photo-1595855759920-86582396756a?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('onion')) {
    return 'https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('apple')) {
    return 'https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('banana')) {
    return 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('coriander') || n.contains('dhania')) {
    return 'https://images.unsplash.com/photo-1588879460618-9249e7d947d1?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('ginger') || n.contains('adrak')) {
    return 'https://images.unsplash.com/photo-1599940824399-b87987ceb72a?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('milk')) {
    return 'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=600&q=80';
  }
  if (n.contains('paneer')) {
    return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?auto=format&fit=crop&w=600&q=80';
  }
  return 'https://images.unsplash.com/photo-1610397613050-59f7f1554d67?auto=format&fit=crop&w=600&q=80';
}

String _formatSelectorQuantity(double qty, String unit) {
  final unitLower = unit.toLowerCase();
  final roundedQty = (qty * 1000).round() / 1000.0;
  if (unitLower == 'kg') {
    if ((roundedQty - 0.25).abs() < 0.001) return '250 g';
    if ((roundedQty - 0.50).abs() < 0.001) return '500 g';
    if ((roundedQty - 0.75).abs() < 0.001) return '750 g';
    if (roundedQty == roundedQty.toInt()) {
      return '${roundedQty.toInt()} kg';
    }
    return '${roundedQty.toStringAsFixed(roundedQty * 10 == (roundedQty * 10).toInt() ? 1 : 2)} kg';
  } else if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') {
    return '${roundedQty.toInt()} g';
  } else {
    if (roundedQty == roundedQty.toInt()) {
      return '${roundedQty.toInt()} $unit';
    }
    return '${roundedQty.toStringAsFixed(1)} $unit';
  }
}

double _getStepSize(String unit) {
  final unitLower = unit.toLowerCase();
  if (unitLower == 'kg') return 0.25;
  if (unitLower == 'g' || unitLower == 'gram' || unitLower == 'grams') return 250.0;
  return 1.0;
}

String _formatCurrency(double amount) {
  if ((amount - amount.roundToDouble()).abs() < 0.01) {
    return amount.round().toString();
  }
  final s = amount.toStringAsFixed(2);
  if (s.endsWith('.00')) {
    return amount.round().toString();
  }
  return s;
}

