import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gate_basic/theme/app_theme.dart';
import '../../utils/dashboard_key.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _sortBy = 'house_no'; // 'house_no', 'name'

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Filter and sort members based on search and sort preferences.
  /// Also excludes removed users (client-side, so missing status = active).
  List<DocumentSnapshot> _filterMembers(List<DocumentSnapshot> docs) {
    final query = _searchQuery.trim();
    final compactQuery = query.replaceAll(RegExp(r'[^a-z0-9]'), '');

    var filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      // Exclude removed users
      final status = (data['status'] ?? 'active').toString();
      if (status == 'removed') return false;

      final name = (data['name'] ?? '').toString().toLowerCase();
      final houseNo = (data['house_no'] ?? '').toString().toLowerCase();
      final phone = (data['phone'] ?? '').toString().toLowerCase();
      final vehicleNo = (data['vehicle_no'] ?? '').toString().toLowerCase();
      final compactVehicleNo = vehicleNo.replaceAll(RegExp(r'[^a-z0-9]'), '');

      return query.isEmpty ||
          name.contains(query) ||
          houseNo.contains(query) ||
          phone.contains(query) ||
          vehicleNo.contains(query) ||
          (compactQuery.isNotEmpty && compactVehicleNo.contains(compactQuery));
    }).toList();

    // Sort — owners always before tenants within the same house
    if (_sortBy == 'name') {
      filtered.sort((a, b) {
        final nameA = (a.data() as Map<String, dynamic>)['name'] ?? '';
        final nameB = (b.data() as Map<String, dynamic>)['name'] ?? '';
        return nameA.toString().compareTo(nameB.toString());
      });
    } else {
      // Sort by house_no, then owners before tenants
      filtered.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final noA = (dataA['house_no'] ?? '').toString();
        final noB = (dataB['house_no'] ?? '').toString();
        final cmp = noA.compareTo(noB);
        if (cmp != 0) return cmp;
        // Same house: owner first (no primary_owner_uid)
        final aIsOwner =
            (dataA['account_link'] as Map?)?['primary_owner_uid'] == null;
        final bIsOwner =
            (dataB['account_link'] as Map?)?['primary_owner_uid'] == null;
        if (aIsOwner && !bIsOwner) return -1;
        if (!aIsOwner && bIsOwner) return 1;
        return 0;
      });
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Members Directory',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () =>
                    dashboardScaffoldKey.currentState?.openDrawer(),
              ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border,
            height: 1,
          ),
        ),
        actions: [
          if (Navigator.canPop(context))
            IconButton(
              icon:
                  const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
              onPressed: () => dashboardScaffoldKey.currentState?.openDrawer(),
            ),
          // Sort menu
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'house_no',
                child: Row(
                  children: [
                    Icon(Icons.sort_outlined,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Sort by House No'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.person_outlined,
                        size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Sort by Name'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(
                _sortBy == 'name' ? Icons.person_outlined : Icons.home_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: AppTheme.inputDecoration(
                'Search by name, house, phone or vehicle',
                Icons.search_rounded,
              ).copyWith(
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Members list ────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', whereIn: ['user', 'resident']).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No members found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check back soon when members are added',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filter and sort members
                final filteredMembers = _filterMembers(snapshot.data!.docs);

                if (filteredMembers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No results found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member =
                        filteredMembers[index].data() as Map<String, dynamic>;
                    return _MemberCard(member: member);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual member card widget
class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;

  const _MemberCard({required this.member});

  /// Returns (badgeLabel, badgeColor, badgeIcon) for the user type badge
  (String, Color, IconData) _badgeInfo() {
    final accountLink = member['account_link'] as Map?;
    final primaryOwnerUid = accountLink?['primary_owner_uid'];
    final linkedAs = (accountLink?['linked_as'] ?? 'owner').toString();

    final isOwner = primaryOwnerUid == null;

    if (isOwner) {
      return ('Owner', const Color(0xFF059669), Icons.home_rounded);
    }

    // Capitalise first letter of linked_as
    final label = linkedAs.isNotEmpty
        ? '${linkedAs[0].toUpperCase()}${linkedAs.substring(1)}'
        : 'Tenant';

    return (label, const Color(0xFF7C3AED), Icons.person_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final name = member['name'] ?? 'Unknown';
    final houseNo = member['house_no'] ?? '-';
    final phone = member['phone'] ?? '-';
    final email = member['email'] ?? '-';
    final vehicleNo = (member['vehicle_no'] ?? '').toString().trim();

    final (badgeLabel, badgeColor, badgeIcon) = _badgeInfo();

    // Generate avatar color based on name hash
    final avatarColor = _getAvatarColor(name.toString());

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Avatar + Name + House ──────────────
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [avatarColor, avatarColor.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      name.toString()[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name and House Number
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'House No. $houseNo',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic badge: Owner / Tenant / Spouse / Family etc.
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeIcon,
                        size: 12,
                        color: badgeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: badgeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Divider ──────────────────────────────────────
            Divider(
              height: 1,
              color: AppColors.divider,
            ),

            const SizedBox(height: 14),

            // ── Contact Information ──────────────────────────
            Row(
              children: [
                // Phone
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // Could implement phone call or copy to clipboard
                      _showContactCopied(context, phone.toString());
                    },
                    child: _ContactInfo(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: phone.toString(),
                      iconColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Email
                Expanded(
                  child: InkWell(
                    onTap: () {
                      _showContactCopied(context, email.toString());
                    },
                    child: _ContactInfo(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email.toString(),
                      iconColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),

            // ── Vehicle Number (if set) ──────────────────────
            if (vehicleNo.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.directions_car_rounded,
                      size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 6),
                  const Text(
                    'Vehicle',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFF59E0B).withOpacity(0.4)),
                    ),
                    child: Text(
                      vehicleNo,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Get a deterministic color based on name
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF2F80ED), // Blue
      const Color(0xFF7C3AED), // Purple
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Orange
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
    ];

    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  void _showContactCopied(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Copied: $value'),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Contact information display widget
class _ContactInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _ContactInfo({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
