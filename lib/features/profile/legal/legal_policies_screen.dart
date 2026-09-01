import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'policy_models.dart';
import 'policy_detail_screen.dart';
import '../../../core/widgets/ambient_background.dart';

class LegalPoliciesScreen extends StatefulWidget {
  const LegalPoliciesScreen({super.key});

  @override
  State<LegalPoliciesScreen> createState() => _LegalPoliciesScreenState();
}

class _LegalPoliciesScreenState extends State<LegalPoliciesScreen> {
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textColorPrimary = Color(0xFF1B3624);
  static const Color textColorSecondary = Color(0xFF6E7E73);
  static const Color brandPrimary = Color(0xFF10B981);
  static const Color brandDark = Color(0xFF047857);

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allPolicies = OrderKartPolicies.getAllPolicies();
    final filteredPolicies = allPolicies.where((p) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase().trim();
      return p.title.toLowerCase().contains(q) ||
          p.marathiTitle.toLowerCase().contains(q) ||
          p.summary.toLowerCase().contains(q);
    }).toList();

    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textColorPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Legal & Policies',
            style: GoogleFonts.playfairDisplay(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: textColorPrimary,
            ),
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Trust & Transparency Banner Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: textColorPrimary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: textColorPrimary.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: Color(0xFF6EE7B7), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transparency & Customer Rights',
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'पारदर्शकता व ग्राहक संरक्षण',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF6EE7B7),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'OrderKart is committed to consumer protection, fair trade, data privacy, and transparent pricing under Indian consumer laws.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: textColorSecondary.withValues(alpha: 0.12)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search policies (e.g., refund, delivery, privacy)...',
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: textColorSecondary),
                  prefixIcon: const Icon(Icons.search_rounded, color: textColorSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Policies Count Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Official Policy Documents',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: textColorPrimary,
                  ),
                ),
                Text(
                  '${filteredPolicies.length} of ${allPolicies.length}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColorSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Policies List
            if (filteredPolicies.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Text(
                  'No matching policy documents found.',
                  style: GoogleFonts.inter(fontSize: 14, color: textColorSecondary),
                ),
              )
            else
              ...filteredPolicies.asMap().entries.map((entry) {
                final idx = entry.key;
                final policy = entry.value;
                return _buildPolicyTile(context, policy, idx);
              }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTile(BuildContext context, PolicyItem policy, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textColorSecondary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PolicyDetailScreen(policy: policy),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: brandPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(policy.icon, color: brandDark, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              policy.title,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 15.5,
                                fontWeight: FontWeight.bold,
                                color: textColorPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        policy.marathiTitle,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: brandDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        policy.summary,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: textColorSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: textColorSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
