import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login.dart';

// Variable globale pour stocker et synchroniser le rôle dynamiquement
String? globalUserRole;

// =============================================================================
// DESIGN SYSTEM
// =============================================================================

class Ui {
  Ui._();

  static const bg = Color(0xFF1A0F0A);
  static const surface = Color(0xFF2B1A12);
  static const surfaceHigh = Color(0xFF3B2519);
  static const violet = Color(0xFF9C2A1F); // rouge ocre copte
  static const violetDeep = Color(0xFF6B1812);
  static const violetSoft = Color(0xFFF0CF84); // or clair
  static const gold = Color(0xFFD8A441); // or copte
  static const text = Color(0xFFF7EDD6); // parchemin
  static const muted = Color(0xFFC8B291);
  static const danger = Color(0xFFFF6B7A);
  static const success = Color(0xFF3DDC97);
  static const info = Color(0xFF6CB6FF);

  static const gradient = LinearGradient(
    colors: [violet, violetDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const goldGradient = LinearGradient(
    colors: [violet, gold],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static InputDecoration input(String label, IconData? icon,
      {bool multiline = false}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: multiline,
      labelStyle: const TextStyle(color: muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
          color: violetSoft, fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: icon == null
          ? null
          : (multiline
          ? Padding(
          padding: const EdgeInsets.only(bottom: 44),
          child: Icon(icon, color: muted, size: 20))
          : Icon(icon, color: muted, size: 20)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Colors.white.withOpacity(0.10)),
      enabledBorder: border(Colors.white.withOpacity(0.10)),
      focusedBorder: border(violet, 1.6),
      errorBorder: border(danger, 1.2),
      focusedErrorBorder: border(danger, 1.6),
      errorStyle: const TextStyle(color: danger, fontSize: 12, height: 1.25),
      errorMaxLines: 3,
    );
  }

  static void snack(BuildContext context, String message, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }
}

const List<String> kMonths = [
  'Tous les mois',
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre'
];

final List<int> kYears = List.generate(2099 - 2026 + 1, (i) => 2026 + i);

const List<String> kAbounas = [
  'Abouna Cherubim El Moharaki',
  'Abouna Bedaba El Moharaki',
  'Abouna Moussa Wahib',
  'Abouna Yolios Anba Bishoy',
  'Abouna Antoine Wahba',
  'Abouna Youhana Sadek',
  'Abouna Joseph Stefanos',
  'Abouna Biktor Anba Bishoy',
  'Abouna Samuel Amin',
  'Abouna Anquelos Weessa',
  'Abouna Tawadros Iskander',
  'Abouna Kirellos Wakim',
  'Abouna Raphaël Dedieu',
  'Abouna Arsenios Gadan',
  'Abouna Abraham Shenouda',
  'Autre',
];

bool _isTeacher(String role) => role == 'Profs' || role == 'Chef d\'église';

/// Incrémenté à chaque modification d'un préseviteur : les pages qui affichent
/// la liste des préseviteurs se rechargent alors avec la classe à jour.
final ValueNotifier<int> preservantsRevision = ValueNotifier<int>(0);

ImageProvider? _imageFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return NetworkImage(url);
  final file = File(url.replaceFirst('file://', ''));
  return file.existsSync() ? FileImage(file) : null;
}

// ----- Widgets réutilisables ------------------------------------------------

/// Motif copte : arcades d'église en haut, losanges dorés et petites croix.
class CopticPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grande croix copte en filigrane, au centre de l'écran
    _copticCross(canvas, Offset(w / 2, h * 0.34), math.min(w, h) * 0.20,
        Paint()..color = Ui.gold.withOpacity(0.05));

    // Arcades de la nef le long du bord supérieur
    final arch = Paint()
      ..color = Ui.gold.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const span = 72.0;
    for (double x = -span / 2; x < w + span; x += span) {
      canvas.drawArc(Rect.fromLTWH(x, 0, span, span), math.pi, math.pi, false, arch);
    }

    // Silhouette d'église copte : nef, bas-côtés, coupole, croix et ouvertures
    _copticChurch(canvas, size);
  }

  void _copticCross(Canvas canvas, Offset c, double len, Paint p) {
    final arm = len * 0.28;
    canvas.drawRect(Rect.fromLTRB(c.dx - arm, c.dy - len, c.dx + arm, c.dy + len), p);
    canvas.drawRect(Rect.fromLTRB(c.dx - len, c.dy - arm, c.dx + len, c.dy + arm), p);
    final r = arm * 1.4;
    for (final o in [
      Offset(c.dx, c.dy - len),
      Offset(c.dx, c.dy + len),
      Offset(c.dx - len, c.dy),
      Offset(c.dx + len, c.dy),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - r)
          ..lineTo(o.dx + r, o.dy)
          ..lineTo(o.dx, o.dy + r)
          ..lineTo(o.dx - r, o.dy)
          ..close(),
        p,
      );
    }
  }

  void _copticChurch(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final naveTop = h * 0.74;
    final domeR = w * 0.10;

    final nave = Path()..addRect(Rect.fromLTRB(w * 0.30, naveTop, w * 0.70, h));
    final aisleL = Path()..addRect(Rect.fromLTRB(w * 0.16, h * 0.82, w * 0.30, h));
    final aisleR = Path()..addRect(Rect.fromLTRB(w * 0.70, h * 0.82, w * 0.84, h));
    final dome = Path()
      ..addArc(Rect.fromCircle(center: Offset(w / 2, naveTop), radius: domeR), math.pi, math.pi);
    final body = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, nave, aisleL),
      Path.combine(PathOperation.union, aisleR, dome),
    );

    canvas.drawPath(body, Paint()..color = Ui.bg.withOpacity(0.55));
    canvas.drawPath(
      body,
      Paint()
        ..color = Ui.gold.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Croix au sommet de la coupole
    _copticCross(canvas, Offset(w / 2, naveTop - domeR - w * 0.035), w * 0.035,
        Paint()..color = Ui.gold.withOpacity(0.40));

    // Fenêtres en arc et porte centrale
    final win = Paint()
      ..color = Ui.gold.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final ww = w * 0.05;
    for (final cx in [w * 0.37, w * 0.63]) {
      canvas.drawPath(_archPath(cx - ww / 2, naveTop + h * 0.05, ww, naveTop + h * 0.14), win);
    }
    canvas.drawPath(_archPath(w / 2 - ww / 2, naveTop + h * 0.10, ww, h), win);
  }

  Path _archPath(double x, double top, double width, double bottom) {
    return Path()
      ..moveTo(x, bottom)
      ..lineTo(x, top + width / 2)
      ..arcToPoint(
        Offset(x + width, top + width / 2),
        radius: Radius.circular(width / 2),
        clockwise: true,
      )
      ..lineTo(x + width, bottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CopticPattern extends StatelessWidget {
  const CopticPattern({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: CopticPatternPainter(), size: Size.infinite),
    );
  }
}

Widget copticGlow(Color color, double size, double opacity) {
  return IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(opacity), color.withOpacity(0)],
        ),
      ),
    ),
  );
}

/// Arrière-plan des pages principales : l'image d'église, sans voile ni motif.
class CopticBackground extends StatelessWidget {
  const CopticBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/1.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(color: Ui.bg),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Ui.surface.withOpacity(0.42),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: borderColor ?? Colors.white.withOpacity(0.08)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Croix copte : bras égaux, extrémités en losange, cercle central.
class CopticCrossPainter extends CustomPainter {
  final Color color;
  const CopticCrossPainter({this.color = Ui.gold});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final arm = s * 0.12;
    final len = s * 0.44;
    final p = Paint()..color = color;
    canvas.drawRect(Rect.fromLTRB(c.dx - arm, c.dy - len, c.dx + arm, c.dy + len), p);
    canvas.drawRect(Rect.fromLTRB(c.dx - len, c.dy - arm, c.dx + len, c.dy + arm), p);
    final r = arm * 1.5;
    for (final o in [
      Offset(c.dx, c.dy - len),
      Offset(c.dx, c.dy + len),
      Offset(c.dx - len, c.dy),
      Offset(c.dx + len, c.dy),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(o.dx, o.dy - r)
          ..lineTo(o.dx + r, o.dy)
          ..lineTo(o.dx, o.dy + r)
          ..lineTo(o.dx - r, o.dy)
          ..close(),
        p,
      );
    }
    canvas.drawCircle(c, arm * 1.05, Paint()..color = Ui.violet);
    canvas.drawCircle(
      c,
      arm * 1.05,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06,
    );
  }

  @override
  bool shouldRepaint(covariant CopticCrossPainter old) => old.color != color;
}

/// Bande décorative : filet d'or, losanges et croix copte au centre.
class CopticBand extends StatelessWidget {
  const CopticBand({super.key});

  @override
  Widget build(BuildContext context) {
    Widget diamond() => Transform.rotate(
      angle: 0.785,
      child: Container(width: 5, height: 5, color: Ui.gold.withOpacity(0.7)),
    );
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Ui.gold.withOpacity(0.35))),
        const SizedBox(width: 8),
        diamond(),
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          height: 14,
          child: CustomPaint(painter: CopticCrossPainter(color: Ui.gold)),
        ),
        const SizedBox(width: 8),
        diamond(),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Ui.gold.withOpacity(0.35))),
      ],
    );
  }
}

class PageShell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const PageShell({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -170,
              left: 0,
              right: 0,
              height: 380,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Ui.violet.withOpacity(0.26),
                        Ui.violet.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: Ui.gradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Ui.violet.withOpacity(0.4),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    color: Ui.text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (subtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      subtitle!,
                                      style: const TextStyle(
                                          color: Ui.muted, fontSize: 12.5),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (trailing != null) trailing!,
                        ],
                      ),
                      const SizedBox(height: 20),
                      const CopticBand(),
                      const SizedBox(height: 18),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  const SectionTitle(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: Ui.goldGradient,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Ui.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 11),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? Ui.gradient : null,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                    BoxShadow(
                      color: Ui.violet.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected ? Colors.white : Ui.muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class MonthYearBar extends StatelessWidget {
  final int month;
  final int year;
  final ValueChanged<int> onMonth;
  final ValueChanged<int> onYear;

  const MonthYearBar({
    super.key,
    required this.month,
    required this.year,
    required this.onMonth,
    required this.onYear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: month,
            dropdownColor: Ui.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Ui.muted),
            style: const TextStyle(color: Ui.text, fontSize: 14),
            decoration: Ui.input('Mois', Icons.calendar_month_rounded),
            items: List.generate(
              kMonths.length,
                  (i) => DropdownMenuItem(value: i, child: Text(kMonths[i])),
            ),
            onChanged: (v) {
              if (v != null) onMonth(v);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: year,
            dropdownColor: Ui.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Ui.muted),
            style: const TextStyle(color: Ui.text, fontSize: 14),
            decoration: Ui.input('Année', Icons.date_range_rounded),
            items: kYears
                .map((y) =>
                DropdownMenuItem(value: y, child: Text(y.toString())))
                .toList(),
            onChanged: (v) {
              if (v != null) onYear(v);
            },
          ),
        ),
      ],
    );
  }
}

class FileChip extends StatelessWidget {
  final String name;
  final VoidCallback? onTap;
  const FileChip({super.key, required this.name, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Ui.violet.withOpacity(0.14),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Ui.violet.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded,
                  size: 18, color: Ui.violetSoft),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Ui.violetSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.open_in_new_rounded,
                  size: 15, color: Ui.violetSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Ui.violet.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: Ui.violet.withOpacity(0.25)),
            ),
            child: Icon(icon, color: Ui.violetSoft, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Ui.muted, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: Ui.gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Ui.violet.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2.4, color: Colors.white),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const SoftButton(
      {super.key,
        required this.label,
        required this.icon,
        required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Flexible(
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: Ui.violetSoft,
        backgroundColor: Ui.violet.withOpacity(0.08),
        side: BorderSide(color: Ui.violet.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}

class MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const MiniAction({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const Pill(this.label, this.color, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? byline;
  final String? body;
  final String? fileName;
  final VoidCallback? onFile;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? footer;

  const ItemCard({
    super.key,
    required this.title,
    required this.icon,
    this.byline,
    this.body,
    this.fileName,
    this.onFile,
    this.onEdit,
    this.onDelete,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Ui.violet.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Ui.violetSoft, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Ui.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (byline != null && byline!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            byline!,
                            style: const TextStyle(
                              color: Ui.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  MiniAction(
                      icon: Icons.edit_rounded,
                      color: Ui.info,
                      tooltip: 'Modifier',
                      onTap: onEdit!),
                ],
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  MiniAction(
                      icon: Icons.delete_rounded,
                      color: Ui.danger,
                      tooltip: 'Supprimer',
                      onTap: onDelete!),
                ],
              ],
            ),
            if (body != null && body!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                body!,
                style: TextStyle(
                  color: Ui.text.withOpacity(0.78),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
            if (fileName != null && fileName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              FileChip(name: fileName!, onTap: onFile),
            ],
            if (footer != null) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 10),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class VersetCard extends StatelessWidget {
  final String titre;
  final String reference;
  final String verset;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? byline;

  const VersetCard({
    super.key,
    required this.titre,
    required this.reference,
    required this.verset,
    this.onEdit,
    this.onDelete,
    this.byline,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Ui.violetDeep.withOpacity(0.55),
              Ui.surface.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Ui.violet.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Ui.violet.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote_rounded,
                    color: Ui.gold, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(
                      color: Ui.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (onEdit != null)
                  MiniAction(
                      icon: Icons.edit_rounded,
                      color: Ui.info,
                      tooltip: 'Modifier',
                      onTap: onEdit!),
                if (onDelete != null) ...[
                  const SizedBox(width: 6),
                  MiniAction(
                      icon: Icons.delete_rounded,
                      color: Ui.danger,
                      tooltip: 'Supprimer',
                      onTap: onDelete!),
                ],
              ],
            ),
            if (byline != null && byline!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  byline!,
                  style: const TextStyle(
                    color: Ui.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              verset,
              style: const TextStyle(
                color: Ui.text,
                fontSize: 15,
                height: 1.55,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (reference.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '— $reference',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Ui.gold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Widget _styledDropdown<T>({
  required String label,
  required IconData icon,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
  String? Function(T?)? validator,
}) {
  return DropdownButtonFormField<T>(
    isExpanded: true,
    value: value,
    dropdownColor: Ui.surfaceHigh,
    borderRadius: BorderRadius.circular(16),
    menuMaxHeight: 320,
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Ui.muted),
    style: const TextStyle(color: Ui.text, fontSize: 15),
    decoration: Ui.input(label, icon),
    items: items,
    onChanged: onChanged,
    validator: validator,
  );
}

Widget _styledField(
    TextEditingController controller,
    String label,
    IconData icon, {
      int? maxLines = 1,
      TextInputType? keyboardType,
      String? Function(String?)? validator,
      List<TextInputFormatter>? formatters,
    }) {
  return TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: formatters,
    cursorColor: Ui.violet,
    style: const TextStyle(color: Ui.text, fontSize: 15),
    decoration: Ui.input(label, icon, multiline: maxLines != 1),
    validator: validator,
  );
}

Future<void> _openPath(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    if (path.startsWith('http')) {
      // Fichier stocké sur Supabase : on le télécharge puis on l'ouvre.
      final uri = Uri.parse(path);
      final name = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'devoir_${DateTime.now().millisecondsSinceEpoch}';
      final client = HttpClient();
      final req = await client.getUrl(uri);
      final res = await req.close();
      final file = File('${Directory.systemTemp.path}/$name');
      await res.pipe(file.openWrite());
      client.close();
      await OpenFilex.open(file.path);
      return;
    }
    await OpenFilex.open(path);
  } catch (e) {
    debugPrint('Erreur ouverture fichier : $e');
  }
}

// =============================================================================
// NAVIGATION & AVATAR
// =============================================================================

class NavigationNotifier extends Notifier<int> {
  final List<int> _history = [0];

  @override
  int build() => 0;

  void setIndex(int index) {
    if (state != index) {
      _history.remove(index);
      _history.add(index);
      state = index;
    }
  }

  void reset() {
    _history.clear();
    _history.add(0);
    state = 0;
  }

  bool goBack() {
    if (_history.length > 1) {
      _history.removeLast();
      state = _history.last;
      return true;
    } else if (state != 0) {
      state = 0;
      return true;
    }
    return false;
  }
}

final navigationIndexProvider =
NotifierProvider<NavigationNotifier, int>(NavigationNotifier.new);

class UserAvatarNotifier extends Notifier<String?> {
  // Incrémenté à chaque écriture : un chargement plus ancien qui se termine
  // en retard ne peut plus écraser une photo plus récente.
  int _gen = 0;

  // Clé propre à chaque compte, pour ne jamais afficher la photo d'un autre.
  String get _prefsKey {
    final id = Supabase.instance.client.auth.currentUser?.id;
    return id == null ? 'user_avatar_url' : 'user_avatar_url_$id';
  }

  @override
  String? build() {
    _loadInitialAvatar();
    return null;
  }

  Future<void> _loadInitialAvatar() async {
    final gen = ++_gen;
    final prefs = await SharedPreferences.getInstance();
    final user = Supabase.instance.client.auth.currentUser;
    final key = _prefsKey;

    String? resolvedUrl;

    if (user != null) {
      try {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('photo_url')
            .eq('id', user.id)
            .maybeSingle();
        final p = profileData?['photo_url']?.toString();
        if (p != null && p.isNotEmpty) resolvedUrl = p;
      } catch (_) {}
    }

    final metaUrl = user?.userMetadata?['photo_url']?.toString();
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      resolvedUrl = (metaUrl != null && metaUrl.isNotEmpty) ? metaUrl : null;
    }
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      resolvedUrl = prefs.getString(key);
    }

    if (resolvedUrl != null && !resolvedUrl.startsWith('http')) {
      final filePath = resolvedUrl.replaceFirst('file://', '');
      final file = File(filePath);
      if (!await file.exists()) {
        resolvedUrl = null;
        await prefs.remove(key);
      }
    }

    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
      await prefs.setString(key, resolvedUrl);
    }

    // Une photo plus récente a été posée pendant le chargement : on garde-la.
    if (gen != _gen) return;
    state = resolvedUrl;
  }

  Future<void> updateAvatar(String newUrl) async {
    _gen++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, newUrl);

    if (newUrl.startsWith('http')) {
      final base = newUrl.split('?').first;
      state = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
    } else {
      state = newUrl;
    }
  }

  void refresh() async {
    await _loadInitialAvatar();
  }

  Future<void> clearAvatar() async {
    _gen++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove('user_avatar_url');
    state = null;
  }
}

final userAvatarProvider =
NotifierProvider<UserAvatarNotifier, String?>(UserAvatarNotifier.new);

// =============================================================================
// APP
// =============================================================================

class EftekadApp extends ConsumerWidget {
  const EftekadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Eftekad',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Ui.violet,
          brightness: Brightness.dark,
          primary: Ui.violet,
          surface: Ui.surface,
        ),
        scaffoldBackgroundColor: Ui.bg,
        cardColor: Ui.surface,
        drawerTheme: const DrawerThemeData(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Ui.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
        ),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const PreservantPage(),
      },
      home: session == null ? const LoginScreen() : const PreservantPage(),
    );
  }
}

class PreservantPage extends ConsumerStatefulWidget {
  const PreservantPage({super.key});

  @override
  ConsumerState<PreservantPage> createState() => _PreservantPageState();
}

class _PreservantPageState extends ConsumerState<PreservantPage> {
  StreamSubscription<AuthState>? _authSubscription;
  String _userPrenom = '';
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // La page de connexion/inscription transmet l'URL de la photo : on s'en
      // sert tout de suite, sinon on la recharge depuis le profil.
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String && args.startsWith('http')) {
        ref.read(userAvatarProvider.notifier).updateAvatar(args);
      } else {
        ref.read(userAvatarProvider.notifier).refresh();
      }
      try {
        await Supabase.instance.client.auth.refreshSession();
        if (mounted) setState(() {});
      } catch (_) {}
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
          if (data.event == AuthChangeEvent.signedOut || data.session == null) {
            globalUserRole = null;
            return;
          }
          if (mounted) {
            setState(() {});
          }

          final newUrl = data.session?.user.userMetadata?['photo_url'];
          if (newUrl != null && newUrl.isNotEmpty) {
            ref.read(userAvatarProvider.notifier).updateAvatar(newUrl);
          } else if (data.session != null) {
            ref.read(userAvatarProvider.notifier).refresh();
          }
        });
  }

  Future<void> _loadUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      String? prenom = meta['prenom'] ?? meta['full_name'];
      String? role = meta['role'];

      if (prenom == null || prenom.isEmpty || role == null || role.isEmpty) {
        try {
          final profileData = await Supabase.instance.client
              .from('profiles')
              .select('prenom, role')
              .eq('id', user.id)
              .maybeSingle();
          if (profileData != null) {
            prenom ??= profileData['prenom'];
            role ??= profileData['role'];
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _userPrenom = prenom ?? '';
          _userRole = role ?? '';
          globalUserRole = _userRole;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    ref.read(navigationIndexProvider.notifier).reset();
    await ref.read(userAvatarProvider.notifier).clearAvatar();
    globalUserRole = null;

    await Supabase.instance.client.auth.signOut();

    navigator.pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
        const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        child,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final userPhotoUrl = ref.watch(userAvatarProvider);

    final List<Map<String, dynamic>> menuItems = [
      {
        'index': 0,
        'title': 'Accueil',
        'icon': Icons.home_rounded,
        'color': Ui.violetSoft
      },
      {
        'index': 1,
        'title': 'Cours',
        'icon': Icons.menu_book_rounded,
        'color': Ui.info
      },
      {
        'index': 2,
        'title': 'Rendre le devoir',
        'icon': Icons.upload_file_rounded,
        'color': Color(0xFFFFB86C)
      },
      {
        'index': 3,
        'title': 'Versets',
        'icon': Icons.format_quote_rounded,
        'color': Color(0xFFFF8FB8)
      },
      if (_isTeacher(_userRole))
        {
          'index': 5,
          'title': 'Gestion absence',
          'icon': Icons.fact_check_rounded,
          'color': Ui.success
        },
      {
        'index': 4,
        'title': 'Paramètres',
        'icon': Icons.settings_rounded,
        'color': Ui.gold
      },
    ];

    final List<Widget> pages = [
      const GeneralHome(),
      const CoursProfsPage(),
      const RenduCoursTab(),
      const VersetsPage(),
      const ParametresPage(),
      _isTeacher(_userRole)
          ? GestionAbsencePage(role: _userRole)
          : const SizedBox.shrink(),
    ];

    final avatar = _imageFromUrl(userPhotoUrl);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        ref.read(navigationIndexProvider.notifier).goBack();
      },
      child: Scaffold(
        drawer: Drawer(
          width: 300,
          child: ClipRRect(
            borderRadius:
            const BorderRadius.horizontal(right: Radius.circular(32)),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2A1A12), Color(0xFF1A0F0A)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête profil
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: [
                            Ui.violet.withOpacity(0.35),
                            Ui.violetDeep.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border:
                        Border.all(color: Ui.violet.withOpacity(0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: Ui.goldGradient,
                            ),
                            child: CircleAvatar(
                              key: ValueKey(userPhotoUrl),
                              radius: 32,
                              backgroundColor: Ui.surfaceHigh,
                              backgroundImage: avatar,
                              child: avatar == null
                                  ? const Icon(Icons.person_rounded,
                                  color: Ui.muted, size: 32)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _userPrenom.isNotEmpty
                                ? 'Bonjour, $_userPrenom'
                                : 'Bonjour',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Ui.text,
                            ),
                          ),
                          if (_userRole.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Pill(_userRole, Ui.gold,
                                icon: Icons.verified_rounded),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        children: menuItems.map((item) {
                          return _buildMenuItem(
                            context: context,
                            ref: ref,
                            index: item['index'] as int,
                            title: item['title'] as String,
                            icon: item['icon'] as IconData,
                            color: item['color'] as Color,
                            currentIndex: currentIndex,
                          );
                        }).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Material(
                        color: Ui.danger.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _signOut(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: Ui.danger.withOpacity(0.35)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: Ui.danger, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Déconnexion',
                                  style: TextStyle(
                                    color: Ui.danger,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
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
        body: Stack(
          children: [
            Positioned.fill(child: CopticBackground()),
            IndexedStack(
              index: currentIndex < pages.length ? currentIndex : 0,
              children: pages,
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Builder(
                builder: (context) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Material(
                        color: Ui.surface.withOpacity(0.85),
                        child: InkWell(
                          onTap: () {
                            ref
                                .read(userAvatarProvider.notifier)
                                .refresh();
                            Scaffold.of(context).openDrawer();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Ui.violet.withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Ui.violet.withOpacity(0.3),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.menu_rounded,
                                    color: Ui.violetSoft, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Menu',
                                  style: TextStyle(
                                    color: Ui.text,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required String title,
    required IconData icon,
    required Color color,
    required int currentIndex,
  }) {
    final isSelected = currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            ref.read(navigationIndexProvider.notifier).setIndex(index);
            Navigator.pop(context);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.16)
                  : Colors.white.withOpacity(0.02),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? color.withOpacity(0.5)
                    : Colors.white.withOpacity(0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isSelected ? 0.28 : 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Ui.text : Ui.muted,
                      fontWeight:
                      isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ACCUEIL
// =============================================================================

class GeneralHome extends StatefulWidget {
  const GeneralHome({super.key});

  @override
  State<GeneralHome> createState() => _GeneralHomeState();
}

class _GeneralHomeState extends State<GeneralHome> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<Map<String, dynamic>> _coursList = [];
  List<Map<String, dynamic>> _preservantsList = [];
  String _userPrenom = '';
  String _userRole = '';
  String _userClasse = '1ère année';
  int _profsTabindex = 0;

  late int _selectedMonthIndex;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthIndex = now.month;
    _selectedYear =
    now.year < 2026 ? 2026 : (now.year > 2099 ? 2099 : now.year);
    _loadUserData();
    _loadCours();
  }

  Future<void> _loadUserData() async {
    final me = await _currentProfile();
    if (me.isNotEmpty) {
      if (mounted) {
        setState(() {
          _userPrenom = (me['prenom'] ?? '').toString();
          _userRole = (me['role'] ?? '').toString();
          _userClasse = _classeOf(me['classe']);
        });
      }

      if (_isTeacher(_userRole)) {
        _loadPreservants();
      }
    }
  }

  Future<void> _loadPreservants() async {
    try {
      final response =
      await _supabase.from('profiles').select().eq('role', 'Préseviteur');
      if (mounted) {
        setState(() {
          _preservantsList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement préséviteurs : $e');
    }
  }

  void _modifierClassePreservant(Map<String, dynamic> preservant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _EditPreservantBottomSheet(
        preservantToEdit: preservant,
        onSuccess: () {
          _loadPreservants();
        },
      ),
    );
  }

  Future<void> _loadCours() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('cours').select();
      if (mounted) {
        setState(() {
          _coursList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement des cours Supabase : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    globalUserRole = null;
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
          const LoginScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) => child,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
            (route) => false,
      );
    }
  }

  void _showPreservantDetails(Map<String, dynamic> preservant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Ui.surfaceHigh,
              backgroundImage: _imageFromUrl(preservant['photo_url']),
              child: _imageFromUrl(preservant['photo_url']) == null
                  ? const Icon(Icons.person_rounded, color: Ui.muted)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${preservant['prenom'] ?? ''} ${preservant['nom'] ?? ''}',
                style: const TextStyle(
                    color: Ui.text, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(Icons.badge_rounded, 'Prénom', preservant['prenom']),
              _detailRow(Icons.badge_outlined, 'Nom', preservant['nom']),
              _detailRow(Icons.school_rounded, 'Classe', preservant['classe']),
              _detailRow(
                  Icons.phone_rounded, 'Téléphone', preservant['telephone']),
              _detailRow(Icons.church_rounded, 'Abouna confesseur',
                  preservant['pere_confesseur']),
              _detailRow(Icons.cake_rounded, 'Date de naissance',
                  preservant['date_naissance']),
              _detailRow(Icons.home_rounded, 'Adresse', preservant['adresse']),
              _detailRow(
                  Icons.location_city_rounded, 'Ville', preservant['ville']),
              _detailRow(Icons.pin_drop_rounded, 'Code postal',
                  preservant['code_postal']),
            ],
          ),
        ),
        actions: [
          if (_userRole == 'Chef d\'église')
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Ui.danger),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('Supprimer'),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Ui.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    title: const Text('Confirmer la suppression',
                        style: TextStyle(
                            color: Ui.text, fontWeight: FontWeight.w800)),
                    content: const Text(
                        'Voulez-vous vraiment supprimer définitivement ce compte ? Cette action est irréversible et empêchera toute connexion.',
                        style: TextStyle(color: Ui.muted)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler',
                            style: TextStyle(color: Ui.muted)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Ui.danger,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Supprimer',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  try {
                    final targetUserId = preservant['id'];
                    await _supabase.rpc('delete_user_by_id',
                        params: {'target_user_id': targetUserId});

                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadPreservants();
                      Ui.snack(
                          context,
                          'Compte supprimé définitivement avec succès.',
                          Ui.success.withOpacity(0.9));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Ui.snack(context, 'Erreur lors de la suppression : $e',
                          Colors.red.shade700);
                    }
                  }
                }
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer',
                style: TextStyle(
                    color: Ui.violetSoft, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Ui.violetSoft, size: 17),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Ui.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 1),
                Text(
                  value != null && value.toString().isNotEmpty
                      ? value.toString()
                      : 'Non renseigné',
                  style: const TextStyle(color: Ui.text, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: Ui.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Ui.violet.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Ui.violet.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/image/1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(gradient: Ui.gradient),
                  child: const Center(
                    child: Icon(Icons.church_rounded,
                        color: Colors.white54, size: 56),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Ui.bg.withOpacity(0.85),
                  ],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'St Mina, St Mercure & St Pape Cyrille VI',
                    style: TextStyle(
                      color: Ui.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Église Copte Orthodoxe, Colombes',
                    style: TextStyle(
                      color: Ui.gold,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

  Widget _preservantTile(Map<String, dynamic> p) {
    final prenom = p['prenom'] ?? '';
    final nom = p['nom'] ?? '';
    final classeActuelle = p['classe'] ?? '';
    final img = _imageFromUrl(p['photo_url']?.toString());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: Ui.goldGradient),
              child: CircleAvatar(
                radius: 23,
                backgroundColor: Ui.surfaceHigh,
                backgroundImage: img,
                child: img == null
                    ? const Icon(Icons.person_rounded,
                    color: Ui.muted, size: 22)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$prenom $nom',
                    style: const TextStyle(
                      color: Ui.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (classeActuelle.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Pill(classeActuelle.toString(), Ui.violetSoft,
                          icon: Icons.school_rounded),
                    ),
                ],
              ),
            ),
            // Les profs consultent seulement ; le chef d'église peut modifier.
            if (_userRole != 'Profs') ...[
              MiniAction(
                  icon: Icons.edit_rounded,
                  color: Ui.info,
                  tooltip: 'Modifier le profil',
                  onTap: () => _modifierClassePreservant(p)),
              const SizedBox(width: 6),
            ],
            MiniAction(
                icon: Icons.info_outline_rounded,
                color: Ui.violetSoft,
                tooltip: 'Informations',
                onTap: () => _showPreservantDetails(p)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teacher = _isTeacher(_userRole);

    final filteredPreservants = _preservantsList.where((p) {
      final classe = p['classe'] ?? '';
      if (_userRole == 'Profs') {
        return classe.toString().toLowerCase().contains('1') ||
            classe.toString().toLowerCase().contains('2');
      } else {
        if (_profsTabindex == 0) {
          return classe.toString().toLowerCase().contains('1');
        } else {
          return classe.toString().toLowerCase().contains('2');
        }
      }
    }).toList();

    final filteredCours = _coursList.where((c) {
      final cYear =
          int.tryParse('${c['year'] ?? _selectedYear}') ?? _selectedYear;
      final cMonth = int.tryParse('${c['month'] ?? _selectedMonthIndex}') ??
          _selectedMonthIndex;
      final cClasse = (c['classe'] ?? '').toString().trim().toLowerCase();

      final matchYear = cYear == _selectedYear;
      final matchMonth =
          _selectedMonthIndex == 0 || cMonth == _selectedMonthIndex;

      // Les Profs et le Chef d'église voient tous les cours.
      // Un Préseviteur ne voit que les cours déposés pour sa classe.
      bool matchClasse = true;
      if (!teacher) {
        final userClasse = _userClasse.toLowerCase();
        if (userClasse.contains('1')) {
          matchClasse = cClasse.contains('1');
        } else if (userClasse.contains('2')) {
          matchClasse = cClasse.contains('2');
        }
      }

      return matchYear && matchMonth && matchClasse;
    }).toList();

    return PageShell(
      title: _userPrenom.isNotEmpty ? 'Bonjour, $_userPrenom' : 'Bonjour',
      subtitle: 'Bienvenue sur Préservant',
      icon: Icons.waving_hand_rounded,
      trailing: IconButton(
        onPressed: _signOut,
        tooltip: 'Se déconnecter',
        style: IconButton.styleFrom(
          backgroundColor: Ui.danger.withOpacity(0.14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.logout_rounded, color: Ui.danger, size: 20),
      ),
      children: [
        _heroImage(),
        const SizedBox(height: 22),
        if (teacher) ...[
          const SectionTitle('Liste des Préseviteurs'),
          if (_userRole != 'Profs') ...[
            SegmentedTabs(
              labels: const ['1ère année', '2ème année'],
              index: _profsTabindex,
              onChanged: (i) => setState(() => _profsTabindex = i),
            ),
            const SizedBox(height: 14),
          ],
          if (filteredPreservants.isEmpty)
            const EmptyState(
              icon: Icons.groups_rounded,
              text: 'Aucun préséviteur dans cette classe.',
            )
          else
            ...filteredPreservants.map(_preservantTile),
        ] else ...[
          SectionTitle(
              'Dossiers & Cours · ${kMonths[_selectedMonthIndex]} $_selectedYear'),
          MonthYearBar(
            month: _selectedMonthIndex,
            year: _selectedYear,
            onMonth: (v) => setState(() => _selectedMonthIndex = v),
            onYear: (v) => setState(() => _selectedYear = v),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                  child: CircularProgressIndicator(color: Ui.violet)),
            )
          else if (filteredCours.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_rounded,
              text: 'Aucun cours pour cette période.',
            )
          else
            ...filteredCours.map((cours) {
              final titre = cours['titre'] ??
                  cours['titre_cours'] ??
                  'Cours sans titre';
              final description = cours['notes'] ??
                  cours['description'] ??
                  cours['contenu'] ??
                  '';
              final prof = cours['prof_prenom'];
              return ItemCard(
                title: titre.toString(),
                icon: Icons.menu_book_rounded,
                byline: (prof != null && prof.toString().isNotEmpty)
                    ? 'Par $prof'
                    : null,
                body: description.toString(),
                fileName: cours['file_name']?.toString(),
                onFile: () => _openPath(cours['file_path']),
              );
            }),
        ],
      ],
    );
  }
}

// =============================================================================
// BOTTOM SHEET DE MODIFICATION D'UN PRÉSEVITEUR
// =============================================================================

class _EditPreservantBottomSheet extends StatefulWidget {
  final Map<String, dynamic> preservantToEdit;
  final VoidCallback onSuccess;

  const _EditPreservantBottomSheet({
    required this.preservantToEdit,
    required this.onSuccess,
  });

  @override
  State<_EditPreservantBottomSheet> createState() =>
      _EditPreservantBottomSheetState();
}

class _EditPreservantBottomSheetState
    extends State<_EditPreservantBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late TextEditingController _lastNameController;
  late TextEditingController _firstNameController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _postalCodeController;
  late TextEditingController _phoneController;
  late TextEditingController _autrePereController;

  File? _imageFile;
  bool _isSubmitting = false;

  int? _selectedDay;
  int? _selectedMonth;
  int? _selectedYear;
  bool _dateError = false;

  String? _selectedAbouna;
  bool _abounaError = false;

  String? _selectedClasse;
  bool _classeError = false;

  final List<String> _classesOptions = [
    '1ère année',
    '2ème année',
    '1ere année',
    '2eme année'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.preservantToEdit;

    _lastNameController = TextEditingController(text: p['nom'] ?? '');
    _firstNameController = TextEditingController(text: p['prenom'] ?? '');
    _addressController = TextEditingController(text: p['adresse'] ?? '');
    _cityController = TextEditingController(text: p['ville'] ?? '');
    _postalCodeController =
        TextEditingController(text: p['code_postal'] ?? p['code'] ?? '');
    _phoneController =
        TextEditingController(text: p['telephone'] ?? p['phone'] ?? '+33');
    _autrePereController = TextEditingController();

    final pere = p['abouna_confesseur'] ?? p['abouna'] ?? p['pere_confesseur'];
    if (kAbounas.contains(pere)) {
      _selectedAbouna = pere;
    } else if (pere != null && pere.toString().isNotEmpty) {
      _selectedAbouna = 'Autre';
      _autrePereController.text = pere;
    }

    final classeExistante = p['classe'] ?? '';
    if (_classesOptions.contains(classeExistante)) {
      _selectedClasse = classeExistante;
    } else {
      _selectedClasse = '1ère année';
    }

    if (p['date_naissance'] != null) {
      try {
        final parsedDate = DateTime.parse(p['date_naissance']);
        _selectedDay = parsedDate.day;
        _selectedMonth = parsedDate.month;
        _selectedYear = parsedDate.year;
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _lastNameController.dispose();
    _firstNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _phoneController.dispose();
    _autrePereController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              _sheetOption(Icons.photo_library_rounded, 'Galerie', () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              }),
              const SizedBox(height: 10),
              _sheetOption(Icons.camera_alt_rounded, 'Appareil photo', () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Ui.violet.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Ui.violetSoft, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(
              color: Ui.text, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+330')) {
      cleaned = '+33${cleaned.substring(4)}';
    } else if (cleaned.startsWith('06')) {
      cleaned = '+33${cleaned.substring(1)}';
    } else if (cleaned.startsWith('07')) {
      cleaned = '+33${cleaned.substring(1)}';
    }
    return cleaned;
  }

  Future<void> _submitForm() async {
    final isFormValid = _formKey.currentState!.validate();

    setState(() {
      _dateError = (_selectedDay == null ||
          _selectedMonth == null ||
          _selectedYear == null);
      _abounaError = (_selectedAbouna == null || _selectedAbouna!.isEmpty);
      _classeError = (_selectedClasse == null || _selectedClasse!.isEmpty);
    });

    if (!isFormValid || _dateError || _abounaError || _classeError) return;

    setState(() => _isSubmitting = true);

    try {
      String? photoUrl = widget.preservantToEdit['photo_url'];

      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final path = 'avatars/$fileName';
        await _supabase.storage.from('avatars').upload(path, _imageFile!);
        photoUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      }

      final birthDateFormatted =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}';

      final cleanedPhone = _cleanPhoneNumber(_phoneController.text.trim());
      final finalAbouna = _selectedAbouna == 'Autre'
          ? _autrePereController.text.trim()
          : _selectedAbouna;

      final payload = {
        'nom': _lastNameController.text.trim(),
        'prenom': _firstNameController.text.trim(),
        'role': 'Préseviteur',
        'adresse': _addressController.text.trim(),
        'ville': _cityController.text.trim(),
        'code_postal': _postalCodeController.text.trim(),
        'telephone': cleanedPhone,
        'phone': cleanedPhone,
        'date_naissance': birthDateFormatted,
        'abouna_confesseur': finalAbouna,
        'abouna': finalAbouna,
        'pere_confesseur': finalAbouna,
        'classe': _selectedClasse,
        'photo_url': photoUrl,
      };

      final targetUserId = widget.preservantToEdit['id'];

      // 1) autres champs (la classe est gérée séparément, côté serveur)
      final otherFields = Map<String, dynamic>.from(payload)
        ..remove('classe');
      await _supabase
          .from('profiles')
          .update(otherFields)
          .eq('id', targetUserId);

      // 2) la classe passe par une fonction SQL qui renvoie la ligne modifiée :
      //    si Supabase refuse, on a une VRAIE erreur (plus de modif "fantôme").
      final updated = await _supabase.rpc('set_preservant_classe', params: {
        'target_user_id': targetUserId,
        'new_classe': _selectedClasse,
      });
      final savedClasse = (updated is Map ? updated['classe'] : null);
      if (savedClasse == null ||
          _classeOf(savedClasse) != _classeOf(_selectedClasse)) {
        throw Exception('La classe n\'a pas été enregistrée');
      }
      payload['classe'] = savedClasse;

      try {
        await _supabase.auth.admin.updateUserById(
          targetUserId,
          attributes: AdminUserAttributes(
            userMetadata: payload,
          ),
        );
      } catch (_) {
        if (_supabase.auth.currentUser?.id == targetUserId) {
          await _supabase.auth.updateUser(
            UserAttributes(data: payload),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
        Ui.snack(context, 'Profil modifié avec succès !',
            Colors.green.shade700);
        widget.onSuccess();
        preservantsRevision.value++;
      }
    } catch (e) {
      if (mounted) {
        Ui.snack(context, 'Erreur lors de la modification : $e',
            Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _errorText(String text) => Padding(
    padding: const EdgeInsets.only(top: 6, left: 12),
    child: Text(text,
        softWrap: true,
        style: const TextStyle(color: Ui.danger, fontSize: 12)),
  );

  Future<void> _pickFromList<T>({
    required String title,
    required List<T> options,
    required T? current,
    required String Function(T) labelOf,
    required ValueChanged<T> onPicked,
  }) async {
    final choice = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                    color: Ui.text, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final opt = options[i];
                    final selected = opt == current;
                    return ListTile(
                      onTap: () => Navigator.pop(ctx, opt),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      tileColor:
                      selected ? Ui.violet.withOpacity(0.16) : null,
                      title: Text(
                        labelOf(opt),
                        softWrap: true,
                        style: TextStyle(
                          color: Ui.text,
                          fontSize: 15,
                          fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                          color: Ui.violetSoft)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null) onPicked(choice);
  }

  Future<void> _pickAbouna() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choisir l\'Abouna confesseur',
                style: TextStyle(
                    color: Ui.text, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                  children: kAbounas.map((a) {
                    final selected = a == _selectedAbouna;
                    return ListTile(
                      onTap: () => Navigator.pop(ctx, a),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      tileColor:
                      selected ? Ui.violet.withOpacity(0.16) : null,
                      title: Text(
                        a,
                        softWrap: true,
                        style: TextStyle(
                          color: Ui.text,
                          fontSize: 15,
                          fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded,
                          color: Ui.violetSoft)
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (choice != null) {
      setState(() {
        _selectedAbouna = choice;
        _abounaError = false;
      });
    }
  }

  Widget _sectionTitle(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 2),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Ui.violetSoft),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Ui.violetSoft,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );

  Widget _pickerField({
    required String label,
    IconData? icon,
    IconData? suffix,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final has = value != null && value.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: Ui.input(label, icon).copyWith(
          suffixIcon: suffix == null
              ? null
              : Icon(suffix, color: Ui.muted, size: 20),
        ),
        child: Text(
          has ? value : placeholder,
          softWrap: true,
          style: TextStyle(
            color: has ? Ui.text : Ui.muted,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _classeChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() {
        _selectedClasse = label;
        _classeError = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        decoration: BoxDecoration(
          gradient: selected ? Ui.gradient : null,
          color: selected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                softWrap: true,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Ui.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classeSelector(String? classeValue) {
    const options = ['1ère année', '2ème année'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Classe',
            style: const TextStyle(
              color: Ui.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _classeChip(options[i], classeValue == options[i]),
              ),
            ],
          ],
        ),
        if (_classeError) _errorText('Veuillez sélectionner la classe'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final existingPhoto = widget.preservantToEdit['photo_url'];
    final avatar = _imageFile != null
        ? FileImage(_imageFile!) as ImageProvider
        : _imageFromUrl(existingPhoto?.toString());

    String? classeValue;
    if (['1ère année', '1ere année'].contains(_selectedClasse)) {
      classeValue = '1ère année';
    } else if (['2ème année', '2eme année'].contains(_selectedClasse)) {
      classeValue = '2ème année';
    }

    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Modifier le profil du Préseviteur',
                    softWrap: true,
                    style: TextStyle(
                      color: Ui.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Ui.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: Ui.goldGradient),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor: Ui.surfaceHigh,
                                    backgroundImage: avatar,
                                    child: avatar == null
                                        ? const Icon(Icons.person_rounded,
                                        color: Ui.muted, size: 38)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      gradient: Ui.gradient,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Ui.surface, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Changer la photo',
                              style: TextStyle(
                                color: Ui.violetSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    _sectionTitle('Identité', Icons.badge_rounded),
                    _styledField(_lastNameController, 'Nom', Icons.badge_rounded,
                        validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Champ requis' : null),
                    const SizedBox(height: 12),
                    _styledField(_firstNameController, 'Prénom',
                        Icons.person_outline_rounded,
                        validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Champ requis' : null),

                    const SizedBox(height: 24),
                    _sectionTitle('Naissance et paroisse', Icons.church_rounded),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _pickerField(
                            label: 'Jour',
                            value: _selectedDay?.toString().padLeft(2, '0'),
                            placeholder: '--',
                            onTap: () => _pickFromList<int>(
                              title: 'Choisir le jour',
                              options: List.generate(31, (i) => i + 1),
                              current: _selectedDay,
                              labelOf: (d) => d.toString().padLeft(2, '0'),
                              onPicked: (v) => setState(() {
                                _selectedDay = v;
                                _dateError = false;
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 4,
                          child: _pickerField(
                            label: 'Mois',
                            value: _selectedMonth == null
                                ? null
                                : kMonths[_selectedMonth!],
                            placeholder: '--',
                            onTap: () => _pickFromList<int>(
                              title: 'Choisir le mois',
                              options: List.generate(12, (i) => i + 1),
                              current: _selectedMonth,
                              labelOf: (m) => kMonths[m],
                              onPicked: (v) => setState(() {
                                _selectedMonth = v;
                                _dateError = false;
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: _pickerField(
                            label: 'Année',
                            value: _selectedYear?.toString(),
                            placeholder: '----',
                            onTap: () => _pickFromList<int>(
                              title: 'Choisir l\'année',
                              options: List.generate(
                                  70, (i) => DateTime.now().year - 10 - i),
                              current: _selectedYear,
                              labelOf: (y) => y.toString(),
                              onPicked: (v) => setState(() {
                                _selectedYear = v;
                                _dateError = false;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_dateError)
                      _errorText(
                          'Veuillez sélectionner la date de naissance complète'),
                    const SizedBox(height: 12),
                    _pickerField(
                      label: 'Abouna confesseur',
                      icon: Icons.church_rounded,
                      suffix: Icons.unfold_more_rounded,
                      value: kAbounas.contains(_selectedAbouna)
                          ? _selectedAbouna
                          : null,
                      placeholder: 'Choisir un Abouna',
                      onTap: _pickAbouna,
                    ),
                    if (_selectedAbouna == 'Autre') ...[
                      const SizedBox(height: 12),
                      _styledField(_autrePereController,
                          'Précisez le nom d\'Abouna', Icons.edit_rounded,
                          validator: (value) => _selectedAbouna == 'Autre' &&
                              (value == null || value.trim().isEmpty)
                              ? 'Champ requis'
                              : null),
                    ],
                    if (_abounaError)
                      _errorText('Veuillez sélectionner un père confesseur'),
                    const SizedBox(height: 16),
                    _classeSelector(classeValue),

                    const SizedBox(height: 24),
                    _sectionTitle('Contact et adresse', Icons.contact_phone_rounded),
                    _styledField(_phoneController, 'Téléphone',
                        Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Champ requis' : null),
                    const SizedBox(height: 12),
                    _styledField(_addressController, 'Adresse (optionnel)',
                        Icons.home_outlined),
                    const SizedBox(height: 12),
                    _styledField(_cityController, 'Ville (optionnel)',
                        Icons.location_city_rounded),
                    const SizedBox(height: 12),
                    _styledField(_postalCodeController,
                        'Code postal (optionnel)', Icons.pin_drop_rounded,
                        keyboardType: TextInputType.number),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Ui.surface,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: GradientButton(
              label: 'Enregistrer les modifications',
              icon: Icons.check_rounded,
              loading: _isSubmitting,
              onPressed: _submitForm,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COURS
// =============================================================================

class CoursProfsPage extends StatefulWidget {
  const CoursProfsPage({super.key});

  @override
  State<CoursProfsPage> createState() => _CoursProfsPageState();
}

class _CoursProfsPageState extends State<CoursProfsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _profPrenomController = TextEditingController();

  String? _selectedFileName;
  String? _selectedFilePath;
  bool _isLoading = false;
  List<Map<String, dynamic>> _coursList = [];

  int _selectedTabYearIndex = 0;
  final List<String> _classesProfs = ['1ère année', '2ème année'];

  late int _selectedMonthIndex;
  late int _selectedYear;

  String? _editingCoursId;

  String _userRole = '';
  String _userPrenom = '';
  String _userClasse = '1ère année';
  bool _roleLoaded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthIndex = now.month;
    _selectedYear =
    now.year < 2026 ? 2026 : (now.year > 2099 ? 2099 : now.year);
    _loadUser();
    _loadCoursFromSupabase();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _notesController.dispose();
    _profPrenomController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final me = await _currentProfile();
    if (mounted) {
      setState(() {
        _userRole = (me['role'] ?? '').toString();
        _userPrenom = (me['prenom'] ?? '').toString().trim();
        // Le prénom affiché et enregistré est toujours celui du compte connecté.
        _profPrenomController.text = _userPrenom;
        _userClasse = _classeOf(me['classe']);
        _roleLoaded = true;
      });
    }
  }

  Future<void> _loadCoursFromSupabase() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('cours').select();
      if (mounted) {
        setState(() {
          _coursList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement cours Supabase : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCours() async {
    if (_titreController.text.trim().isEmpty) {
      Ui.snack(context, 'Veuillez entrer un titre de cours', Ui.surfaceHigh);
      return;
    }

    try {
      final currentClasse = _classesProfs[_selectedTabYearIndex];
      final payload = {
        'titre': _titreController.text.trim(),
        'notes': _notesController.text.trim(),
        'prof_prenom': _userPrenom,
        'classe': currentClasse,
        'file_name': _selectedFileName,
        'file_path': _selectedFilePath,
        'month': _selectedMonthIndex,
        'year': _selectedYear,
      };

      if (_editingCoursId != null) {
        await _supabase
            .from('cours')
            .update(payload)
            .eq('id', _editingCoursId!);
        _editingCoursId = null;
      } else {
        await _supabase.from('cours').insert(payload);
      }

      _titreController.clear();
      _notesController.clear();
      _profPrenomController.text = _userPrenom;
      setState(() {
        _selectedFileName = null;
        _selectedFilePath = null;
      });

      if (mounted) {
        Ui.snack(context, 'Cours enregistré et synchronisé avec succès !',
            Colors.green.shade700);
      }
      _loadCoursFromSupabase();
    } catch (e) {
      debugPrint('Erreur sauvegarde cours : $e');
      if (mounted) {
        Ui.snack(context, 'Erreur : $e', Colors.red.shade700);
      }
    }
  }

  void _editCours(Map<String, dynamic> c) {
    setState(() {
      _editingCoursId = c['id'];
      _titreController.text = c['titre'] ?? '';
      _notesController.text = c['notes'] ?? '';
      _profPrenomController.text = _userPrenom;
      _selectedFileName = c['file_name'];
      _selectedFilePath = c['file_path'];
      if (c['month'] != null) _selectedMonthIndex = c['month'];
      if (c['year'] != null) _selectedYear = c['year'];

      final classeCours = c['classe'] ?? '1ère année';
      if (classeCours.toString().toLowerCase().contains('2')) {
        _selectedTabYearIndex = 1;
      } else {
        _selectedTabYearIndex = 0;
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCoursId = null;
      _titreController.clear();
      _notesController.clear();
      _profPrenomController.text = _userPrenom;
      _selectedFileName = null;
      _selectedFilePath = null;
    });
  }

  Future<void> _deleteCours(String coursId) async {
    try {
      await _supabase.from('cours').delete().eq('id', coursId);
      if (_editingCoursId == coursId) {
        _cancelEdit();
      }
      _loadCoursFromSupabase();
      if (mounted) {
        Ui.snack(context, 'Cours supprimé avec succès pour tous',
            Ui.danger.withOpacity(0.9));
      }
    } catch (e) {
      debugPrint('Erreur suppression cours : $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      debugPrint('Erreur sélection fichier : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Ui.violet)),
      );
    }

    // Vue préséviteur : lecture seule, uniquement les cours de sa classe.
    if (!_isTeacher(_userRole)) {
      final isSecond = _userClasse.toLowerCase().contains('2');
      final mesCours = _coursList.where((c) {
        final cClasse = (c['classe'] ?? '').toString().toLowerCase();
        final cYear =
            int.tryParse('${c['year'] ?? _selectedYear}') ?? _selectedYear;
        final cMonth = int.tryParse('${c['month'] ?? _selectedMonthIndex}') ??
            _selectedMonthIndex;
        final matchClasse =
        isSecond ? cClasse.contains('2') : cClasse.contains('1');
        return matchClasse &&
            cYear == _selectedYear &&
            (_selectedMonthIndex == 0 || cMonth == _selectedMonthIndex);
      }).toList();

      return PageShell(
        title: 'Mes cours',
        subtitle: 'Cours de votre classe · $_userClasse',
        icon: Icons.menu_book_rounded,
        children: [
          MonthYearBar(
            month: _selectedMonthIndex,
            year: _selectedYear,
            onMonth: (v) => setState(() => _selectedMonthIndex = v),
            onYear: (v) => setState(() => _selectedYear = v),
          ),
          const SizedBox(height: 18),
          SectionTitle(
              'Cours · ${kMonths[_selectedMonthIndex]} $_selectedYear'),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child:
              Center(child: CircularProgressIndicator(color: Ui.violet)),
            )
          else if (mesCours.isEmpty)
            const EmptyState(
              icon: Icons.menu_book_rounded,
              text: 'Aucun cours pour cette période.',
            )
          else
            ...mesCours.map((c) {
              final prof = (c['prof_prenom'] ?? '').toString();
              return ItemCard(
                title: (c['titre'] ?? 'Cours sans titre').toString(),
                icon: Icons.menu_book_rounded,
                byline: prof.isNotEmpty ? 'Par $prof' : null,
                body: (c['notes'] ?? '').toString(),
                fileName: c['file_name']?.toString(),
                onFile: () => _openPath(c['file_path']),
              );
            }),
        ],
      );
    }

    final currentActiveClasse = _classesProfs[_selectedTabYearIndex];

    final filteredCours = _coursList.where((c) {
      final cClasse = c['classe'] ?? '1ère année';
      final cYear = c['year'] ?? _selectedYear;
      final cMonth = c['month'] ?? _selectedMonthIndex;

      bool matchClasse = false;
      if (_selectedTabYearIndex == 0) {
        matchClasse = cClasse.toString().toLowerCase().contains('1');
      } else {
        matchClasse = cClasse.toString().toLowerCase().contains('2');
      }

      bool matchYear = cYear == _selectedYear;
      bool matchMonth =
          _selectedMonthIndex == 0 || cMonth == _selectedMonthIndex;

      return matchClasse && matchYear && matchMonth;
    }).toList();

    return PageShell(
      title: 'Cours & Idées',
      subtitle: 'Gestion des cours · Professeurs',
      icon: Icons.menu_book_rounded,
      children: [
        SegmentedTabs(
          labels: _classesProfs,
          index: _selectedTabYearIndex,
          onChanged: (i) => setState(() => _selectedTabYearIndex = i),
        ),
        const SizedBox(height: 14),
        MonthYearBar(
          month: _selectedMonthIndex,
          year: _selectedYear,
          onMonth: (v) => setState(() => _selectedMonthIndex = v),
          onYear: (v) => setState(() => _selectedYear = v),
        ),
        const SizedBox(height: 18),
        GlassCard(
          borderColor: Ui.violet.withOpacity(0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                      _editingCoursId != null
                          ? Icons.edit_note_rounded
                          : Icons.add_circle_rounded,
                      color: Ui.gold,
                      size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _editingCoursId != null
                          ? 'Modifier le cours'
                          : 'Nouveau cours · $currentActiveClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)',
                      style: const TextStyle(
                        color: Ui.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _styledField(
                  _titreController, 'Titre du cours', Icons.book_rounded),
              const SizedBox(height: 12),
              TextFormField(
                controller: _profPrenomController,
                readOnly: true,
                style: const TextStyle(color: Ui.text, fontSize: 15),
                decoration: Ui.input(
                  _userRole == 'Chef d\'église'
                      ? 'Prénom du chef d\'église'
                      : 'Prénom du professeur',
                  Icons.person_rounded,
                ).copyWith(
                  suffixIcon: const Icon(Icons.lock_rounded,
                      color: Ui.muted, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              _styledField(_notesController, 'Notes / Description / Idée',
                  Icons.note_rounded,
                  maxLines: 3),
              const SizedBox(height: 12),
              SoftButton(
                onPressed: _pickFile,
                icon: Icons.attach_file_rounded,
                label: _selectedFileName ?? 'Joindre un fichier (optionnel)',
              ),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: _saveCours,
                icon: Icons.check_rounded,
                label: _editingCoursId != null
                    ? 'Valider'
                    : 'Enregistrer le cours',
              ),
              if (_editingCoursId != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _cancelEdit,
                  child: const Text('Annuler la modification',
                      style: TextStyle(color: Ui.muted, fontSize: 13)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionTitle(
            'Cours enregistrés · $currentActiveClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)'),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(color: Ui.violet)),
          )
        else if (filteredCours.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_rounded,
            text: 'Aucun cours enregistré pour cette période.',
          )
        else
          ...filteredCours.map((c) {
            final coursId = c['id'];
            final profPrenom = (c['prof_prenom'] ?? '').toString();
            return ItemCard(
              title: (c['titre'] ?? '').toString(),
              icon: Icons.menu_book_rounded,
              byline: profPrenom.isNotEmpty ? 'Par $profPrenom' : null,
              body: (c['notes'] ?? '').toString(),
              fileName: c['file_name']?.toString(),
              onFile: () => _openPath(c['file_path']),
              onEdit: () => _editCours(c),
              onDelete: () => _deleteCours(coursId),
            );
          }),
      ],
    );
  }
}

// =============================================================================
// RENDRE LE DEVOIR
// =============================================================================

class RenduCoursTab extends StatefulWidget {
  const RenduCoursTab({super.key});

  @override
  State<RenduCoursTab> createState() => _RenduCoursTabState();
}

class _RenduCoursTabState extends State<RenduCoursTab> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _userRole = '';
  List<Map<String, dynamic>> _preservantsList = [];

  String _selectedClasse = '1ère année';
  final List<String> _classesProfs = ['1ère année', '2ème année'];
  Map<String, dynamic>? _selectedPreservant;

  late int _selectedMonthIndex;
  late int _selectedYear;

  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedFileName;
  String? _selectedFilePath;
  List<Map<String, dynamic>> _devoirsList = [];
  List<Map<String, dynamic>> _devoirsRendusList = [];
  int? _editingIndex;

  String? _studentSelectedFileName;
  String? _studentSelectedFilePath;
  List<Map<String, dynamic>> _enseignantsList = [];
  Map<String, dynamic>? _selectedEnseignant;
  String _studentName = '';
  String _studentClasse = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthIndex = now.month;
    _selectedYear =
    now.year < 2026 ? 2026 : (now.year > 2099 ? 2099 : now.year);
    _loadUserRoleAndData();
    preservantsRevision.addListener(_onPreservantsChanged);
  }

  @override
  void dispose() {
    preservantsRevision.removeListener(_onPreservantsChanged);
    _titreController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRoleAndData() async {
    final me = await _currentProfile();
    final prenom = (me['prenom'] ?? '').toString();
    final nom = (me['nom'] ?? '').toString();
    if (mounted) {
      setState(() {
        _userRole = (me['role'] ?? '').toString();
        _studentName = '$prenom $nom'.trim();
        _studentClasse = _classeOf(me['classe']);
      });
    }
    if (_isTeacher(_userRole)) {
      _loadPreservants();
    } else {
      _loadEnseignants();
    }
    _loadDevoirs();
    _loadDevoirsRendus();
  }

  void _onPreservantsChanged() {
    _loadPreservants();
  }

  Future<void> _loadPreservants() async {
    try {
      final response =
      await _supabase.from('profiles').select().eq('role', 'Préseviteur');
      if (mounted) {
        setState(() {
          _preservantsList = List<Map<String, dynamic>>.from(response);
          // La sélection doit pointer vers la version à jour du préseviteur
          // (sinon le menu ne correspond plus et garde l'ancienne classe).
          if (_selectedPreservant != null) {
            final id = _selectedPreservant!['id'];
            final fresh = _preservantsList.where((p) => p['id'] == id).toList();
            final stillInClass = fresh.isNotEmpty &&
                _classeOf(fresh.first['classe']) == _selectedClasse;
            _selectedPreservant = stillInClass ? fresh.first : null;
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement préséviteurs : $e');
    }
  }

  Widget _noteFooter(Map<String, dynamic> d) {
    final note = (d['note'] ?? '').toString();
    final sur = (d['sur'] ?? '20').toString();
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: note.isEmpty
                ? const Pill('Non noté', Ui.muted,
                icon: Icons.hourglass_empty_rounded)
                : Pill('Note : $note/$sur', Ui.gold,
                icon: Icons.grade_rounded),
          ),
        ),
        TextButton.icon(
          onPressed: () => _showModifierRenduSheet(d),
          icon: const Icon(Icons.edit_rounded, size: 18),
          label: const Text('Modifier'),
          style: TextButton.styleFrom(foregroundColor: Ui.info),
        ),
      ],
    );
  }

  void _showModifierRenduSheet(Map<String, dynamic> d) {
    final hasFile = d['filePath'] != null &&
        (d['filePath'] ?? '').toString().isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.grade_rounded, color: Ui.gold),
              title: const Text('Noter / modifier la note',
                  style: TextStyle(color: Ui.text)),
              onTap: () {
                Navigator.pop(ctx);
                _noterDevoir(d);
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded, color: Ui.info),
              title: const Text('Changer le fichier',
                  style: TextStyle(color: Ui.text)),
              onTap: () {
                Navigator.pop(ctx);
                _remplacerFichierRendu(d);
              },
            ),
            if (hasFile)
              ListTile(
                leading:
                const Icon(Icons.delete_outline_rounded, color: Ui.danger),
                title: const Text('Supprimer le fichier',
                    style: TextStyle(color: Ui.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  _supprimerFichierRendu(d);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _supprimerFichierRendu(Map<String, dynamic> d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ui.surface,
        title: const Text('Supprimer le fichier ?',
            style: TextStyle(color: Ui.text)),
        content: Text(
          'Le fichier rendu par ${d['studentName'] ?? 'cet élève'} sera supprimé. La note est conservée.',
          style: const TextStyle(color: Ui.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Ui.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Ui.danger)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await _supabase
          .from('devoirs_rendus')
          .update({'file_name': null, 'file_url': null})
          .eq('id', d['id'])
          .select();
      if (res.isEmpty) throw Exception('Action refusée (droits Supabase)');
      setState(() {
        d.remove('fileName');
        d.remove('filePath');
      });
      if (mounted) {
        Ui.snack(context, 'Fichier supprimé', Ui.danger.withOpacity(0.9));
      }
    } catch (e) {
      debugPrint('Erreur suppression fichier rendu : $e');
    }
  }

  Future<void> _noterDevoir(Map<String, dynamic> d) async {
    final noteController =
    TextEditingController(text: (d['note'] ?? '').toString());
    final surController =
    TextEditingController(text: (d['sur'] ?? '').toString());
    String? noteError;
    String? surError;

    String fmt(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Ui.surface,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Note de ${d['studentName'] ?? 'Élève'}',
            style: const TextStyle(
                color: Ui.text, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: noteController,
                  autofocus: true,
                  cursorColor: Ui.violet,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Ui.text, fontSize: 16),
                  decoration: Ui.input('Note', Icons.grade_rounded)
                      .copyWith(errorText: noteError),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: surController,
                  cursorColor: Ui.violet,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Ui.text, fontSize: 16),
                  decoration: Ui.input('Sur combien ? (ex. 20)',
                      Icons.straighten_rounded)
                      .copyWith(errorText: surError),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Ui.muted)),
            ),
            TextButton(
              onPressed: () {
                final rawNote =
                noteController.text.trim().replaceAll(',', '.');
                final rawSur = surController.text.trim().replaceAll(',', '.');
                if (rawNote.isEmpty && rawSur.isEmpty) {
                  Navigator.pop(ctx, {'note': '', 'sur': ''});
                  return;
                }
                final n = double.tryParse(rawNote);
                final m = double.tryParse(rawSur);
                String? ne;
                String? se;
                if (n == null || n < 0) ne = 'Entrez une note valide';
                if (m == null || m <= 0) se = 'Entrez le barème (ex. 20)';
                if (ne == null && se == null && n! > m!) {
                  ne = 'La note ne peut pas dépasser $rawSur';
                }
                if (ne != null || se != null) {
                  setLocal(() {
                    noteError = ne;
                    surError = se;
                  });
                  return;
                }
                Navigator.pop(ctx, {'note': fmt(n!), 'sur': fmt(m!)});
              },
              child: const Text('Enregistrer',
                  style: TextStyle(
                      color: Ui.violetSoft, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    final newNote = result['note'] ?? '';
    final newSur = result['sur'] ?? '';

    try {
      final res = await _supabase
          .from('devoirs_rendus')
          .update({
        'note': newNote.isEmpty ? null : newNote,
        'sur': newNote.isEmpty ? null : newSur,
      })
          .eq('id', d['id'])
          .select();
      if (res.isEmpty) throw Exception('Note refusée (droits Supabase)');
      setState(() {
        if (newNote.isEmpty) {
          d.remove('note');
          d.remove('sur');
        } else {
          d['note'] = newNote;
          d['sur'] = newSur;
        }
      });
      if (mounted) {
        Ui.snack(
            context,
            newNote.isEmpty
                ? 'Note retirée'
                : 'Note enregistrée : $newNote/$newSur',
            Colors.green.shade700);
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde note : $e');
    }
  }

  Future<void> _remplacerFichierRendu(Map<String, dynamic> d) async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) return;
      final url = await _uploadDevoirFile(
          result.files.single.path, result.files.single.name);
      final res = await _supabase
          .from('devoirs_rendus')
          .update({'file_name': result.files.single.name, 'file_url': url})
          .eq('id', d['id'])
          .select();
      if (res.isEmpty) throw Exception('Action refusée (droits Supabase)');
      setState(() {
        d['fileName'] = result.files.single.name;
        d['filePath'] = url;
      });
      if (mounted) {
        Ui.snack(context, 'Fichier modifié avec succès',
            Colors.green.shade700);
      }
    } catch (e) {
      debugPrint('Erreur modification fichier rendu : $e');
    }
  }

  Future<void> _deleteDevoirRendu(Map<String, dynamic> d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Supprimer ce devoir rendu ?',
            style: TextStyle(color: Ui.text, fontWeight: FontWeight.w800)),
        content: Text(
            'Le devoir de ${d['studentName'] ?? 'cet élève'} sera supprimé définitivement, ainsi que sa note.',
            style: const TextStyle(color: Ui.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Ui.muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Ui.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
            const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await _supabase
          .from('devoirs_rendus')
          .delete()
          .eq('id', d['id'])
          .select();
      if (res.isEmpty) throw Exception('Suppression refusée (droits Supabase)');
      setState(() => _devoirsRendusList.remove(d));
      if (mounted) {
        Ui.snack(context, 'Devoir rendu supprimé', Ui.danger.withOpacity(0.9));
      }
    } catch (e) {
      debugPrint('Erreur suppression devoir rendu : $e');
    }
  }

  List<Widget> _mesRendusSection() {
    final myId = _supabase.auth.currentUser?.id;
    final mine = _devoirsRendusList.where((d) {
      final dYear = d['year'] ?? _selectedYear;
      final dMonth = d['month'] ?? _selectedMonthIndex;
      return d['studentId'] == myId &&
          dYear == _selectedYear &&
          (_selectedMonthIndex == 0 || dMonth == _selectedMonthIndex);
    }).toList();
    if (mine.isEmpty) return [];

    return [
      const SizedBox(height: 22),
      SectionTitle(
          'Mes devoirs rendus · ${kMonths[_selectedMonthIndex]} $_selectedYear'),
      ...mine.map((d) {
        final note = (d['note'] ?? '').toString();
        final sur = (d['sur'] ?? '20').toString();
        return ItemCard(
          title: 'Envoyé à ${d['destinataireNom'] ?? 'un professeur'}',
          icon: Icons.task_alt_rounded,
          fileName: d['fileName']?.toString(),
          onFile: () => _openPath(d['filePath']),
          footer: Align(
            alignment: Alignment.centerLeft,
            child: note.isEmpty
                ? const Pill('Pas encore noté', Ui.muted,
                icon: Icons.hourglass_empty_rounded)
                : Pill('Note : $note/$sur', Ui.gold, icon: Icons.grade_rounded),
          ),
        );
      }),
    ];
  }

  Future<void> _loadEnseignants() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .inFilter('role', ['Profs', 'Chef d\'église']);
      if (mounted) {
        setState(() {
          _enseignantsList = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement enseignants : $e');
    }
  }

  Map<String, dynamic> _devoirFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'teacherId': r['teacher_id'],
    'titre': r['titre'] ?? '',
    'notes': r['notes'] ?? '',
    'classe': r['classe'] ?? '1ère année',
    'destinataire': r['destinataire'] ?? 'Tous les préseviteurs',
    'destinataireId': r['destinataire_id'],
    'fileName': r['file_name'],
    'filePath': r['file_url'],
    'month': r['month'],
    'year': r['year'],
    'date': r['created_at'],
  };

  Map<String, dynamic> _renduFromRow(Map<String, dynamic> r) => {
    'id': r['id'],
    'studentId': r['student_id'],
    'studentName': r['student_name'],
    'classe': r['classe'],
    'destinataireId': r['destinataire_id'],
    'destinataireNom': r['destinataire_nom'],
    'destinataireRole': r['destinataire_role'],
    'fileName': r['file_name'],
    'filePath': r['file_url'],
    if (r['note'] != null && r['note'].toString().isNotEmpty)
      'note': r['note'],
    if (r['sur'] != null && r['sur'].toString().isNotEmpty)
      'sur': r['sur'],
    'month': r['month'],
    'year': r['year'],
    'date': r['created_at'],
  };

  /// Envoie un fichier local vers Supabase Storage et renvoie son URL publique.
  Future<String?> _uploadDevoirFile(String? localPath, String? name) async {
    if (localPath == null || localPath.isEmpty) return null;
    if (localPath.startsWith('http')) return localPath; // déjà en ligne
    final uid = _supabase.auth.currentUser?.id ?? 'anonyme';
    final safe = (name ?? 'fichier').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _supabase.storage.from('devoirs').upload(path, File(localPath));
    return _supabase.storage.from('devoirs').getPublicUrl(path);
  }

  Future<void> _loadDevoirs() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      var q = _supabase.from('devoirs').select();
      // Un prof ne voit que ses devoirs ; le chef d'église voit tout.
      if (_userRole == 'Profs' && uid != null) {
        q = q.eq('teacher_id', uid);
      }
      final rows = await q.order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _devoirsList = List<Map<String, dynamic>>.from(rows)
              .map(_devoirFromRow)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement devoirs : $e');
    }
  }

  Future<void> _loadDevoirsRendus() async {
    try {
      final rows = await _supabase
          .from('devoirs_rendus')
          .select()
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _devoirsRendusList = List<Map<String, dynamic>>.from(rows)
              .map(_renduFromRow)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement devoirs rendus : $e');
    }
  }

  Future<void> _saveDevoir() async {
    if (_titreController.text.trim().isEmpty) {
      Ui.snack(context, 'Veuillez entrer un titre pour le devoir',
          Ui.surfaceHigh);
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Non connecté');

      final destinataireNom = _selectedPreservant != null
          ? '${_selectedPreservant!['prenom'] ?? ''} ${_selectedPreservant!['nom'] ?? ''}'
          .trim()
          : 'Tous les préseviteurs';

      final fileUrl =
      await _uploadDevoirFile(_selectedFilePath, _selectedFileName);

      final row = {
        'titre': _titreController.text.trim(),
        'notes': _notesController.text.trim(),
        'classe': _selectedClasse,
        'destinataire_id': _selectedPreservant?['id'],
        'destinataire': destinataireNom,
        'file_name': _selectedFileName,
        'file_url': fileUrl,
        'month': _selectedMonthIndex,
        'year': _selectedYear,
      };

      if (_editingIndex != null) {
        final id = _devoirsList[_editingIndex!]['id'];
        final res = await _supabase
            .from('devoirs')
            .update(row)
            .eq('id', id)
            .select();
        if (res.isEmpty) {
          throw Exception('Modification refusée (droits Supabase)');
        }
        _editingIndex = null;
      } else {
        await _supabase.from('devoirs').insert({
          ...row,
          'teacher_id': user.id,
        });
      }

      _titreController.clear();
      _notesController.clear();
      setState(() {
        _selectedPreservant = null;
        _selectedFileName = null;
        _selectedFilePath = null;
      });

      if (mounted) {
        Ui.snack(context, 'Devoir envoyé avec succès !',
            Colors.green.shade700);
      }
      _loadDevoirs();
    } catch (e) {
      debugPrint('Erreur sauvegarde devoir : $e');
      if (mounted) {
        Ui.snack(context, 'Erreur : $e', Colors.red.shade700);
      }
    }
  }

  void _editDevoir(int index, Map<String, dynamic> d) {
    setState(() {
      _editingIndex = index;
      _titreController.text = d['titre'] ?? '';
      _notesController.text = d['notes'] ?? '';
      _selectedClasse = d['classe'] ?? '1ère année';
      _selectedFileName = d['fileName'];
      _selectedFilePath = d['filePath'];
      if (d['month'] != null) _selectedMonthIndex = d['month'];
      if (d['year'] != null) _selectedYear = d['year'];
      final destName = d['destinataire'];
      try {
        _selectedPreservant = _preservantsList.firstWhere(
              (p) => '${p['prenom'] ?? ''} ${p['nom'] ?? ''}' == destName,
        );
      } catch (_) {
        _selectedPreservant = null;
      }
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingIndex = null;
      _titreController.clear();
      _notesController.clear();
      _selectedPreservant = null;
      _selectedFileName = null;
      _selectedFilePath = null;
    });
  }

  Future<void> _deleteDevoir(int index) async {
    try {
      final id = _devoirsList[index]['id'];
      final res =
      await _supabase.from('devoirs').delete().eq('id', id).select();
      if (res.isEmpty) {
        throw Exception('Suppression refusée (droits Supabase)');
      }

      setState(() {
        _devoirsList.removeAt(index);
        if (_editingIndex == index) {
          _editingIndex = null;
          _titreController.clear();
          _notesController.clear();
          _selectedPreservant = null;
          _selectedFileName = null;
          _selectedFilePath = null;
        } else if (_editingIndex != null && _editingIndex! > index) {
          _editingIndex = _editingIndex! - 1;
        }
      });

      if (mounted) {
        Ui.snack(context, 'Devoir supprimé avec succès',
            Ui.danger.withOpacity(0.9));
      }
    } catch (e) {
      debugPrint('Erreur suppression devoir : $e');
      if (mounted) Ui.snack(context, 'Erreur : $e', Colors.red.shade700);
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      debugPrint('Erreur sélection fichier : $e');
    }
  }

  Future<void> _pickStudentFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _studentSelectedFileName = result.files.single.name;
          _studentSelectedFilePath = result.files.single.path;
        });
      }
    } catch (e) {
      debugPrint('Erreur sélection fichier élève : $e');
    }
  }

  Future<void> _submitStudentDevoir() async {
    if (_studentSelectedFileName == null || _studentSelectedFilePath == null) {
      Ui.snack(context, 'Veuillez sélectionner un fichier à rendre',
          Ui.surfaceHigh);
      return;
    }
    if (_selectedEnseignant == null) {
      Ui.snack(context, 'Veuillez choisir le professeur ou le chef d\'église',
          Ui.surfaceHigh);
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Non connecté');

      String studentName = _studentName.isNotEmpty
          ? _studentName
          : (user.userMetadata?['prenom'] ?? 'Élève');
      String studentClasse =
      _studentClasse.isNotEmpty ? _studentClasse : '1ère année';
      try {
        final profile = await _supabase
            .from('profiles')
            .select('prenom, nom, classe')
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          studentName =
              '${profile['prenom'] ?? ''} ${profile['nom'] ?? ''}'.trim();
          studentClasse = _classeOf(profile['classe']);
        }
      } catch (_) {}

      final ens = _selectedEnseignant!;
      final destinataireId = ens['id']?.toString();
      final destinataireNom =
      '${ens['prenom'] ?? ''} ${ens['nom'] ?? ''}'.trim();

      final fileUrl = await _uploadDevoirFile(
          _studentSelectedFilePath, _studentSelectedFileName);

      // Un seul rendu par élève / destinataire / mois : on remplace l'ancien.
      await _supabase
          .from('devoirs_rendus')
          .delete()
          .eq('student_id', user.id)
          .eq('destinataire_id', destinataireId!)
          .eq('month', _selectedMonthIndex)
          .eq('year', _selectedYear);

      await _supabase.from('devoirs_rendus').insert({
        'student_id': user.id,
        'student_name': studentName.isNotEmpty ? studentName : 'Élève',
        'classe': studentClasse,
        'destinataire_id': destinataireId,
        'destinataire_nom': destinataireNom,
        'destinataire_role': ens['role'],
        'file_name': _studentSelectedFileName,
        'file_url': fileUrl,
        'month': _selectedMonthIndex,
        'year': _selectedYear,
      });

      if (mounted) {
        Ui.snack(
            context,
            'Devoir envoyé à $destinataireNom avec succès !',
            Colors.green.shade700);
        setState(() {
          _studentSelectedFileName = null;
          _studentSelectedFilePath = null;
          _selectedEnseignant = null;
        });
      }
      _loadDevoirsRendus();
    } catch (e) {
      debugPrint('Erreur lors de l\'envoi du devoir : $e');
      if (mounted) Ui.snack(context, 'Erreur : $e', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthBar = MonthYearBar(
      month: _selectedMonthIndex,
      year: _selectedYear,
      onMonth: (v) => setState(() => _selectedMonthIndex = v),
      onYear: (v) => setState(() => _selectedYear = v),
    );

    // ------------------------------ PROFS ------------------------------------
    if (_isTeacher(_userRole)) {
      final filteredPreservants = _preservantsList
          .where((p) => _classeOf(p['classe']) == _selectedClasse)
          .toList();

      final filteredDevoirs = _devoirsList.where((d) {
        final dClasse = d['classe'] ?? '1ère année';
        final dYear = d['year'] ?? _selectedYear;
        final dMonth = d['month'] ?? _selectedMonthIndex;
        bool matchClasse = dClasse == _selectedClasse;
        bool matchYear = dYear == _selectedYear;
        bool matchMonth =
            _selectedMonthIndex == 0 || dMonth == _selectedMonthIndex;
        return matchClasse && matchYear && matchMonth;
      }).toList();

      final filteredDevoirsRendus = _devoirsRendusList.where((d) {
        final dYear = d['year'] ?? _selectedYear;
        final dMonth = d['month'] ?? _selectedMonthIndex;
        bool matchClasse = _classeOf(d['classe']) == _selectedClasse;
        bool matchYear = dYear == _selectedYear;
        bool matchMonth =
            _selectedMonthIndex == 0 || dMonth == _selectedMonthIndex;
        // Chaque prof / chef d'église ne voit que les devoirs qui lui sont adressés.
        final myId = _supabase.auth.currentUser?.id;
        final destId = d['destinataireId'];
        bool matchDest = destId == null || destId.toString() == myId;
        return matchClasse && matchYear && matchMonth && matchDest;
      }).toList();

      return PageShell(
        title: 'Devoirs & Travaux',
        subtitle: 'Espace professeurs',
        icon: Icons.assignment_rounded,
        children: [
          SegmentedTabs(
            labels: _classesProfs,
            index: _classesProfs.indexOf(_selectedClasse),
            onChanged: (i) {
              setState(() {
                _selectedClasse = _classesProfs[i];
                _selectedPreservant = null;
              });
              // Recharge la liste : la classe d'un préseviteur a pu changer.
              _loadPreservants();
            },
          ),
          const SizedBox(height: 14),
          monthBar,
          const SizedBox(height: 18),
          GlassCard(
            borderColor: Ui.violet.withOpacity(0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                        _editingIndex != null
                            ? Icons.edit_note_rounded
                            : Icons.send_rounded,
                        color: Ui.gold,
                        size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _editingIndex != null
                            ? 'Modifier le devoir'
                            : 'Envoyer un devoir · $_selectedClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)',
                        style: const TextStyle(
                          color: Ui.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _styledField(_titreController, 'Titre du devoir',
                    Icons.assignment_rounded),
                const SizedBox(height: 12),
                _styledDropdown<Map<String, dynamic>>(
                  label: 'Choisir le préseviteur (optionnel)',
                  icon: Icons.person_rounded,
                  value: _selectedPreservant,
                  items: [
                    const DropdownMenuItem<Map<String, dynamic>>(
                      value: null,
                      child: Text('Tous les préseviteurs de la classe',
                          style: TextStyle(color: Ui.muted)),
                    ),
                    ...filteredPreservants.map((p) {
                      final name = '${p['prenom'] ?? ''} ${p['nom'] ?? ''}';
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: p,
                        child: Text(name),
                      );
                    }),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedPreservant = val),
                ),
                const SizedBox(height: 12),
                _styledField(_notesController, 'Consignes / Description',
                    Icons.note_rounded,
                    maxLines: 3),
                const SizedBox(height: 12),
                SoftButton(
                  onPressed: _pickFile,
                  icon: Icons.attach_file_rounded,
                  label: _selectedFileName ?? 'Joindre un fichier (optionnel)',
                ),
                if (_selectedFileName != null)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _selectedFileName = null;
                      _selectedFilePath = null;
                    }),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Retirer le fichier'),
                    style: TextButton.styleFrom(foregroundColor: Ui.danger),
                  ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: _saveDevoir,
                  icon: Icons.send_rounded,
                  label: _editingIndex != null
                      ? 'Valider les modifications'
                      : 'Envoyer le devoir',
                ),
                if (_editingIndex != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Annuler la modification',
                        style: TextStyle(color: Ui.muted, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
              'Devoirs envoyés · $_selectedClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)'),
          if (filteredDevoirs.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              text: 'Aucun devoir pour cette période.',
            )
          else
            ...filteredDevoirs.map((d) {
              final realIndex = _devoirsList.indexOf(d);
              return ItemCard(
                title: (d['titre'] ?? '').toString(),
                icon: Icons.assignment_rounded,
                byline: 'Destinataire : ${d['destinataire'] ?? 'Tous'}',
                body: (d['notes'] ?? '').toString(),
                fileName: d['fileName']?.toString(),
                onFile: () => _openPath(d['filePath']),
                onEdit: () => _editDevoir(realIndex, d),
                onDelete: () => _deleteDevoir(realIndex),
              );
            }),
          const SizedBox(height: 10),
          SectionTitle(
              'Devoirs rendus · $_selectedClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)'),
          if (filteredDevoirsRendus.isEmpty)
            const EmptyState(
              icon: Icons.inbox_rounded,
              text: 'Aucun devoir rendu par les préséviteurs pour cette période.',
            )
          else
            ...filteredDevoirsRendus.map((d) {
              return ItemCard(
                title: (d['studentName'] ?? 'Élève').toString(),
                icon: Icons.person_rounded,
                byline: 'Classe : ${d['classe'] ?? ''}',
                fileName: (d['fileName'] ?? '').toString(),
                onFile: () => _openPath(d['filePath']),
                onDelete: () => _deleteDevoirRendu(d),
                footer: _noteFooter(d),
              );
            }),
        ],
      );
    }

    // ----------------------------- ÉLÈVES ------------------------------------
    final studentFilteredDevoirs = _devoirsList.where((d) {
      final dClasse = (d['classe'] ?? '').toString().toLowerCase();
      final sClasse = _studentClasse.toLowerCase();
      bool matchClasse = false;
      if (sClasse.contains('1') && dClasse.contains('1')) {
        matchClasse = true;
      } else if (sClasse.contains('2') && dClasse.contains('2')) {
        matchClasse = true;
      } else if (dClasse == _studentClasse) {
        matchClasse = true;
      }

      final dYear = d['year'] ?? _selectedYear;
      final dMonth = d['month'] ?? _selectedMonthIndex;
      bool matchYear = dYear == _selectedYear;
      bool matchMonth =
          _selectedMonthIndex == 0 || dMonth == _selectedMonthIndex;

      final destinataire = d['destinataire'] ?? 'Tous les préseviteurs';
      bool matchDest = destinataire == 'Tous les préseviteurs' ||
          destinataire.toString().toLowerCase() ==
              _studentName.toLowerCase() ||
          _studentName
              .toLowerCase()
              .contains(destinataire.toString().toLowerCase());

      return matchClasse && matchYear && matchMonth && matchDest;
    }).toList();

    return PageShell(
      title: 'Rendre le devoir',
      subtitle: 'Dépose ton travail du mois',
      icon: Icons.upload_file_rounded,
      children: [
        monthBar,
        const SizedBox(height: 18),
        if (studentFilteredDevoirs.isNotEmpty) ...[
          SectionTitle(
              'Devoirs des professeurs · ${kMonths[_selectedMonthIndex]} $_selectedYear'),
          ...studentFilteredDevoirs.map((d) {
            return ItemCard(
              title: (d['titre'] ?? 'Devoir').toString(),
              icon: Icons.assignment_rounded,
              body: (d['notes'] ?? '').toString(),
              fileName: d['fileName']?.toString(),
              onFile: () => _openPath(d['filePath']),
            );
          }),
          const SizedBox(height: 10),
        ],
        GlassCard(
          borderColor: Ui.violet.withOpacity(0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Ui.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded,
                        color: Ui.gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Dépose ou soumets ton travail pour ${kMonths[_selectedMonthIndex]} $_selectedYear.',
                      style: const TextStyle(
                          color: Ui.muted, fontSize: 13.5, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SoftButton(
                onPressed: _pickStudentFile,
                icon: Icons.upload_file_rounded,
                label: 'Sélectionner un fichier à rendre',
              ),
              if (_studentSelectedFileName != null) ...[
                const SizedBox(height: 12),
                FileChip(
                  name: _studentSelectedFileName!,
                  onTap: () => _openPath(_studentSelectedFilePath),
                ),
                const SizedBox(height: 16),
                if (_enseignantsList.isEmpty)
                  const Text(
                    'Aucun professeur ou chef d\'église disponible pour le moment.',
                    style: TextStyle(color: Ui.muted, fontSize: 12.5),
                  )
                else
                  _styledDropdown<Map<String, dynamic>>(
                    label: 'À qui rendre le devoir ?',
                    icon: Icons.person_search_rounded,
                    value: _selectedEnseignant,
                    items: _enseignantsList.map((e) {
                      final name =
                      '${e['prenom'] ?? ''} ${e['nom'] ?? ''}'.trim();
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: e,
                        child: Text('$name · ${e['role'] ?? ''}',
                            softWrap: true),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedEnseignant = val),
                  ),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: _submitStudentDevoir,
                  icon: Icons.check_circle_rounded,
                  label: 'Valider',
                ),
              ],
            ],
          ),
        ),
        ..._mesRendusSection(),
      ],
    );
  }
}

// =============================================================================
// VERSETS
// =============================================================================

/// Profil de l'utilisateur connecté : la table profiles fait foi (elle est
/// mise à jour quand un chef modifie un préseviteur) ; les métadonnées de
/// session ne servent qu'en secours.
Future<Map<String, dynamic>> _currentProfile() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return {};
  final meta = Map<String, dynamic>.from(user.userMetadata ?? {});
  try {
    final profile = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (profile != null) {
      final merged = Map<String, dynamic>.from(meta);
      profile.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) merged[k] = v;
      });
      return merged;
    }
  } catch (_) {}
  return meta;
}

/// Ramène n'importe quelle écriture de classe à l'une des deux classes.
String _classeOf(Object? value) {
  final s = (value ?? '').toString().toLowerCase();
  return s.contains('2') ? '2ème année' : '1ère année';
}

class VersetsPage extends StatefulWidget {
  const VersetsPage({super.key});

  @override
  State<VersetsPage> createState() => _VersetsPageState();
}

class _VersetsPageState extends State<VersetsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _userRole = '';
  String _userId = '';
  String _userName = '';
  String _studentClasse = '1ère année';

  final TextEditingController _titreController = TextEditingController();
  final TextEditingController _chapitreController = TextEditingController();
  final TextEditingController _versetController = TextEditingController();
  final TextEditingController _numeroVersetController = TextEditingController();

  String _selectedClasse = '1ère année';
  final List<String> _classesProfs = ['1ère année', '2ème année'];

  late int _selectedMonthIndex;
  late int _selectedYear;

  List<Map<String, dynamic>> _versets = [];
  bool _isLoading = false;
  String? _editingId;

  bool get _isChef => _userRole == 'Chef d\'église';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonthIndex = now.month;
    _selectedYear =
    now.year < 2026 ? 2026 : (now.year > 2099 ? 2099 : now.year);
    _init();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _chapitreController.dispose();
    _versetController.dispose();
    _numeroVersetController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final me = await _currentProfile();
    final user = _supabase.auth.currentUser;
    if (mounted) {
      setState(() {
        _userId = user?.id ?? '';
        _userRole = (me['role'] ?? '').toString();
        _userName = '${me['prenom'] ?? ''} ${me['nom'] ?? ''}'.trim();
        _studentClasse = _classeOf(me['classe']);
      });
    }
    await _loadVersets();
  }

  /// Tous les versets sont partagés : chaque rôle voit ceux des profs et du chef.
  Future<void> _loadVersets() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('versets')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _versets = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement versets : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _titreController.clear();
      _chapitreController.clear();
      _versetController.clear();
      _numeroVersetController.clear();
    });
  }

  Future<void> _saveVerset() async {
    if (_titreController.text.trim().isEmpty ||
        _versetController.text.trim().isEmpty) {
      Ui.snack(context, 'Veuillez remplir au moins le titre et le verset',
          Ui.surfaceHigh);
      return;
    }

    final wasEditing = _editingId != null;
    final payload = {
      'titre': _titreController.text.trim(),
      'chapitre': _chapitreController.text.trim(),
      'numero': _numeroVersetController.text.trim(),
      'verset': _versetController.text.trim(),
      'classe': _selectedClasse,
      'month': _selectedMonthIndex,
      'year': _selectedYear,
    };

    try {
      if (wasEditing) {
        await _supabase.from('versets').update(payload).eq('id', _editingId!);
      } else {
        await _supabase.from('versets').insert({
          ...payload,
          'author_id': _userId,
          'author_name': _userName,
        });
      }
      _clearForm();
      if (mounted) {
        Ui.snack(
            context,
            wasEditing ? 'Verset modifié avec succès !' : 'Verset enregistré avec succès !',
            Colors.green.shade700);
      }
      await _loadVersets();
    } catch (e) {
      debugPrint('Erreur sauvegarde verset : $e');
      if (mounted) {
        Ui.snack(context, 'Erreur lors de l\'enregistrement du verset',
            Ui.danger.withOpacity(0.9));
      }
    }
  }

  void _editVerset(Map<String, dynamic> v) {
    setState(() {
      _editingId = v['id'].toString();
      _titreController.text = (v['titre'] ?? '').toString();
      _chapitreController.text = (v['chapitre'] ?? '').toString();
      _versetController.text = (v['verset'] ?? '').toString();
      _numeroVersetController.text = (v['numero'] ?? '').toString();
      _selectedClasse = _classeOf(v['classe']);
      _selectedMonthIndex =
          int.tryParse('${v['month']}') ?? _selectedMonthIndex;
      _selectedYear = int.tryParse('${v['year']}') ?? _selectedYear;
    });
  }

  void _cancelEdit() => _clearForm();

  Future<void> _deleteVerset(Map<String, dynamic> v) async {
    try {
      await _supabase.from('versets').delete().eq('id', v['id']);
      if (_editingId == v['id'].toString()) _clearForm();
      await _loadVersets();
      if (mounted) {
        Ui.snack(context, 'Verset supprimé avec succès',
            Ui.danger.withOpacity(0.9));
      }
    } catch (e) {
      debugPrint('Erreur suppression verset : $e');
    }
  }

  bool _matchesPeriod(Map<String, dynamic> v) {
    final month = int.tryParse('${v['month']}') ?? 0;
    final year = int.tryParse('${v['year']}') ?? _selectedYear;
    return year == _selectedYear &&
        (_selectedMonthIndex == 0 || month == _selectedMonthIndex);
  }

  String _reference(Map<String, dynamic> v) {
    final chapitre = (v['chapitre'] ?? '').toString();
    final numero = (v['numero'] ?? '').toString();
    if (chapitre.isEmpty && numero.isEmpty) return '';
    return '$chapitre${numero.isNotEmpty ? '\n$numero' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final monthBar = MonthYearBar(
      month: _selectedMonthIndex,
      year: _selectedYear,
      onMonth: (v) => setState(() => _selectedMonthIndex = v),
      onYear: (v) => setState(() => _selectedYear = v),
    );

    // ------------------------------ PROFS & CHEF ------------------------------
    if (_isTeacher(_userRole)) {
      final filteredVersets = _versets
          .where((v) => _classeOf(v['classe']) == _selectedClasse && _matchesPeriod(v))
          .toList();

      return PageShell(
        title: 'Versets',
        subtitle: 'Gestion des versets · ${_isChef ? 'Chef d\'église' : 'Profs'}',
        icon: Icons.format_quote_rounded,
        children: [
          SegmentedTabs(
            labels: _classesProfs,
            index: _classesProfs.indexOf(_selectedClasse),
            onChanged: (i) => setState(() {
              _selectedClasse = _classesProfs[i];
              _cancelEdit();
            }),
          ),
          const SizedBox(height: 14),
          monthBar,
          const SizedBox(height: 18),
          GlassCard(
            borderColor: Ui.violet.withOpacity(0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                        _editingId != null
                            ? Icons.edit_note_rounded
                            : Icons.auto_stories_rounded,
                        color: Ui.gold,
                        size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _editingId != null
                            ? 'Modifier le verset'
                            : 'Nouveau verset · $_selectedClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)',
                        style: const TextStyle(
                          color: Ui.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _styledField(_titreController, 'Titre', Icons.title_rounded),
                const SizedBox(height: 12),
                _styledField(_chapitreController, 'Chapitre',
                    Icons.bookmark_rounded),
                const SizedBox(height: 12),
                _styledField(_versetController, 'Texte du verset',
                    Icons.format_quote_rounded,
                    maxLines: 4),
                const SizedBox(height: 12),
                _styledField(_numeroVersetController, 'N° verset en entier',
                    Icons.format_list_numbered_rounded,
                    keyboardType: TextInputType.multiline, maxLines: null),
                const SizedBox(height: 16),
                GradientButton(
                  onPressed: _saveVerset,
                  icon: Icons.check_rounded,
                  label: _editingId != null
                      ? 'Valider les modifications'
                      : 'Valider et publier',
                ),
                if (_editingId != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _cancelEdit,
                    child: const Text('Annuler la modification',
                        style: TextStyle(color: Ui.muted, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(
              'Versets enregistrés · $_selectedClasse (${kMonths[_selectedMonthIndex]} $_selectedYear)'),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator(color: Ui.violet)),
            )
          else if (filteredVersets.isEmpty)
            const EmptyState(
              icon: Icons.format_quote_rounded,
              text: 'Aucun verset enregistré pour cette période.',
            )
          else
            ...filteredVersets.map((v) {
              final mine = v['author_id'] == _userId;
              final author = (v['author_name'] ?? '').toString();
              return VersetCard(
                titre: (v['titre'] ?? '').toString(),
                byline: mine
                    ? 'Publié par vous'
                    : (author.isNotEmpty ? 'Publié par $author' : null),
                reference: _reference(v),
                verset: '"${v['verset'] ?? ''}"',
                onEdit: mine ? () => _editVerset(v) : null,
                onDelete: mine ? () => _deleteVerset(v) : null,
              );
            }),
        ],
      );
    }

    // ----------------------------- ÉLÈVES ------------------------------------
    final studentFilteredVersets = _versets
        .where((v) => _classeOf(v['classe']) == _studentClasse && _matchesPeriod(v))
        .toList();

    return PageShell(
      title: 'Versets du mois',
      subtitle: 'Médite et mémorise',
      icon: Icons.format_quote_rounded,
      children: [
        monthBar,
        const SizedBox(height: 18),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(color: Ui.violet)),
          )
        else if (studentFilteredVersets.isEmpty)
          const EmptyState(
            icon: Icons.format_quote_rounded,
            text: 'Aucun verset disponible pour cette période.',
          )
        else
          ...studentFilteredVersets.map((v) {
            final author = (v['author_name'] ?? '').toString();
            return VersetCard(
              titre: (v['titre'] ?? '').toString(),
              byline: author.isNotEmpty ? 'Publié par $author' : null,
              reference: _reference(v),
              verset: '"${v['verset'] ?? ''}"',
            );
          }),
      ],
    );
  }
}

// =============================================================================
// =============================================================================
// PARAMÈTRES & PROFIL
// =============================================================================

class ParametresPage extends ConsumerStatefulWidget {
  const ParametresPage({super.key});

  @override
  ConsumerState<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends ConsumerState<ParametresPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _villeController = TextEditingController();
  final TextEditingController _codePostalController = TextEditingController();
  final TextEditingController _autrePereController = TextEditingController();

  String? _pereConfesseur;
  String? _classe;
  File? _selectedImage;
  String? _currentPhotoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _userRole;

  final List<String> _classesList = ['1ere année', '2eme année'];
  final List<String> _profsClassesList = ['1ère et 2ème année'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _codePostalController.dispose();
    _autrePereController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        final meta = user.userMetadata ?? {};

        if (profile != null) {
          _nomController.text = profile['nom'] ?? meta['nom'] ?? '';
          _prenomController.text = profile['prenom'] ?? meta['prenom'] ?? '';
          _telephoneController.text =
              profile['telephone'] ?? meta['telephone'] ?? '';
          _adresseController.text = profile['adresse'] ?? meta['adresse'] ?? '';
          _villeController.text = profile['ville'] ?? meta['ville'] ?? '';
          _codePostalController.text =
              profile['code_postal'] ?? meta['code_postal'] ?? '';

          _userRole = profile['role'] ?? meta['role'];

          final pere = profile['pere_confesseur'] ?? meta['pere_confesseur'];
          if (kAbounas.contains(pere)) {
            _pereConfesseur = pere;
          } else if (pere != null && pere.toString().isNotEmpty) {
            _pereConfesseur = 'Autre';
            _autrePereController.text = pere;
          }

          final c = profile['classe'] ?? meta['classe'];
          if (_isTeacher(_userRole ?? '')) {
            if (_profsClassesList.contains(c)) {
              _classe = c;
            } else {
              _classe = '1ère et 2ème année';
            }
          } else {
            if (_classesList.contains(c)) {
              _classe = c;
            }
          }

          final profilePhoto = profile['photo_url']?.toString();
          final metaPhoto = meta['photo_url']?.toString();
          _currentPhotoUrl = (profilePhoto != null && profilePhoto.isNotEmpty)
              ? profilePhoto
              : metaPhoto;
          if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
            ref
                .read(userAvatarProvider.notifier)
                .updateAvatar(_currentPhotoUrl!);
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement profil : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _currentPhotoUrl = pickedFile.path;
        });
        ref.read(userAvatarProvider.notifier).updateAvatar(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Erreur sélection image : $e');
    }
  }

  Future<String?> _uploadImageToSupabase(String prenom) async {
    if (_selectedImage != null) {
      try {
        final cleanPrenom =
        prenom.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        final fileName =
            '${cleanPrenom}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await _selectedImage!.readAsBytes();

        String bucketName = 'photos';
        try {
          await _supabase.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions:
            const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
        } catch (_) {
          bucketName = 'avatars';
          await _supabase.storage.from(bucketName).uploadBinary(
            fileName,
            bytes,
            fileOptions:
            const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
        }

        final imageUrl =
        _supabase.storage.from(bucketName).getPublicUrl(fileName);
        return imageUrl;
      } catch (e) {
        debugPrint('Erreur upload image: $e');
      }
    }
    return _currentPhotoUrl;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final prenom = _prenomController.text.trim();
      final nom = _nomController.text.trim();
      final telephone = _telephoneController.text.trim();
      final adresse = _adresseController.text.trim();
      final ville = _villeController.text.trim();
      final codePostal = _codePostalController.text.trim();
      final pereConfesseur = _pereConfesseur == 'Autre'
          ? _autrePereController.text.trim()
          : _pereConfesseur;

      final String? uploaded = await _uploadImageToSupabase(prenom);
      // Jamais de chemin local en base : seule une vraie URL est enregistrée.
      final String? photoUrl =
      (uploaded != null && uploaded.startsWith('http')) ? uploaded : null;
      final bool photoNotSent = _selectedImage != null && photoUrl == null;

      final isChef = _userRole == 'Chef d\'église';

      final updateData = <String, dynamic>{
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        if (!isChef) ...{
          'adresse': adresse,
          'ville': ville,
          'code_postal': codePostal,
          'pere_confesseur': pereConfesseur ?? '',
        },
        // On n'écrase jamais une photo existante par une valeur vide.
        if (photoUrl != null) 'photo_url': photoUrl,
      };

      await _supabase.from('profiles').update(updateData).eq('id', user.id);

      await _supabase.auth.updateUser(
        UserAttributes(data: updateData),
      );

      if (photoUrl != null) {
        ref.read(userAvatarProvider.notifier).updateAvatar(photoUrl);
      }

      if (mounted) {
        if (photoNotSent) {
          Ui.snack(
              context,
              'Profil mis à jour, mais la photo n\'a pas pu être envoyée.',
              Colors.orange.shade800);
        } else {
          Ui.snack(context, 'Profil mis à jour avec succès !',
              Colors.green.shade700);
        }
        ref.read(navigationIndexProvider.notifier).setIndex(0);
      }
    } catch (e) {
      if (mounted) {
        Ui.snack(
            context, 'Erreur lors de la mise à jour : $e', Colors.red.shade700);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ImageProvider? _avatarImage() {
    if (_selectedImage != null) return FileImage(_selectedImage!);
    return _imageFromUrl(_currentPhotoUrl);
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Ui.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              _sheetOption(
                  Icons.photo_library_rounded, 'Choisir dans la galerie', () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              }),
              const SizedBox(height: 10),
              _sheetOption(Icons.camera_alt_rounded, 'Prendre une photo', () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Ui.violet.withOpacity(0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Ui.violetSoft, size: 20),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Ui.text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _required(
      TextEditingController c,
      String label,
      IconData icon, {
        TextInputType? keyboardType,
        List<TextInputFormatter>? formatters,
      }) {
    return _styledField(
      c,
      label,
      icon,
      keyboardType: keyboardType,
      formatters: formatters,
      validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentClassesOptions = _isTeacher(_userRole ?? '')
        ? _profsClassesList
        : _classesList;
    final classeAffichee = _classe ??
        (currentClassesOptions.length == 1
            ? currentClassesOptions.first
            : null);
    // Le chef d'église n'a ni adresse, ni confesseur, ni classe à renseigner.
    final isChef = _userRole == 'Chef d\'église';

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: Ui.violet)),
      );
    }

    return PageShell(
      title: 'Paramètres & Profil',
      subtitle: 'Gère tes informations',
      icon: Icons.settings_rounded,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isChef ? null : classeAffichee),
              const SizedBox(height: 24),
              _section(
                title: 'Informations personnelles',
                icon: Icons.person_rounded,
                children: [
                  _required(_nomController, 'Nom', Icons.badge_rounded),
                  _required(_prenomController, 'Prénom',
                      Icons.person_outline_rounded),
                  _required(_telephoneController, 'Numéro de téléphone',
                      Icons.phone_rounded,
                      keyboardType: TextInputType.phone),
                ],
              ),
              if (!isChef) ...[
                const SizedBox(height: 16),
                _section(
                  title: 'Adresse',
                  icon: Icons.home_rounded,
                  children: [
                    _required(
                        _adresseController, 'Adresse', Icons.home_outlined),
                    _required(_villeController, 'Ville',
                        Icons.location_city_rounded),
                    _required(_codePostalController, 'Code postal',
                        Icons.pin_drop_rounded,
                        keyboardType: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly]),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Confesseur et classe',
                  icon: Icons.church_rounded,
                  children: [
                    _styledDropdown<String>(
                      label: 'Abouna confesseur',
                      icon: Icons.church_rounded,
                      value: _pereConfesseur,
                      items: kAbounas
                          .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a, softWrap: true)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _pereConfesseur = val),
                      validator: (val) => val == null ? 'Requis' : null,
                    ),
                    if (_pereConfesseur == 'Autre')
                      _styledField(_autrePereController,
                          'Précisez le nom d\'Abouna', Icons.edit_rounded,
                          validator: (val) => _pereConfesseur == 'Autre' &&
                              (val == null || val.trim().isEmpty)
                              ? 'Requis'
                              : null),
                    _lockedField(
                      label: 'Classe',
                      value: classeAffichee ?? 'Non renseignée',
                      icon: Icons.school_rounded,
                      helper:
                      'Votre classe est modifiable par un prof ou un chef d\'église.',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              GradientButton(
                label: 'Enregistrer les modifications',
                icon: Icons.check_rounded,
                loading: _isSaving,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String? classeAffichee) {
    final hasRole = _userRole != null && _userRole!.isNotEmpty;
    final avatar = _avatarImage();

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImageSourceDialog,
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: Ui.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Ui.violet.withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Ui.surfaceHigh,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(Icons.person_rounded,
                        color: Ui.muted, size: 48)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: Ui.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Ui.surface, width: 2.5),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Changer la photo',
            style: TextStyle(
              color: Ui.violetSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: Listenable.merge([_prenomController, _nomController]),
            builder: (context, _) {
              final fullName =
              '${_prenomController.text.trim()} ${_nomController.text.trim()}'
                  .trim();
              return Text(
                fullName.isEmpty ? 'Votre profil' : fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Ui.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasRole) Pill(_userRole!, Ui.gold, icon: Icons.verified_rounded),
              if (classeAffichee != null)
                Pill(classeAffichee, Ui.violetSoft, icon: Icons.school_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final spaced = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) spaced.add(const SizedBox(height: 12));
      spaced.add(children[i]);
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Ui.violet.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Ui.violetSoft, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Ui.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...spaced,
        ],
      ),
    );
  }

  Widget _lockedField({
    required String label,
    required String value,
    required IconData icon,
    required String helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Ui.muted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Ui.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      softWrap: true,
                      style: TextStyle(
                        color: Ui.text.withOpacity(0.85),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.lock_rounded, color: Ui.muted, size: 18),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            helper,
            style: const TextStyle(
              color: Ui.muted,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}


// =============================================================================
// GESTION ABSENCE (Profs + Chef d'église)
// =============================================================================

const List<String> kMonthsShort = [
  'Jan',
  'Fév',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aoû',
  'Sep',
  'Oct',
  'Nov',
  'Déc',
];

const List<String> kWeekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Date au format ISO `yyyy-MM-dd` (format de la colonne `date` de Supabase).
String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

/// Ex. : « Dimanche 16 novembre 2026 ».
String _frDate(DateTime d) =>
    '${kWeekdays[d.weekday - 1]} ${d.day} ${kMonths[d.month].toLowerCase()} ${d.year}';

/// Transforme un numéro saisi dans l'app en numéro utilisable par wa.me
/// (chiffres uniquement, avec l'indicatif pays, sans « + »).
String _whatsappNumber(String raw) {
  var n = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (n.isEmpty) return '';
  if (n.startsWith('+')) {
    n = n.substring(1);
  } else if (n.startsWith('00')) {
    n = n.substring(2);
  } else if (n.startsWith('0')) {
    n = '33${n.substring(1)}';
  }
  if (n.startsWith('330')) n = '33${n.substring(3)}';
  return n.length < 8 ? '' : n;
}

class GestionAbsencePage extends StatefulWidget {
  final String role;
  const GestionAbsencePage({super.key, required this.role});

  @override
  State<GestionAbsencePage> createState() => _GestionAbsencePageState();
}

class _GestionAbsencePageState extends State<GestionAbsencePage> {
  static const List<String> _classes = ['1ère année', '2ème année'];
  static const Color _whatsappGreen = Color(0xFF25D366);

  final SupabaseClient _supabase = Supabase.instance.client;

  int _classeIndex = 0;
  late DateTime _date;
  late int _bilanMonth;
  late int _bilanYear;

  bool _loadingStudents = true;
  bool _loadingDay = true;
  bool _loadingBilan = true;
  String? _busyId;

  List<Map<String, dynamic>> _students = [];
  Map<String, Map<String, dynamic>> _dayRecords = {};
  List<Map<String, dynamic>> _yearRecords = [];

  bool get _isChef => widget.role == 'Chef d\'église';
  String get _prevenir => _isChef ? 'les Profs' : 'le Chef d\'église';
  String get _classe => _classes[_classeIndex];
  String get _isoSelected => _isoDate(_date);

  List<Map<String, dynamic>> get _studentsOfClass =>
      _students.where((s) => _classeOf(s['classe']) == _classe).toList();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final y = now.year < 2026 ? 2026 : (now.year > 2099 ? 2099 : now.year);
    _date = now.year == y ? DateTime(now.year, now.month, now.day) : DateTime(y, 1, 1);
    _bilanMonth = now.month;
    _bilanYear = y;
    preservantsRevision.addListener(_loadStudents);
    _loadStudents();
    _loadDay();
    _loadBilan();
  }

  @override
  void dispose() {
    preservantsRevision.removeListener(_loadStudents);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Chargement des données
  // ---------------------------------------------------------------------------

  void _error(String message) => Ui.snack(context, message, Ui.danger);

  static const String _tableHint =
      'Chargement impossible. Vérifiez que la table « absences » existe dans Supabase.';

  Future<void> _loadStudents() async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'Préseviteur')
          .order('prenom');
      if (!mounted) return;
      setState(() => _students = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Erreur chargement préséviteurs (absences) : $e');
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _loadDay({bool silent = false}) async {
    if (!silent) setState(() => _loadingDay = true);
    final wanted = _isoSelected;
    try {
      final res = await _supabase.from('absences').select().eq('date', wanted);
      if (!mounted || wanted != _isoSelected) return;
      final map = <String, Map<String, dynamic>>{};
      for (final r in List<Map<String, dynamic>>.from(res)) {
        map['${r['preservant_id']}'] = r;
      }
      setState(() => _dayRecords = map);
    } catch (e) {
      debugPrint('Erreur chargement absences du jour : $e');
      if (mounted) _error(_tableHint);
    } finally {
      if (mounted && wanted == _isoSelected) {
        setState(() => _loadingDay = false);
      }
    }
  }

  Future<void> _loadBilan({bool silent = false}) async {
    if (!silent) setState(() => _loadingBilan = true);
    final classe = _classe;
    final year = _bilanYear;
    try {
      final res = await _supabase
          .from('absences')
          .select()
          .eq('classe', classe)
          .gte('date', '$year-01-01')
          .lte('date', '$year-12-31');
      if (!mounted || classe != _classe || year != _bilanYear) return;
      setState(() => _yearRecords = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint('Erreur chargement bilan absences : $e');
    } finally {
      if (mounted && classe == _classe && year == _bilanYear) {
        setState(() => _loadingBilan = false);
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStudents(), _loadDay(), _loadBilan()]);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _changeClasse(int i) {
    if (i == _classeIndex) return;
    setState(() {
      _classeIndex = i;
      _yearRecords = [];
    });
    _loadBilan();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2026, 1, 1),
      lastDate: DateTime(2099, 12, 31),
      helpText: 'Choisir la date',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _dayRecords = {};
    });
    _loadDay();
  }

  String _nameOf(Map<String, dynamic> s) =>
      '${s['prenom'] ?? ''} ${s['nom'] ?? ''}'.trim();

  Future<String?> _askMotif({
    required String title,
    required String name,
    String initial = '',
  }) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          title,
          style: const TextStyle(
              color: Ui.text, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Ui.gold,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Ui.text),
                decoration: Ui.input('Motif de l\'absence', Icons.edit_note_rounded,
                    multiline: true),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_rounded, color: Ui.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cas grave (maladie sérieuse, deuil…) ? '
                          'Pensez à prévenir $_prevenir.',
                      style: const TextStyle(
                          color: Ui.gold, fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Ui.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Enregistrer',
                style: TextStyle(
                    color: Ui.violetSoft, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Ui.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title,
            style: const TextStyle(
                color: Ui.text, fontSize: 18, fontWeight: FontWeight.w800)),
        content: Text(message, style: const TextStyle(color: Ui.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Ui.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style:
                TextStyle(color: Ui.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Touche « Présent » / « Absent ». Un second appui sur le statut déjà
  /// choisi efface la saisie.
  Future<void> _onStatut(Map<String, dynamic> s, String statut) async {
    final id = '${s['id']}';
    final current = _dayRecords[id];

    if (current != null && current['statut'] == statut) {
      await _clearStatut(id);
      return;
    }

    String? motif;
    if (statut == 'absent') {
      final answer = await _askMotif(
        title: 'Marquer absent(e)',
        name: _nameOf(s),
      );
      if (answer == null) return; // annulé
      motif = answer.isEmpty ? null : answer;
    }
    await _saveStatut(s, statut, motif);
  }

  Future<void> _saveStatut(
      Map<String, dynamic> s, String statut, String? motif) async {
    final id = '${s['id']}';
    setState(() => _busyId = id);
    try {
      final row = await _supabase
          .from('absences')
          .upsert({
        'preservant_id': id,
        'date': _isoSelected,
        'statut': statut,
        'motif': statut == 'absent' ? motif : null,
        'classe': _classe,
      }, onConflict: 'preservant_id,date')
          .select()
          .single();
      if (!mounted) return;
      setState(() => _dayRecords[id] = Map<String, dynamic>.from(row));
      _loadBilan(silent: true);
    } catch (e) {
      debugPrint('Erreur enregistrement absence : $e');
      if (mounted) _error('Enregistrement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _clearStatut(String id) async {
    setState(() => _busyId = id);
    try {
      await _supabase
          .from('absences')
          .delete()
          .eq('preservant_id', id)
          .eq('date', _isoSelected);
      if (!mounted) return;
      setState(() => _dayRecords.remove(id));
      _loadBilan(silent: true);
    } catch (e) {
      debugPrint('Erreur suppression absence : $e');
      if (mounted) _error('Suppression impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _updateMotif(String id, String? motif) async {
    setState(() => _busyId = id);
    try {
      await _supabase
          .from('absences')
          .update({'motif': motif})
          .eq('preservant_id', id)
          .eq('date', _isoSelected);
      if (!mounted) return;
      setState(() {
        final rec = Map<String, dynamic>.from(_dayRecords[id] ?? {});
        rec['motif'] = motif;
        _dayRecords[id] = rec;
      });
    } catch (e) {
      debugPrint('Erreur modification motif : $e');
      if (mounted) _error('Modification impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _editMotif(Map<String, dynamic> s) async {
    final id = '${s['id']}';
    final initial = (_dayRecords[id]?['motif'] ?? '').toString();
    final answer = await _askMotif(
      title: initial.isEmpty ? 'Ajouter un motif' : 'Modifier le motif',
      name: _nameOf(s),
      initial: initial,
    );
    if (answer == null) return;
    await _updateMotif(id, answer.isEmpty ? null : answer);
  }

  Future<void> _deleteMotif(Map<String, dynamic> s) async {
    final ok = await _confirm(
        'Supprimer le motif ?', 'Le motif de ${_nameOf(s)} sera effacé.');
    if (!ok) return;
    await _updateMotif('${s['id']}', null);
  }

  Future<void> _openWhatsapp(Map<String, dynamic> s) async {
    final number = _whatsappNumber('${s['telephone'] ?? s['phone'] ?? ''}');
    if (number.isEmpty) {
      Ui.snack(context, 'Aucun numéro de téléphone valide pour ${_nameOf(s)}.',
          Ui.danger);
      return;
    }
    final motif = (_dayRecords['${s['id']}']?['motif'] ?? '').toString().trim();
    final prenom = (s['prenom'] ?? '').toString().trim();
    final message = 'Bonjour $prenom, tu étais absent(e) le ${_frDate(_date)}.'
        '${motif.isNotEmpty ? ' ($motif)' : ''} '
        'On pense à toi, j\'espère que tout va bien ! 🙏';
    final uri =
    Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        Ui.snack(context, 'Impossible d\'ouvrir WhatsApp.', Ui.danger);
      }
    } catch (e) {
      debugPrint('Erreur ouverture WhatsApp : $e');
      if (mounted) Ui.snack(context, 'Impossible d\'ouvrir WhatsApp.', Ui.danger);
    }
  }

  // ---------------------------------------------------------------------------
  // Widgets
  // ---------------------------------------------------------------------------

  Widget _notice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Ui.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Ui.gold.withOpacity(0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Ui.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'En cas d\'absence grave (maladie sérieuse, hospitalisation, '
                  'deuil, absences répétées), pensez à prévenir $_prevenir.',
              style: const TextStyle(
                  color: Ui.gold,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateCard() {
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    return GlassCard(
      onTap: _pickDate,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Ui.violet.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_rounded,
                color: Ui.violetSoft, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date de la séance',
                    style: TextStyle(color: Ui.muted, fontSize: 12)),
                const SizedBox(height: 3),
                Text(
                  _frDate(_date),
                  style: const TextStyle(
                      color: Ui.text,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (isToday)
            const Pill('Aujourd\'hui', Ui.success)
          else
            const Icon(Icons.edit_calendar_rounded,
                color: Ui.violetSoft, size: 22),
        ],
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.22) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Colors.white.withOpacity(0.10),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? color : Ui.muted, size: 19),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Ui.muted,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _studentTile(Map<String, dynamic> s) {
    final id = '${s['id']}';
    final rec = _dayRecords[id];
    final isPresent = rec?['statut'] == 'present';
    final isAbsent = rec?['statut'] == 'absent';
    final motif = (rec?['motif'] ?? '').toString().trim();
    final busy = _busyId == id;
    final photo = _imageFromUrl(s['photo_url']?.toString());
    final phone = (s['telephone'] ?? s['phone'] ?? '').toString().trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        borderColor: isAbsent
            ? Ui.danger.withOpacity(0.45)
            : (isPresent ? Ui.success.withOpacity(0.40) : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Ui.surfaceHigh,
                  backgroundImage: photo,
                  child: photo == null
                      ? const Icon(Icons.person_rounded, color: Ui.muted)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameOf(s),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Ui.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700),
                      ),
                      if (phone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(phone,
                              style: const TextStyle(
                                  color: Ui.muted, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Ui.violet),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statusButton(
                    label: 'Présent',
                    icon: Icons.check_circle_rounded,
                    color: Ui.success,
                    selected: isPresent,
                    onTap: busy ? null : () => _onStatut(s, 'present'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statusButton(
                    label: 'Absent',
                    icon: Icons.cancel_rounded,
                    color: Ui.danger,
                    selected: isAbsent,
                    onTap: busy ? null : () => _onStatut(s, 'absent'),
                  ),
                ),
              ],
            ),
            if (isAbsent) ...[
              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 12),
              if (motif.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.notes_rounded,
                          color: Ui.violetSoft, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        motif,
                        style: TextStyle(
                          color: Ui.text.withOpacity(0.85),
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MiniAction(
                        icon: Icons.edit_rounded,
                        color: Ui.info,
                        tooltip: 'Modifier le motif',
                        onTap: () => _editMotif(s)),
                    const SizedBox(width: 6),
                    MiniAction(
                        icon: Icons.delete_rounded,
                        color: Ui.danger,
                        tooltip: 'Supprimer le motif',
                        onTap: () => _deleteMotif(s)),
                  ],
                )
              else
                Row(
                  children: [
                    const Expanded(
                      child: Text('Aucun motif renseigné',
                          style: TextStyle(color: Ui.muted, fontSize: 13)),
                    ),
                    TextButton.icon(
                      onPressed: () => _editMotif(s),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Ajouter un motif'),
                      style: TextButton.styleFrom(
                          foregroundColor: Ui.violetSoft),
                    ),
                  ],
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openWhatsapp(s),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: const Text('Écrire sur WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _whatsappGreen,
                    backgroundColor: _whatsappGreen.withOpacity(0.10),
                    side: BorderSide(color: _whatsappGreen.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ----- Bilan ---------------------------------------------------------------

  Widget _cell(String text,
      {int flex = 1,
        Color color = Ui.text,
        bool bold = false,
        TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Ui.muted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Ui.muted, fontSize: 12)),
      ],
    );
  }

  Widget _ratioBar(int present, int absent) {
    final total = present + absent;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 7,
        child: total == 0
            ? Container(color: Colors.white.withOpacity(0.08))
            : Row(
          children: [
            if (present > 0)
              Expanded(
                  flex: present, child: Container(color: Ui.success)),
            if (absent > 0)
              Expanded(flex: absent, child: Container(color: Ui.danger)),
          ],
        ),
      ),
    );
  }

  List<Widget> _bilanSection(List<Map<String, dynamic>> students) {
    final monthP = List<int>.filled(12, 0);
    final monthA = List<int>.filled(12, 0);
    final perP = <String, int>{};
    final perA = <String, int>{};
    int totalP = 0;
    int totalA = 0;

    for (final r in _yearRecords) {
      final d = (r['date'] ?? '').toString();
      if (d.length < 10) continue;
      final m = int.tryParse(d.substring(5, 7)) ?? 0;
      if (m < 1 || m > 12) continue;
      final isAbs = r['statut'] == 'absent';
      if (isAbs) {
        monthA[m - 1]++;
      } else {
        monthP[m - 1]++;
      }
      if (_bilanMonth == 0 || _bilanMonth == m) {
        final id = '${r['preservant_id']}';
        if (isAbs) {
          perA[id] = (perA[id] ?? 0) + 1;
          totalA++;
        } else {
          perP[id] = (perP[id] ?? 0) + 1;
          totalP++;
        }
      }
    }

    final total = totalP + totalA;
    final rate = total == 0 ? 0 : (totalP * 100 / total).round();
    final monthsWithData = [
      for (int i = 0; i < 12; i++)
        if (monthP[i] + monthA[i] > 0) i
    ];
    final yearP = monthP.fold<int>(0, (a, b) => a + b);
    final yearA = monthA.fold<int>(0, (a, b) => a + b);

    return [
      SectionTitle('Bilan · ${kMonths[_bilanMonth]} $_bilanYear'),
      MonthYearBar(
        month: _bilanMonth,
        year: _bilanYear,
        onMonth: (v) => setState(() => _bilanMonth = v),
        onYear: (v) {
          setState(() {
            _bilanYear = v;
            _yearRecords = [];
          });
          _loadBilan();
        },
      ),
      const SizedBox(height: 14),
      if (_loadingBilan)
        const Padding(
          padding: EdgeInsets.all(28),
          child: Center(child: CircularProgressIndicator(color: Ui.violet)),
        )
      else ...[
        Row(
          children: [
            _statBox('Présents', '$totalP', Ui.success),
            const SizedBox(width: 10),
            _statBox('Absents', '$totalA', Ui.danger),
            const SizedBox(width: 10),
            _statBox('Présence', '$rate %', Ui.info),
          ],
        ),
        const SizedBox(height: 14),

        // Graphique par mois
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Présents / absents par mois · $_bilanYear',
                  style: const TextStyle(
                      color: Ui.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _legendDot('Présents', Ui.success),
                  const SizedBox(width: 16),
                  _legendDot('Absents', Ui.danger),
                ],
              ),
              const SizedBox(height: 14),
              _AbsenceBarChart(
                present: monthP,
                absent: monthA,
                selectedMonth: _bilanMonth,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tableau par mois
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Tableau par mois',
                  style: TextStyle(
                      color: Ui.text,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _cell('Mois',
                      flex: 3,
                      color: Ui.muted,
                      bold: true,
                      align: TextAlign.left),
                  _cell('Présents', flex: 2, color: Ui.muted, bold: true),
                  _cell('Absents', flex: 2, color: Ui.muted, bold: true),
                  _cell('Taux', flex: 2, color: Ui.muted, bold: true),
                ],
              ),
              Divider(color: Colors.white.withOpacity(0.08), height: 18),
              if (monthsWithData.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucune donnée pour cette année.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Ui.muted, fontSize: 13)),
                )
              else ...[
                ...monthsWithData.map((i) {
                  final t = monthP[i] + monthA[i];
                  final r = (monthP[i] * 100 / t).round();
                  final selected = _bilanMonth == i + 1;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        _cell(kMonths[i + 1],
                            flex: 3,
                            align: TextAlign.left,
                            bold: selected,
                            color: selected ? Ui.violetSoft : Ui.text),
                        _cell('${monthP[i]}',
                            flex: 2, color: Ui.success, bold: true),
                        _cell('${monthA[i]}',
                            flex: 2, color: Ui.danger, bold: true),
                        _cell('$r %', flex: 2, color: Ui.muted),
                      ],
                    ),
                  );
                }),
                Divider(color: Colors.white.withOpacity(0.08), height: 18),
                Row(
                  children: [
                    _cell('Total $_bilanYear',
                        flex: 3, align: TextAlign.left, bold: true),
                    _cell('$yearP', flex: 2, color: Ui.success, bold: true),
                    _cell('$yearA', flex: 2, color: Ui.danger, bold: true),
                    _cell(
                        (yearP + yearA) == 0
                            ? '0 %'
                            : '${(yearP * 100 / (yearP + yearA)).round()} %',
                        flex: 2,
                        color: Ui.muted,
                        bold: true),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bilan individuel
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Par préséviteur · ${kMonths[_bilanMonth]} $_bilanYear',
                style: const TextStyle(
                    color: Ui.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _cell('Nom',
                      flex: 5,
                      color: Ui.muted,
                      bold: true,
                      align: TextAlign.left),
                  _cell('Présent', flex: 2, color: Ui.muted, bold: true),
                  _cell('Absent', flex: 2, color: Ui.muted, bold: true),
                ],
              ),
              Divider(color: Colors.white.withOpacity(0.08), height: 18),
              if (students.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('Aucun préséviteur dans cette classe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Ui.muted, fontSize: 13)),
                )
              else
                ...students.map((s) {
                  final id = '${s['id']}';
                  final p = perP[id] ?? 0;
                  final a = perA[id] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _cell(_nameOf(s),
                                flex: 5, align: TextAlign.left, bold: true),
                            _cell('$p',
                                flex: 2, color: Ui.success, bold: true),
                            _cell('$a', flex: 2, color: Ui.danger, bold: true),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _ratioBar(p, a),
                        if (a >= 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Absences répétées : pensez à prévenir $_prevenir.',
                              style: const TextStyle(
                                  color: Ui.gold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final students = _studentsOfClass;
    final presents =
        students.where((s) => _dayRecords['${s['id']}']?['statut'] == 'present').length;
    final absents =
        students.where((s) => _dayRecords['${s['id']}']?['statut'] == 'absent').length;
    final pending = students.length - presents - absents;

    return PageShell(
      title: 'Gestion absence',
      subtitle: 'Présences des préseviteurs',
      icon: Icons.fact_check_rounded,
      trailing: IconButton(
        onPressed: _refreshAll,
        tooltip: 'Actualiser',
        style: IconButton.styleFrom(
          backgroundColor: Ui.violet.withOpacity(0.14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.refresh_rounded, color: Ui.violetSoft, size: 20),
      ),
      children: [
        _notice(),
        const SizedBox(height: 16),
        SegmentedTabs(
          labels: _classes,
          index: _classeIndex,
          onChanged: _changeClasse,
        ),
        const SizedBox(height: 14),
        _dateCard(),
        const SizedBox(height: 18),
        SectionTitle('Appel · $_classe'),
        if (!_loadingStudents && !_loadingDay) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill('$presents présent(s)', Ui.success,
                  icon: Icons.check_circle_rounded),
              Pill('$absents absent(s)', Ui.danger, icon: Icons.cancel_rounded),
              if (pending > 0) Pill('$pending non renseigné(s)', Ui.muted),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              'Touchez à nouveau le statut choisi pour l\'effacer.',
              style: TextStyle(color: Ui.muted, fontSize: 11.5),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_loadingStudents || _loadingDay)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator(color: Ui.violet)),
          )
        else if (students.isEmpty)
          const EmptyState(
            icon: Icons.groups_rounded,
            text: 'Aucun préséviteur dans cette classe.',
          )
        else
          ...students.map(_studentTile),
        const SizedBox(height: 10),
        ..._bilanSection(students),
      ],
    );
  }
}

/// Histogramme simple (sans dépendance) : 2 barres par mois, présents / absents.
class _AbsenceBarChart extends StatelessWidget {
  final List<int> present;
  final List<int> absent;
  final int selectedMonth; // 0 = tous les mois

  const _AbsenceBarChart({
    required this.present,
    required this.absent,
    required this.selectedMonth,
  });

  static const double _chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    int maxValue = 1;
    for (int i = 0; i < 12; i++) {
      if (present[i] > maxValue) maxValue = present[i];
      if (absent[i] > maxValue) maxValue = absent[i];
    }

    Widget bar(int value, Color color) {
      final h = value == 0 ? 2.0 : (value / maxValue) * _chartHeight;
      return Container(
        width: 7,
        height: h,
        decoration: BoxDecoration(
          color: value == 0 ? color.withOpacity(0.25) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(12, (i) {
        final selected = selectedMonth == i + 1;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Ui.violet.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: _chartHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      bar(present[i], Ui.success),
                      const SizedBox(width: 2),
                      bar(absent[i], Ui.danger),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  kMonthsShort[i],
                  style: TextStyle(
                    color: selected ? Ui.violetSoft : Ui.muted,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}