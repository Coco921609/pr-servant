import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Palette copte : noir de terre, rouge ocre (couleur liturgique), or des icônes, parchemin.
class _Ui {
  _Ui._();

  static const night = Color(0xFF1B0F0A);
  static const surface = Color(0xFF2B1A12);
  static const surfaceHigh = Color(0xFF3A2519);
  static const red = Color(0xFF9C2A1F);
  static const redDeep = Color(0xFF6B1812);
  static const redSoft = Color(0xFFD0604A);
  static const gold = Color(0xFFD8A441);
  static const goldSoft = Color(0xFFF0CF84);
  static const text = Color(0xFFF7EDD6);
  static const muted = Color(0xFFC8B291);
  static const danger = Color(0xFFFF7A6B);

  static const gradient = LinearGradient(
    colors: [red, redDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ---------------------------------------------------------------------------
// Éléments graphiques coptes
// ---------------------------------------------------------------------------

/// Croix copte : bras égaux, extrémités en losange, cercle central.
class _CopticCrossPainter extends CustomPainter {
  _CopticCrossPainter({this.color = _Ui.gold, this.ring = true});

  final Color color;
  final bool ring;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = Offset(s / 2, s / 2);
    final arm = s * 0.12;
    final len = s * 0.44;
    final p = Paint()..color = color..style = PaintingStyle.fill;

    if (ring) {
      final ringPaint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012;
      canvas.drawCircle(c, s * 0.48, ringPaint);
    }

    canvas.drawRect(Rect.fromLTRB(c.dx - arm, c.dy - len, c.dx + arm, c.dy + len), p);
    canvas.drawRect(Rect.fromLTRB(c.dx - len, c.dy - arm, c.dx + len, c.dy + arm), p);

    final r = arm * 1.5;
    _diamond(canvas, p, Offset(c.dx, c.dy - len), r);
    _diamond(canvas, p, Offset(c.dx, c.dy + len), r);
    _diamond(canvas, p, Offset(c.dx - len, c.dy), r);
    _diamond(canvas, p, Offset(c.dx + len, c.dy), r);

    canvas.drawCircle(c, arm * 1.05, Paint()..color = _Ui.red);
    canvas.drawCircle(
      c,
      arm * 1.05,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.015,
    );
  }

  void _diamond(Canvas canvas, Paint p, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..lineTo(o.dx + r, o.dy)
      ..lineTo(o.dx, o.dy + r)
      ..lineTo(o.dx - r, o.dy)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CopticCrossPainter old) => old.color != color || old.ring != ring;
}

/// Motif répété en losanges dorés, inspiré des textiles coptes.
class _OrnamentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grande croix copte en filigrane, au centre de l'écran
    _copticCross(canvas, Offset(w / 2, h * 0.34), math.min(w, h) * 0.20,
        Paint()..color = _Ui.gold.withOpacity(0.05));

    // Arcades de la nef le long du bord supérieur
    final arch = Paint()
      ..color = _Ui.gold.withOpacity(0.14)
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

    canvas.drawPath(body, Paint()..color = _Ui.night.withOpacity(0.55));
    canvas.drawPath(
      body,
      Paint()
        ..color = _Ui.gold.withOpacity(0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Croix au sommet de la coupole
    _copticCross(canvas, Offset(w / 2, naveTop - domeR - w * 0.035), w * 0.035,
        Paint()..color = _Ui.gold.withOpacity(0.40));

    // Fenêtres en arc et porte centrale
    final win = Paint()
      ..color = _Ui.gold.withOpacity(0.30)
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

class _CopticBackdrop extends StatelessWidget {
  const _CopticBackdrop();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/1.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(color: _Ui.night),
    );
  }
}

Widget _glow(Color color, double size, double opacity) {
  return IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(opacity), color.withOpacity(0)]),
      ),
    ),
  );
}

Widget _primaryButton({
  required String label,
  required VoidCallback onPressed,
  bool loading = false,
}) {
  return Container(
    height: 54,
    decoration: BoxDecoration(
      gradient: _Ui.gradient,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _Ui.gold.withOpacity(0.55)),
      boxShadow: [
        BoxShadow(color: _Ui.red.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 8)),
      ],
    ),
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: _Ui.goldSoft,
        disabledForegroundColor: _Ui.goldSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: loading
          ? const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: _Ui.goldSoft),
      )
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ),
  );
}

// ---------------------------------------------------------------------------
// Page d'ouverture
// ---------------------------------------------------------------------------

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 4200), _enter);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _enter() {
    if (!mounted) return;
    _timer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

    return Scaffold(
      backgroundColor: _Ui.night,
      body: Stack(
        children: [
          const Positioned.fill(child: _CopticBackdrop()),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(fade),
                        child: SizedBox(
                          width: 150,
                          height: 150,
                          child: CustomPaint(painter: _CopticCrossPainter()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: fade,
                      child: Column(
                        children: const [
                          Text(
                            'Préservant',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _Ui.gold,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'ÉGLISE COPTE ORTHODOXE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _Ui.goldSoft,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 3,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'St Mina, St Mercure & St Pape Cyrille VI',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _Ui.muted, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: fade,
                      child: Row(
                        children: [
                          Expanded(child: Container(height: 1, color: _Ui.gold.withOpacity(0.4))),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CustomPaint(painter: _CopticCrossPainter(ring: false)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Container(height: 1, color: _Ui.gold.withOpacity(0.4))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    FadeTransition(
                      opacity: fade,
                      child: const Text(
                        '« Que la paix du Seigneur soit avec vous tous »',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _Ui.text,
                          fontSize: 15,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 44),
                    FadeTransition(
                      opacity: fade,
                      child: SizedBox(
                        width: 220,
                        child: _primaryButton(label: 'Entrer', onPressed: _enter),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Écran de connexion / inscription
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  // Un formulaire par étape de l'inscription
  final _identityFormKey = GlobalKey<FormState>();
  final _infoFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  final ScrollController _scrollController = ScrollController();

  // Contrôleurs Connexion
  final TextEditingController _loginPrenomController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Contrôleurs Préseviteur
  final TextEditingController _presPasswordController = TextEditingController();
  final TextEditingController _presNomController = TextEditingController();
  final TextEditingController _presPrenomController = TextEditingController();
  final TextEditingController _presTelephoneController = TextEditingController(text: '+33');
  final TextEditingController _presAdresseController = TextEditingController();
  final TextEditingController _presVilleController = TextEditingController();
  final TextEditingController _presCodePostalController = TextEditingController();
  final TextEditingController _presAutrePereController = TextEditingController();
  final TextEditingController _presAccessCodeController = TextEditingController();

  String? _presBirthDay;
  String? _presBirthMonth;
  String? _presBirthYear;
  String? _presPereConfesseur;
  String? _presClasse;

  // Contrôleurs Profs
  final TextEditingController _profsPasswordController = TextEditingController();
  final TextEditingController _profsNomController = TextEditingController();
  final TextEditingController _profsPrenomController = TextEditingController();
  final TextEditingController _profsTelephoneController = TextEditingController(text: '+33');
  final TextEditingController _profsAdresseController = TextEditingController();
  final TextEditingController _profsVilleController = TextEditingController();
  final TextEditingController _profsCodePostalController = TextEditingController();
  final TextEditingController _profsAutrePereController = TextEditingController();
  final TextEditingController _profsAccessCodeController = TextEditingController();

  String? _profsBirthDay;
  String? _profsBirthMonth;
  String? _profsBirthYear;
  String? _profsPereConfesseur;
  String? _profsClasse;

  // Contrôleurs Chef d'église
  final TextEditingController _chefPasswordController = TextEditingController();
  final TextEditingController _chefNomController = TextEditingController();
  final TextEditingController _chefPrenomController = TextEditingController();
  final TextEditingController _chefTelephoneController = TextEditingController(text: '+33');
  final TextEditingController _chefAccessCodeController = TextEditingController();

  // Listes pour la date de naissance (De 1980 à 2099)
  final List<String> _birthDaysList = List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));
  final List<String> _birthMonthsList = ['01', '02', '03', '04', '05', '06', '07', '08', '09', '10', '11', '12'];
  final List<String> _birthYearsList = List.generate(2099 - 1980 + 1, (index) => (1980 + index).toString());

  // Liste des classes disponibles pour Préseviteur
  final List<String> _classesList = ['1ere année', '2 année'];

  // Liste des classes pour Profs (les deux réunies)
  final List<String> _profsClassesList = ['1ère et 2ème année'];

  // Liste des Pères Confesseurs (Abouna)
  final List<String> _listeAbounas = [
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

  // Gestion de la photo de profil
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool _isSignUp = false;
  int _signUpTabindex = 0; // 0: Préseviteur, 1: Profs, 2: Chef d'église
  int _signUpStep = 0;
  bool _forward = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _loginErrorMessage;

  @override
  void dispose() {
    _scrollController.dispose();
    _loginPrenomController.dispose();
    _loginPasswordController.dispose();
    _presPasswordController.dispose();
    _presNomController.dispose();
    _presPrenomController.dispose();
    _presTelephoneController.dispose();
    _presAdresseController.dispose();
    _presVilleController.dispose();
    _presCodePostalController.dispose();
    _presAutrePereController.dispose();
    _presAccessCodeController.dispose();
    _profsPasswordController.dispose();
    _profsNomController.dispose();
    _profsPrenomController.dispose();
    _profsTelephoneController.dispose();
    _profsAdresseController.dispose();
    _profsVilleController.dispose();
    _profsCodePostalController.dispose();
    _profsAutrePereController.dispose();
    _profsAccessCodeController.dispose();
    _chefPasswordController.dispose();
    _chefNomController.dispose();
    _chefPrenomController.dispose();
    _chefTelephoneController.dispose();
    _chefAccessCodeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Accès aux données du profil choisi (évite de dupliquer les formulaires)
  // ---------------------------------------------------------------------------

  String get _roleName =>
      _signUpTabindex == 0 ? 'Préseviteur' : (_signUpTabindex == 1 ? 'Profs' : 'Chef d\'église');

  TextEditingController get _nomC =>
      _signUpTabindex == 0 ? _presNomController : (_signUpTabindex == 1 ? _profsNomController : _chefNomController);
  TextEditingController get _prenomC =>
      _signUpTabindex == 0 ? _presPrenomController : (_signUpTabindex == 1 ? _profsPrenomController : _chefPrenomController);
  TextEditingController get _telC => _signUpTabindex == 0
      ? _presTelephoneController
      : (_signUpTabindex == 1 ? _profsTelephoneController : _chefTelephoneController);
  TextEditingController get _passC =>
      _signUpTabindex == 0 ? _presPasswordController : (_signUpTabindex == 1 ? _profsPasswordController : _chefPasswordController);
  TextEditingController get _accessC => _signUpTabindex == 0
      ? _presAccessCodeController
      : (_signUpTabindex == 1 ? _profsAccessCodeController : _chefAccessCodeController);
  TextEditingController get _adresseC => _signUpTabindex == 0 ? _presAdresseController : _profsAdresseController;
  TextEditingController get _villeC => _signUpTabindex == 0 ? _presVilleController : _profsVilleController;
  TextEditingController get _cpC => _signUpTabindex == 0 ? _presCodePostalController : _profsCodePostalController;
  TextEditingController get _autrePereC => _signUpTabindex == 0 ? _presAutrePereController : _profsAutrePereController;

  String? get _pere => _signUpTabindex == 0 ? _presPereConfesseur : _profsPereConfesseur;
  String? get _bDay => _signUpTabindex == 0 ? _presBirthDay : _profsBirthDay;
  String? get _bMonth => _signUpTabindex == 0 ? _presBirthMonth : _profsBirthMonth;
  String? get _bYear => _signUpTabindex == 0 ? _presBirthYear : _profsBirthYear;
  String? get _classe => _signUpTabindex == 0 ? _presClasse : _profsClasse;

  void _setPere(String? v) => setState(() {
    if (_signUpTabindex == 0) {
      _presPereConfesseur = v;
    } else {
      _profsPereConfesseur = v;
    }
  });
  void _setBDay(String? v) => setState(() {
    if (_signUpTabindex == 0) {
      _presBirthDay = v;
    } else {
      _profsBirthDay = v;
    }
  });
  void _setBMonth(String? v) => setState(() {
    if (_signUpTabindex == 0) {
      _presBirthMonth = v;
    } else {
      _profsBirthMonth = v;
    }
  });
  void _setBYear(String? v) => setState(() {
    if (_signUpTabindex == 0) {
      _presBirthYear = v;
    } else {
      _profsBirthYear = v;
    }
  });
  void _setClasse(String? v) => setState(() {
    if (_signUpTabindex == 0) {
      _presClasse = v;
    } else {
      _profsClasse = v;
    }
  });

  // Étapes : 0 profil, 1 identité, 2 informations (sauf Chef d'église), dernière : sécurité
  int get _totalSteps => _signUpTabindex == 2 ? 3 : 4;

  String get _stepKind {
    if (_signUpStep == 0) return 'role';
    if (_signUpStep == 1) return 'identity';
    if (_signUpStep == _totalSteps - 1) return 'security';
    return 'info';
  }

  // ---------------------------------------------------------------------------
  // Logique (inchangée)
  // ---------------------------------------------------------------------------

  String _getInternalAuthIdentifier(String prenom) {
    final cleanPrenom = prenom.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$cleanPrenom@preservant.internal';
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: _Ui.text)),
          backgroundColor: color ?? _Ui.redDeep,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: _Ui.gold.withOpacity(0.4)),
          ),
        ),
      );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showSnack('Erreur lors de la sélection de l\'image : $e', color: Colors.red.shade700);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _Ui.surface,
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
                decoration: BoxDecoration(color: _Ui.gold.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 18),
              _sheetOption(Icons.photo_library_rounded, 'Choisir dans la galerie', () {
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
      tileColor: _Ui.gold.withOpacity(0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _Ui.red.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _Ui.goldSoft, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: _Ui.text, fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  Future<String?> _uploadImageToSupabase(String prenom) async {
    if (_selectedImage == null) return null;
    try {
      final cleanPrenom = prenom.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final fileName = '${cleanPrenom}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await _selectedImage!.readAsBytes();

      String bucketName = 'photos';
      try {
        await Supabase.instance.client.storage
            .from(bucketName)
            .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
      } catch (_) {
        bucketName = 'avatars';
        await Supabase.instance.client.storage
            .from(bucketName)
            .uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
        );
      }

      final imageUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      debugPrint('Erreur upload image: $e');
      return null;
    }
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _loginErrorMessage = null;
    });

    try {
      final prenom = _loginPrenomController.text.trim();
      final internalAuth = _getInternalAuthIdentifier(prenom);

      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: internalAuth,
        password: _loginPasswordController.text.trim(),
      );

      final userMetadata = authResponse.user?.userMetadata;
      String? photoUrl = userMetadata?['photo_url'];

      if (authResponse.user != null && (photoUrl == null || photoUrl.isEmpty)) {
        try {
          final profileData = await Supabase.instance.client
              .from('profiles')
              .select('photo_url')
              .eq('id', authResponse.user!.id)
              .maybeSingle();
          if (profileData != null) {
            photoUrl = profileData['photo_url'];
          }
        } catch (_) {}
      }

      if (mounted) {
        _showSnack('Bienvenue ! Connexion réussie.');
        Navigator.of(context).pushReplacementNamed('/home', arguments: photoUrl);
      }
    } on AuthException catch (_) {
      setState(() {
        _loginErrorMessage = 'Prénom ou mot de passe incorrect';
      });
    } catch (e) {
      setState(() {
        _loginErrorMessage = 'Erreur de connexion : $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSignUp(String role) async {
    // Les étapes précédentes ont été validées au fil du parcours ; on valide ici la dernière.
    if (!(_securityFormKey.currentState?.validate() ?? false)) return;

    if (role == 'Préseviteur') {
      if (_presAccessCodeController.text.trim() != 'préservant2026!') {
        _showSnack('Code d\'accès secret incorrect pour Préseviteur !', color: Colors.red.shade700);
        return;
      }
    } else if (role == 'Profs') {
      if (_profsAccessCodeController.text.trim() != 'profs2026!!!!!') {
        _showSnack('Code d\'accès secret incorrect pour Profs !', color: Colors.red.shade700);
        return;
      }
    } else if (role == 'Chef d\'église') {
      if (_chefAccessCodeController.text.trim() != 'eftrkad2026!!!!') {
        _showSnack('Code d\'accès secret incorrect pour Chef d\'église !', color: Colors.red.shade700);
        return;
      }
    }

    if (role == 'Préseviteur') {
      if (_presBirthDay == null || _presBirthMonth == null || _presBirthYear == null) {
        _showSnack('Veuillez sélectionner la date de naissance complète');
        return;
      }
      if (_presClasse == null) {
        _showSnack('Veuillez sélectionner la classe');
        return;
      }
    }

    if (role == 'Profs') {
      if (_profsBirthDay == null || _profsBirthMonth == null || _profsBirthYear == null) {
        _showSnack('Veuillez sélectionner la date de naissance complète');
        return;
      }
      if (_profsClasse == null) {
        _showSnack('Veuillez sélectionner la classe');
        return;
      }
    }

    setState(() => _isLoading = true);

    String prenom, nom, telephone, password, adresse, ville, codePostal, dateNaissance, classe;
    String? pereConfesseur;
    String finalRole = role;
    String currentAccessCode = '';

    if (role == 'Préseviteur') {
      prenom = _presPrenomController.text.trim();
      nom = _presNomController.text.trim();
      telephone = _presTelephoneController.text.trim();
      password = _presPasswordController.text.trim();
      adresse = _presAdresseController.text.trim();
      ville = _presVilleController.text.trim();
      codePostal = _presCodePostalController.text.trim();
      dateNaissance = '$_presBirthYear-$_presBirthMonth-$_presBirthDay';
      classe = _presClasse ?? '';
      pereConfesseur = _presPereConfesseur == 'Autre' ? _presAutrePereController.text.trim() : _presPereConfesseur;
      currentAccessCode = _presAccessCodeController.text.trim();
    } else if (role == 'Profs') {
      prenom = _profsPrenomController.text.trim();
      nom = _profsNomController.text.trim();
      telephone = _profsTelephoneController.text.trim();
      password = _profsPasswordController.text.trim();
      adresse = _profsAdresseController.text.trim();
      ville = _profsVilleController.text.trim();
      codePostal = _profsCodePostalController.text.trim();
      dateNaissance = '$_profsBirthYear-$_profsBirthMonth-$_profsBirthDay';
      classe = _profsClasse ?? '';
      pereConfesseur = _profsPereConfesseur == 'Autre' ? _profsAutrePereController.text.trim() : _profsPereConfesseur;
      currentAccessCode = _profsAccessCodeController.text.trim();
    } else {
      prenom = _chefPrenomController.text.trim();
      nom = _chefNomController.text.trim();
      telephone = _chefTelephoneController.text.trim();
      password = _chefPasswordController.text.trim();
      finalRole = 'Chef d\'église';
      adresse = '';
      ville = '';
      codePostal = '';
      dateNaissance = '';
      classe = '';
      currentAccessCode = _chefAccessCodeController.text.trim();
    }

    final internalAuth = _getInternalAuthIdentifier(prenom);
    String? dateNaissanceSanitized = (dateNaissance.trim().isEmpty || dateNaissance.contains('null')) ? null : dateNaissance;

    try {
      // La photo est envoyée APRÈS la création du compte : à ce moment-là
      // l'utilisateur est connecté et le stockage accepte l'envoi.
      String? photoUrl;
      bool photoFailed = false;

      final Map<String, dynamic> metadata = {
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'role': finalRole,
        'classe': classe,
        'pere_confesseur': pereConfesseur ?? '',
        'adresse': adresse.isEmpty ? '' : adresse,
        'ville': ville.isEmpty ? '' : ville,
        'code_postal': codePostal.isEmpty ? '' : codePostal,
        'date_naissance': dateNaissanceSanitized,
        'photo_url': '',
        'access_code': currentAccessCode,
      };

      final response = await Supabase.instance.client.auth.signUp(
        email: internalAuth,
        password: password,
        data: metadata,
      );

      if (response.user != null) {
        if (_selectedImage != null) {
          photoUrl = await _uploadImageToSupabase(prenom);
          if (photoUrl == null) photoFailed = true;
        }

        try {
          final Map<String, dynamic> profileData = {
            'id': response.user!.id,
            'nom': nom,
            'prenom': prenom,
            'telephone': telephone,
            'role': finalRole,
            'classe': classe,
            'pere_confesseur': pereConfesseur ?? '',
            'adresse': adresse.isEmpty ? null : adresse,
            'ville': ville.isEmpty ? null : ville,
            'code_postal': codePostal.isEmpty ? null : codePostal,
            'date_naissance': dateNaissanceSanitized,
            'photo_url': photoUrl ?? '',
            'access_code': currentAccessCode,
          };

          await Supabase.instance.client.from('profiles').upsert(profileData);
        } catch (dbErr) {
          debugPrint('Erreur insertion table profiles: $dbErr');
        }

        // La photo est enregistrée à part, par deux voies indépendantes
        // (profil et métadonnées du compte). Si aucune ne marche, on le dit.
        if (photoUrl != null) {
          bool photoSaved = false;
          try {
            await Supabase.instance.client
                .from('profiles')
                .update({'photo_url': photoUrl})
                .eq('id', response.user!.id);
            photoSaved = true;
          } catch (e) {
            debugPrint('Erreur enregistrement photo (profil) : $e');
          }
          try {
            await Supabase.instance.client.auth
                .updateUser(UserAttributes(data: {'photo_url': photoUrl}));
            photoSaved = true;
          } catch (e) {
            debugPrint('Erreur enregistrement photo (métadonnées) : $e');
          }
          if (!photoSaved) photoFailed = true;
        }
      }

      if (mounted) {
        if (response.user != null) {
          _showSnack(
            photoFailed
                ? 'Compte créé, mais la photo n\'a pas pu être enregistrée. Ajoutez-la dans Paramètres.'
                : 'Compte créé avec succès ! Connexion réussie.',
            color: photoFailed ? Colors.orange.shade800 : Colors.green.shade700,
          );
          Navigator.of(context).pushReplacementNamed('/home', arguments: photoUrl);
        }
      }
    } on AuthException catch (e) {
      String errorMessage = e.message;
      if (errorMessage.toLowerCase().contains('already registered')) {
        errorMessage = 'Ce compte existe déjà. Veuillez vous connecter.';
      }
      _showSnack(errorMessage, color: Colors.red.shade700);
    } catch (e) {
      _showSnack('Erreur : $e', color: Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetPrenomController = TextEditingController();
    final TextEditingController resetNewPasswordController = TextEditingController();
    final GlobalKey<FormState> resetFormKey = GlobalKey<FormState>();
    bool isResetting = false;
    bool obscureReset = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _Ui.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _Ui.gold.withOpacity(0.35)),
          ),
          title: const Text(
            'Nouveau mot de passe',
            style: TextStyle(color: _Ui.goldSoft, fontSize: 19, fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: resetFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Entrez votre prénom et votre nouveau mot de passe.',
                  style: TextStyle(color: _Ui.muted, fontSize: 13.5, height: 1.35),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: resetPrenomController,
                  cursorColor: _Ui.gold,
                  style: const TextStyle(color: _Ui.text, fontSize: 15),
                  decoration: _inputDecoration('Prénom', Icons.person_outline_rounded),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: resetNewPasswordController,
                  obscureText: obscureReset,
                  cursorColor: _Ui.gold,
                  style: const TextStyle(color: _Ui.text, fontSize: 15),
                  decoration: _inputDecoration(
                    'Nouveau mot de passe',
                    Icons.lock_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        obscureReset ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _Ui.muted,
                        size: 20,
                      ),
                      onPressed: () => setDialogState(() => obscureReset = !obscureReset),
                    ),
                  ),
                  validator: (val) => val == null || val.length < 6 ? 'Min 6 caractères' : null,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler', style: TextStyle(color: _Ui.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _Ui.red,
                foregroundColor: _Ui.goldSoft,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onPressed: isResetting
                  ? null
                  : () async {
                if (!resetFormKey.currentState!.validate()) return;
                setDialogState(() => isResetting = true);

                try {
                  final prenomClean =
                  resetPrenomController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                  await Supabase.instance.client.rpc(
                    'update_password_by_prenom',
                    params: {
                      'p_prenom': prenomClean,
                      'p_new_password': resetNewPasswordController.text.trim(),
                    },
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    _showSnack('Mot de passe mis à jour avec succès !', color: Colors.green.shade700);
                  }
                } catch (_) {
                  setDialogState(() => isResetting = false);
                  _showSnack('Erreur : Prénom introuvable', color: Colors.red.shade700);
                }
              },
              child: isResetting
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _Ui.goldSoft),
              )
                  : const Text('Mettre à jour', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation entre connexion / inscription / étapes
  // ---------------------------------------------------------------------------

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _toggleMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSignUp = !_isSignUp;
      _selectedImage = null;
      _loginErrorMessage = null;
      _signUpStep = 0;
      _forward = true;
    });
    _scrollToTop();
  }

  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_signUpStep == 0) {
      _toggleMode();
      return;
    }
    setState(() {
      _forward = false;
      _signUpStep--;
    });
    _scrollToTop();
  }

  void _goNext() {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    final kind = _stepKind;
    if (kind == 'identity' && !(_identityFormKey.currentState?.validate() ?? false)) return;
    if (kind == 'info' && !(_infoFormKey.currentState?.validate() ?? false)) return;
    if (kind == 'security') {
      _submitSignUp(_roleName);
      return;
    }
    setState(() {
      _forward = true;
      _signUpStep++;
    });
    _scrollToTop();
  }

  // ---------------------------------------------------------------------------
  // Interface
  // ---------------------------------------------------------------------------

  static Widget _topLayout(Widget? current, List<Widget> previous) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [...previous, if (current != null) current],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isSignUp) _goBack();
      },
      child: Scaffold(
        backgroundColor: _Ui.night,
        body: Stack(
          children: [
            Positioned.fill(child: _buildBackground()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: _topLayout,
                          child: KeyedSubtree(
                            key: ValueKey<bool>(_isSignUp),
                            child: _buildBrand(),
                          ),
                        ),
                        SizedBox(height: _isSignUp ? 18 : 28),
                        _glassCard(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              layoutBuilder: _topLayout,
                              child: KeyedSubtree(
                                key: ValueKey<bool>(_isSignUp),
                                child: _isSignUp ? _buildSignUpCard() : _buildLoginCard(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _buildModeSwitch(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() => const _CopticBackdrop();

  Widget _buildBrand() {
    final logo = Image.asset(
      'assets/image/logo.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          CustomPaint(painter: _CopticCrossPainter()),
    );

    if (_isSignUp) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 36, width: 36, child: logo),
          const SizedBox(width: 10),
          const Text(
            'Préservant',
            style: TextStyle(color: _Ui.gold, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.6),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          height: 96,
          width: 96,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _Ui.gold.withOpacity(0.06),
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: _Ui.gold.withOpacity(0.5), width: 1.2),
            boxShadow: [
              BoxShadow(color: _Ui.red.withOpacity(0.45), blurRadius: 40, spreadRadius: -4),
            ],
          ),
          child: logo,
        ),
        const SizedBox(height: 18),
        const Text(
          'Préservant',
          style: TextStyle(color: _Ui.gold, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'ÉGLISE COPTE ORTHODOXE',
          style: TextStyle(color: _Ui.goldSoft, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2.6),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'St Mina, St Mercure & St Pape Cyrille VI',
          style: TextStyle(color: _Ui.muted, fontSize: 12.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 40, offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: _Ui.surface.withOpacity(0.42),
              border: Border.all(color: _Ui.gold.withOpacity(0.25)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitch() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Déjà un compte ?' : 'Pas encore de compte ?',
          style: const TextStyle(color: _Ui.muted, fontSize: 14),
        ),
        TextButton(
          onPressed: _toggleMode,
          style: TextButton.styleFrom(foregroundColor: _Ui.goldSoft),
          child: Text(
            _isSignUp ? 'Se connecter' : 'Créer un compte',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ],
    );
  }

  // ----- Connexion -----

  Widget _buildLoginCard() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bon retour',
            style: TextStyle(color: _Ui.goldSoft, fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous avec votre prénom et votre mot de passe.',
            style: TextStyle(color: _Ui.muted, fontSize: 13.5, height: 1.35),
          ),
          const SizedBox(height: 22),
          _textField(
            controller: _loginPrenomController,
            label: 'Prénom',
            icon: Icons.person_rounded,
            validator: (val) => val == null || val.trim().isEmpty ? 'Veuillez entrer votre prénom' : null,
          ),
          const SizedBox(height: 14),
          _textField(
            controller: _loginPasswordController,
            label: 'Mot de passe',
            icon: Icons.lock_rounded,
            isPassword: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _submitLogin(),
            validator: (val) => val == null || val.trim().isEmpty ? 'Veuillez entrer votre mot de passe' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(foregroundColor: _Ui.muted),
              child: const Text('Mot de passe oublié ?', style: TextStyle(fontSize: 13)),
            ),
          ),
          if (_loginErrorMessage != null) ...[
            _errorBanner(_loginErrorMessage!),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),
          _primaryButton(
            label: 'Se connecter',
            loading: _isLoading,
            onPressed: _submitLogin,
          ),
        ],
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Ui.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Ui.danger.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: _Ui.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFFFC7BD), fontSize: 13.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // ----- Inscription -----

  Widget _buildSignUpCard() {
    final isLast = _stepKind == 'security';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _roundButton(Icons.arrow_back_rounded, _goBack),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Créer un compte',
                style: TextStyle(color: _Ui.goldSoft, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              'Étape ${_signUpStep + 1} sur $_totalSteps',
              style: const TextStyle(color: _Ui.muted, fontSize: 12.5),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStepper(),
        const SizedBox(height: 22),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          layoutBuilder: _topLayout,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey<int>(_signUpStep);
            final dx = (_forward ? 1 : -1) * (incoming ? 0.06 : -0.06);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_signUpStep),
            child: _buildStepBody(),
          ),
        ),
        const SizedBox(height: 22),
        _primaryButton(
          label: isLast ? 'Créer mon compte' : 'Continuer',
          loading: _isLoading && isLast,
          onPressed: _goNext,
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) {
    return Tooltip(
      message: 'Retour',
      child: Material(
        color: _Ui.gold.withOpacity(0.08),
        shape: CircleBorder(side: BorderSide(color: _Ui.gold.withOpacity(0.3))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: _Ui.goldSoft, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Row(
      children: List.generate(_totalSteps, (i) {
        final reached = i <= _signUpStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: reached ? _Ui.gradient : null,
                color: reached ? null : _Ui.gold.withOpacity(0.14),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepBody() {
    switch (_stepKind) {
      case 'role':
        return _buildRoleStep();
      case 'identity':
        return _buildIdentityStep();
      case 'info':
        return _buildInfoStep();
      default:
        return _buildSecurityStep();
    }
  }

  Widget _stepIntro(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _Ui.goldSoft, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _Ui.muted, fontSize: 13, height: 1.35)),
        ],
      ),
    );
  }

  Widget _caption(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(color: _Ui.muted, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Étape 1 : profil
  Widget _buildRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepIntro('Choisissez votre profil', 'Les informations demandées ensuite dépendent de votre profil.'),
        _roleCard(0, 'Préseviteur', 'Élève en 1ère ou 2ème année', Icons.school_rounded),
        _roleCard(1, 'Profs', 'Enseigne en 1ère et 2ème année', Icons.menu_book_rounded),
        _roleCard(2, 'Chef d\'église', 'Responsable de l\'église', Icons.church_rounded),
      ],
    );
  }

  Widget _roleCard(int index, String title, String description, IconData icon) {
    final selected = _signUpTabindex == index;
    return Padding(
      padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: '$title, $description',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _signUpTabindex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? _Ui.red.withOpacity(0.28) : _Ui.gold.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? _Ui.gold : _Ui.gold.withOpacity(0.18),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: selected ? _Ui.gradient : null,
                    color: selected ? null : _Ui.gold.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: selected ? _Ui.goldSoft : _Ui.gold, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(color: _Ui.text, fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(description, style: const TextStyle(color: _Ui.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _Ui.gold : Colors.transparent,
                    border: Border.all(color: selected ? _Ui.gold : _Ui.gold.withOpacity(0.4), width: 1.5),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, size: 16, color: _Ui.night) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Étape 2 : identité
  Widget _buildIdentityStep() {
    return Form(
      key: _identityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIntro('Faisons connaissance', 'Votre nom, votre prénom et un numéro pour vous joindre.'),
          const SizedBox(height: 20),
          _textField(controller: _nomC, label: 'Nom', icon: Icons.badge_rounded),
          const SizedBox(height: 12),
          _textField(controller: _prenomC, label: 'Prénom', icon: Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _textField(
            controller: _telC,
            label: 'Téléphone',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            formatters: [PhoneInputFormatter()],
            action: TextInputAction.done,
            validator: _validatePhone,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _Ui.gold, size: 15),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Gardez bien le 0 : +3306 ou +3307, sinon WhatsApp ne fonctionne pas.',
                    style: TextStyle(color: _Ui.gold, fontSize: 11.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _validatePhone(String? val) {
    if (val == null || val.isEmpty || val == '+33') return 'Requis';
    final clean = val.replaceAll(' ', '');
    if (!clean.startsWith('+3306') && !clean.startsWith('+3307')) {
      return 'Vous avez bien le 0 ? Le numéro doit commencer par +3306 ou +3307';
    }
    return null;
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceDialog,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_Ui.gold, _Ui.red],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: _Ui.surfaceHigh,
                    backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null
                        ? const Icon(Icons.person_rounded, color: _Ui.muted, size: 40)
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: _Ui.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: _Ui.surface, width: 2),
                    ),
                    child: Icon(
                      _selectedImage == null ? Icons.add_a_photo_rounded : Icons.edit_rounded,
                      color: _Ui.goldSoft,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _selectedImage == null ? 'Ajouter une photo (facultatif)' : 'Changer la photo',
              style: const TextStyle(color: _Ui.goldSoft, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // Étape 3 : informations (Préseviteur et Profs)
  Widget _buildInfoStep() {
    return Form(
      key: _infoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIntro('Complétez votre profil', 'Quelques détails pour finaliser votre inscription.'),
          _dropdown(
            label: 'Abouna confesseur',
            icon: Icons.church_rounded,
            value: _pere,
            items: _listeAbounas,
            onChanged: _setPere,
          ),
          if (_pere == 'Autre') ...[
            const SizedBox(height: 12),
            _textField(
              controller: _autrePereC,
              label: 'Précisez le nom d\'Abouna',
              icon: Icons.edit_rounded,
              validator: (val) => _pere == 'Autre' && (val == null || val.trim().isEmpty) ? 'Requis' : null,
            ),
          ],
          const SizedBox(height: 18),
          _caption('Date de naissance'),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: _dropdown(label: 'Jour', value: _bDay, items: _birthDaysList, onChanged: _setBDay, compact: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: _dropdown(label: 'Mois', value: _bMonth, items: _birthMonthsList, onChanged: _setBMonth, compact: true),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 13,
                child: _dropdown(label: 'Année', value: _bYear, items: _birthYearsList, onChanged: _setBYear, compact: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Classe',
            icon: Icons.school_rounded,
            value: _classe,
            items: _signUpTabindex == 0 ? _classesList : _profsClassesList,
            onChanged: _setClasse,
          ),
          const SizedBox(height: 12),
          _textField(controller: _adresseC, label: 'Adresse', icon: Icons.home_rounded),
          const SizedBox(height: 12),
          _textField(controller: _villeC, label: 'Ville', icon: Icons.location_city_rounded),
          const SizedBox(height: 12),
          _textField(
            controller: _cpC,
            label: 'Code postal',
            icon: Icons.pin_drop_rounded,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            action: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  // Dernière étape : mot de passe et code d'accès
  Widget _buildSecurityStep() {
    return Form(
      key: _securityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stepIntro('Sécurisez votre compte', 'Choisissez un mot de passe et saisissez le code d\'accès de votre profil.'),
          _buildRecapTile(),
          const SizedBox(height: 16),
          _textField(
            controller: _passC,
            label: 'Mot de passe',
            helper: 'Au moins 6 caractères',
            icon: Icons.lock_rounded,
            isPassword: true,
            validator: (val) => val == null || val.length < 6 ? 'Min 6 caractères' : null,
          ),
          const SizedBox(height: 12),
          _textField(
            controller: _accessC,
            label: 'Code d\'accès',
            icon: Icons.security_rounded,
            obscure: true,
            action: TextInputAction.done,
            onSubmitted: (_) => _goNext(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecapTile() {
    final fullName = '${_prenomC.text.trim()} ${_nomC.text.trim()}'.trim();
    final initial = fullName.isEmpty ? '?' : fullName[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _Ui.gold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Ui.gold.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _Ui.red.withOpacity(0.45),
            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
            child: _selectedImage == null
                ? Text(initial, style: const TextStyle(color: _Ui.goldSoft, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Nouveau compte' : fullName,
                  softWrap: true,
                  style: const TextStyle(color: _Ui.text, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(_roleName, style: const TextStyle(color: _Ui.muted, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Composants réutilisables
  // ---------------------------------------------------------------------------

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData? icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool obscure = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextInputAction action = TextInputAction.next,
    ValueChanged<String>? onSubmitted,
    String? helper,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : obscure,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textInputAction: action,
      onFieldSubmitted: onSubmitted,
      cursorColor: _Ui.gold,
      style: const TextStyle(color: _Ui.text, fontSize: 15),
      decoration: _inputDecoration(
        label,
        icon,
        helper: helper,
        suffix: isPassword
            ? IconButton(
          tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            color: _Ui.muted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        )
            : null,
      ),
      validator: validator ?? (val) => val == null || val.trim().isEmpty ? 'Requis' : null,
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
    bool compact = false,
  }) {
    final fontSize = compact ? 14.0 : 15.0;
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value,
      dropdownColor: _Ui.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      menuMaxHeight: 320,
      itemHeight: null,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _Ui.gold, size: compact ? 18 : 24),
      style: TextStyle(color: _Ui.text, fontSize: fontSize),
      decoration: _inputDecoration(label, icon, compact: compact),
      selectedItemBuilder: (context) => items
          .map(
            (e) => Align(
          alignment: Alignment.centerLeft,
          child: Text(
            e,
            softWrap: true,
            style: TextStyle(color: _Ui.text, fontSize: fontSize),
          ),
        ),
      )
          .toList(),
      items: items
          .map(
            (e) => DropdownMenuItem(
          value: e,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              e,
              softWrap: true,
              style: TextStyle(color: _Ui.text, fontSize: fontSize),
            ),
          ),
        ),
      )
          .toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Requis' : null,
    );
  }

  InputDecoration _inputDecoration(
      String label,
      IconData? icon, {
        Widget? suffix,
        bool compact = false,
        String? helper,
      }) {
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _Ui.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: _Ui.gold, fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: icon == null ? null : Icon(icon, color: _Ui.gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _Ui.gold.withOpacity(0.05),
      contentPadding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 16),
      border: border(_Ui.gold.withOpacity(0.22)),
      enabledBorder: border(_Ui.gold.withOpacity(0.22)),
      focusedBorder: border(_Ui.gold, 1.6),
      errorBorder: border(_Ui.danger, 1.2),
      focusedErrorBorder: border(_Ui.danger, 1.6),
      errorStyle: const TextStyle(color: _Ui.danger, fontSize: 12, height: 1.25),
      errorMaxLines: 3,
      helperText: helper,
      helperStyle: const TextStyle(color: _Ui.muted, fontSize: 11.5, height: 1.3),
      helperMaxLines: 2,
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;
    if (text.isEmpty) {
      return const TextEditingValue(text: '+33', selection: TextSelection.collapsed(offset: 3));
    }
    if (!text.startsWith('+33')) {
      text = '+33${text.startsWith('0') ? text.substring(1) : text}';
    }
    if (text.allMatches('+33').length > 1) {
      text = '+33${text.replaceAll('+33', '')}';
    }
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}