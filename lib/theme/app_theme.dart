import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  APP COLOR PALETTE - MODERN & MINIMALIST
// ─────────────────────────────────────────────
class AppColors {
  // Primary - Refined Blue
  static const Color primary = Color(0xFF2563EB);        // Modern Blue
  static const Color primaryDark = Color(0xFF1E40AF);    // Darker Blue
  static const Color primaryLight = Color(0xFFEFF6FF);   // Very light blue

  // Backgrounds & Surfaces
  static const Color background = Color(0xFFFAFBFC);     // Clean white
  static const Color surface = Colors.white;
  static const Color surfaceLight = Color(0xFFF8FAFC);   // Subtle background

  // Text Colors - Refined
  static const Color textPrimary = Color(0xFF0F172A);    // Dark slate
  static const Color textSecondary = Color(0xFF475569);  // Medium slate
  static const Color textTertiary = Color(0xFF64748B);   // Light slate
  static const Color textHint = Color(0xFFA0AEC0);       // Hint text

  // Status Colors - Refined
  static const Color success = Color(0xFF059669);        // Emerald
  static const Color successLight = Color(0xFFECFDF5);   // Light emerald
  static const Color warning = Color(0xFFF59E0B);        // Amber
  static const Color warningLight = Color(0xFFFEF3C7);   // Light amber
  static const Color error = Color(0xFFDC2626);          // Red
  static const Color errorLight = Color(0xFFFEE2E2);     // Light red
  static const Color info = Color(0xFF0891B2);           // Cyan
  static const Color infoLight = Color(0xFFECFDF5);      // Light cyan

  // Neutral Grays - Refined palette
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray600 = Color(0xFF4B5563);

  // UI Elements
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color shadow = Color(0xFF000000);
}

// ─────────────────────────────────────────────
//  SHARED THEME HELPERS - MODERN & MINIMALIST
// ─────────────────────────────────────────────
class AppTheme {
  // ── Gradients (Subtle & Modern) ────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Shadows (Subtle & Modern) ──────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.shadow.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: AppColors.shadow.withOpacity(0.02),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: AppColors.shadow.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: AppColors.shadow.withOpacity(0.03),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get primaryShadow => [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Box Decorations ────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: cardShadow,
        border: Border.all(
          color: AppColors.borderLight,
          width: 0.5,
        ),
      );

  static BoxDecoration get subtleCardDecoration => BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderLight,
          width: 0.5,
        ),
      );

  // ── Input Decoration ──────────────────────
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.primaryLight,
      labelStyle: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
    );
  }

  // ── Typography Styles ──────────────────────
  static const TextStyle headingXL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
  );

  // ── Gradient Button Widget ─────────────────
  static Widget gradientButton({
    required String label,
    required VoidCallback? onTap,
    double height = 52,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isLoading || onTap == null
                ? const LinearGradient(
                    colors: [Color(0xFFD1D5DB), Color(0xFFD1D5DB)])
                : primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: onTap == null ? [] : elevatedShadow,
          ),
          height: height,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ── Section Header ─────────────────────────
  static Widget sectionHeader(String title, {String? emoji}) {
    return Row(
      children: [
        if (emoji != null) ...[
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // ── Status Chip ───────────────────────────
  static Widget statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Summary Card ───────────────────────────
  static Widget summaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
}
