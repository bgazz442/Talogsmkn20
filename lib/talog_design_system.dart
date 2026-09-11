import 'package:flutter/material.dart';

/// TALOG20 Design System — Academic Prestige Theme
///
/// Palette:
/// - Primary Navy: #0F2B5C
/// - Dark Navy: #0A1D3F / #091E42
/// - Accent Orange: #FF6B00
/// - Light Canvas: #F8FAFC / #F1F5F9
/// - Surface: #FFFFFF
/// - Border: #E2E8F0
/// - Text Heading: #0F172A
/// - Text Body: #334155
/// - Text on Dark: #FFFFFF / #CBD5E1

class TalogColors {
  const TalogColors._();

  // Brand Palette
  static const Color primaryNavy = Color(0xFF0F2B5C);
  static const Color darkNavy = Color(0xFF0A1D3F);
  static const Color darkNavyElevated = Color(0xFF091E42);
  static const Color accentOrange = Color(0xFFFF6B00);

  // Background & Surfaces
  static const Color lightCanvas = Color(0xFFF8FAFC);
  static const Color lightCanvasSecondary = Color(0xFFF1F5F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderHover = Color(0xFFCBD5E1);

  // Typography
  static const Color textHeading = Color(0xFF0F172A);
  static const Color textBody = Color(0xFF334155);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textOnDarkMuted = Color(0xFFCBD5E1);

  // Status & Actions
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color danger = Color(0xFFEF4444);

  // Department Accents
  static const Color deptRPL = Color(0xFF8B5CF6);  // Purple - Rekayasa Perangkat Lunak
  static const Color deptBD = Color(0xFF06B6D4);   // Cyan - Bisnis Daring
  static const Color deptAKL = Color(0xFFF59E0B);  // Amber - Akuntansi & Keuangan Lembaga
  static const Color deptML = Color(0xFF10B981);   // Green - Manajemen Logistik
  static const Color deptTJKT = Color(0xFF3B82F6); // Blue - Teknik Jaringan Komputer & Telekomunikasi

  /// Resolve color by department code or name
  static Color departmentAccent(String? codeOrName) {
    if (codeOrName == null) return deptRPL;
    final clean = codeOrName.trim().toUpperCase();
    if (clean.contains('RPL') || clean.contains('PERANGKAT')) return deptRPL;
    if (clean.contains('BD') || clean.contains('BISNIS') || clean.contains('DARING')) return deptBD;
    if (clean.contains('AKL') || clean.contains('AKUNTANSI')) return deptAKL;
    if (clean.contains('ML') || clean.contains('LOGISTIK')) return deptML;
    if (clean.contains('TJKT') || clean.contains('TKJ') || clean.contains('JARINGAN')) return deptTJKT;
    return deptRPL;
  }
}

class TalogTypography {
  const TalogTypography._();

  static const TextStyle hero = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: TalogColors.textHeading,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static const TextStyle heroDark = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: TalogColors.textOnDark,
    letterSpacing: -0.8,
    height: 1.15,
  );

  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: TalogColors.textHeading,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionHeading = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: TalogColors.textHeading,
    letterSpacing: -0.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: TalogColors.textHeading,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: TalogColors.textBody,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: TalogColors.textMuted,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: TalogColors.textMuted,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: TalogColors.accentOrange,
  );
}

/// A modern card with 1px border #E2E8F0, radius 14-16px, and very soft shadow
class TalogCard extends StatelessWidget {
  const TalogCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.backgroundColor = TalogColors.surface,
    this.borderColor = TalogColors.border,
    this.borderRadius = 14.0,
    this.accentBorderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final double borderRadius;
  final Color? accentBorderColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: accentBorderColor ?? borderColor,
          width: accentBorderColor != null ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F2B5C),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );

    return content;
  }
}

/// Brand logo with Academic Prestige styling
class TalogBrand extends StatelessWidget {
  const TalogBrand({super.key, this.light = false, this.size = 32});

  final bool light;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TalogColors.primaryNavy, TalogColors.darkNavyElevated],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.28),
            border: Border.all(
              color: light ? Colors.white24 : TalogColors.border,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F0F2B5C),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'T',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.58,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            text: 'TALog',
            style: TextStyle(
              color: light ? TalogColors.textOnDark : TalogColors.primaryNavy,
              fontSize: size * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            children: const [
              TextSpan(
                text: '20',
                style: TextStyle(
                  color: TalogColors.accentOrange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pill Badge for status, jurusan, and role
class TalogBadge extends StatelessWidget {
  const TalogBadge({
    super.key,
    required this.label,
    this.color = TalogColors.primaryNavy,
    this.backgroundColor,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String label;
  final Color color;
  final Color? backgroundColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? color.withValues(alpha: 0.1);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary button with Orange #FF6B00 and rounded 12-14px
class TalogButton extends StatelessWidget {
  const TalogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.isSecondary = false,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool isSecondary;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDanger
        ? TalogColors.danger
        : (isSecondary ? TalogColors.primaryNavy : TalogColors.accentOrange);

    if (isSecondary) {
      return OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: TalogColors.primaryNavy,
          side: const BorderSide(color: TalogColors.border, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white,
        ),
        icon: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: TalogColors.primaryNavy),
              )
            : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: effectiveColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : (icon != null ? Icon(icon, size: 18) : const SizedBox.shrink()),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.2),
      ),
    );
  }
}

/// Metric Card for 4 key indicators
class TalogMetricCard extends StatelessWidget {
  const TalogMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.accentColor = TalogColors.accentOrange,
    this.badgeText,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return TalogCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              if (badgeText != null)
                TalogBadge(label: badgeText!, color: accentColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: TalogColors.textHeading,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: TalogColors.textMuted,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: TalogColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Academic Prestige Hero Section
class TalogAcademicHero extends StatelessWidget {
  const TalogAcademicHero({
    super.key,
    required this.greeting,
    required this.name,
    required this.description,
    this.statusText = 'Aktif',
    this.isStaffPreview = false,
    this.actions,
  });

  final String greeting;
  final String name;
  final String description;
  final String statusText;
  final bool isStaffPreview;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Container(
      padding: EdgeInsets.all(isCompact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TalogColors.primaryNavy, TalogColors.darkNavy, TalogColors.darkNavyElevated],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F2B5C),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: TalogColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isStaffPreview) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TalogColors.accentOrange.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: TalogColors.accentOrange, width: 1),
                      ),
                      child: const Text(
                        'STAFF PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const Icon(Icons.school_outlined, color: Colors.white30, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            greeting,
            style: const TextStyle(
              color: TalogColors.accentOrange,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 24 : 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: TalogColors.textOnDarkMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          if (actions != null) ...[
            const SizedBox(height: 16),
            actions!,
          ],
        ],
      ),
    );
  }
}

/// Task Progress Card with step timeline
class TalogTaskProgressCard extends StatelessWidget {
  const TalogTaskProgressCard({
    super.key,
    required this.taskName,
    this.departmentName,
    this.departmentCode,
    this.description,
    required this.dueAt,
    required this.statusLabel,
    required this.progressPercent,
    required this.isSubmitted,
    required this.isUnderReview,
    required this.isGraded,
    this.score,
    this.feedback,
    this.onSubmit,
  });

  final String taskName;
  final String? departmentName;
  final String? departmentCode;
  final String? description;
  final String dueAt;
  final String statusLabel;
  final double progressPercent; // 0.0 to 1.0
  final bool isSubmitted;
  final bool isUnderReview;
  final bool isGraded;
  final double? score;
  final String? feedback;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final deptColor = TalogColors.departmentAccent(departmentCode ?? departmentName);
    final percentInt = (progressPercent * 100).toInt();

    return TalogCard(
      accentBorderColor: deptColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Department Badge & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TalogBadge(
                label: departmentCode ?? departmentName ?? 'UMUM',
                color: deptColor,
                icon: Icons.bookmark_outline,
              ),
              TalogBadge(
                label: statusLabel,
                color: isGraded
                    ? TalogColors.success
                    : (isSubmitted ? TalogColors.info : TalogColors.accentOrange),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Task Name
          Text(
            taskName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TalogColors.textHeading,
            ),
          ),

          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TalogTypography.bodySmall,
            ),
          ],

          const SizedBox(height: 16),

          // Progress Bar with Percentage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progres Pengerjaan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TalogColors.textMuted),
              ),
              Text(
                '$percentInt%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: TalogColors.accentOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 8,
              backgroundColor: const Color(0xFFECECF4),
              valueColor: AlwaysStoppedAnimation<Color>(
                isGraded ? TalogColors.success : TalogColors.accentOrange,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Timeline Steps
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TalogColors.lightCanvas,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TalogColors.border, width: 1),
            ),
            child: Column(
              children: [
                _buildTimelineStep(
                  done: true,
                  active: false,
                  label: 'Tugas dibuat',
                ),
                const SizedBox(height: 6),
                _buildTimelineStep(
                  done: isSubmitted,
                  active: !isSubmitted,
                  label: 'Tugas dikumpulkan',
                ),
                const SizedBox(height: 6),
                _buildTimelineStep(
                  done: isGraded,
                  active: isSubmitted && !isGraded,
                  label: 'Sedang diperiksa',
                ),
                const SizedBox(height: 6),
                _buildTimelineStep(
                  done: isGraded,
                  active: false,
                  label: isGraded && score != null
                      ? 'Dinilai (Nilai: ${score!.toStringAsFixed(0)})'
                      : 'Dinilai',
                ),
              ],
            ),
          ),

          if (feedback != null && feedback!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TalogColors.deptBD.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TalogColors.deptBD.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_outlined, size: 16, color: TalogColors.deptBD),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Feedback Guru:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: TalogColors.deptBD),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          feedback!,
                          style: const TextStyle(fontSize: 12, color: TalogColors.textBody),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Footer: Deadline & Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 14, color: TalogColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Deadline: $dueAt',
                    style: const TextStyle(fontSize: 12, color: TalogColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (onSubmit != null)
                FilledButton.tonal(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: isSubmitted
                        ? TalogColors.lightCanvasSecondary
                        : TalogColors.accentOrange.withValues(alpha: 0.12),
                    foregroundColor: isSubmitted ? TalogColors.textBody : TalogColors.accentOrange,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isSubmitted ? 'Kirim Ulang' : 'Kumpulkan',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required bool done,
    required bool active,
    required String label,
  }) {
    IconData icon;
    Color iconColor;
    if (done) {
      icon = Icons.check_circle;
      iconColor = TalogColors.success;
    } else if (active) {
      icon = Icons.radio_button_checked;
      iconColor = TalogColors.accentOrange;
    } else {
      icon = Icons.radio_button_unchecked;
      iconColor = TalogColors.borderHover;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: done || active ? FontWeight.w600 : FontWeight.w400,
            color: done || active ? TalogColors.textHeading : TalogColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Informative Empty State Widget
class TalogEmptyState extends StatelessWidget {
  const TalogEmptyState({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.folder_open_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: TalogColors.lightCanvasSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: TalogColors.border),
              ),
              child: Icon(icon, color: TalogColors.textMuted, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: TalogColors.textHeading,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description,
                style: const TextStyle(fontSize: 13, color: TalogColors.textMuted, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TalogButton(
                label: actionLabel!,
                onPressed: onAction,
                isSecondary: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Friendly Error State with retry button
class TalogErrorState extends StatelessWidget {
  const TalogErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TalogColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TalogColors.danger.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: TalogColors.danger, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tidak dapat memuat data',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: TalogColors.textHeading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(fontSize: 12, color: TalogColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: TalogColors.danger.withValues(alpha: 0.12),
              foregroundColor: TalogColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Coba Lagi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
