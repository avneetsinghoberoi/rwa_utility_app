import 'package:flutter/material.dart';
import 'package:gate_basic/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MemberCard extends StatelessWidget {
  final String name;
  final String houseNo;
  final String phone;
  final String? email;
  final String? role;
  final DateTime? createdAt;
  final VoidCallback? onClose;

  const MemberCard({
    super.key,
    required this.name,
    required this.houseNo,
    required this.phone,
    this.email,
    this.role,
    this.createdAt,
    this.onClose,
  });

  String _getInitials() {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _getAvatarColor() {
    final colors = [
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF10B981), // Green
      const Color(0xFFF59E0B), // Amber
    ];
    return colors[name.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials();
    final avatarColor = _getAvatarColor();
    final createdDate = createdAt != null
        ? DateFormat('dd MMM yyyy').format(createdAt!)
        : 'N/A';

    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              avatarColor.withOpacity(0.1),
              avatarColor.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── Close button ─────────────────────────────────────
                if (onClose != null)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textPrimary),
                        onPressed: onClose,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // ── Main Card ────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: avatarColor.withOpacity(0.2),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Header with gradient ─────────────────────
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [avatarColor, avatarColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            // Avatar
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: avatarColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Name
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            // House number
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Flat / Unit $houseNo',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Details section ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Phone
                            _buildDetailRow(
                              icon: Icons.phone_rounded,
                              label: 'Phone',
                              value: phone,
                              color: avatarColor,
                            ),
                            const SizedBox(height: 16),

                            // Email
                            if (email != null && email!.isNotEmpty) ...[
                              _buildDetailRow(
                                icon: Icons.email_rounded,
                                label: 'Email',
                                value: email!,
                                color: avatarColor,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Role
                            if (role != null && role!.isNotEmpty) ...[
                              _buildDetailRow(
                                icon: role == 'admin'
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.person_rounded,
                                label: 'Role',
                                value: role == 'admin' ? 'Administrator' : 'Resident',
                                color: avatarColor,
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Member since
                            _buildDetailRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Member Since',
                              value: createdDate,
                              color: avatarColor,
                            ),
                          ],
                        ),
                      ),

                      // ── Status badge ────────────────────────────
                      Container(
                        margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              avatarColor.withOpacity(0.1),
                              avatarColor.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: avatarColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Valid Member',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: avatarColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Verification badge ───────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6EE7B7),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Color(0xFF059669), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'QR Verified • Ready for Entry',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
