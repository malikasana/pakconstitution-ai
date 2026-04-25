import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_colors.dart';
import '../providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _dotsController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _textFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    // Apply saved theme before animating
    final prefs = await SharedPreferences.getInstance();
    final isDark = (prefs.getString('theme') ?? 'light') == 'dark';
    if (mounted) {
      context.read<ThemeProvider>().setTheme(
          isDark ? ThemeMode.dark : ThemeMode.light);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F11) : AppColors.lightBg;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subtitleColor = isDark ? AppColors.darkText3 : AppColors.lightText3;

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.sidebarBg,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: AppColors.sidebarDivider,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                        blurRadius: 28,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: _ScalesIcon(size: 52),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App name + tagline
            FadeTransition(
              opacity: _textFade,
              child: SlideTransition(
                position: _textSlide,
                child: Column(
                  children: [
                    Text(
                      'PakConstitution AI',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Constitutional Research · 1973',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                        color: subtitleColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 56),

            // Divider
            FadeTransition(
              opacity: _textFade,
              child: Container(
                width: 32,
                height: 1.5,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 56),

            // Loading dots
            FadeTransition(
              opacity: _textFade,
              child: _LoadingDots(
                controller: _dotsController,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),

      // Bottom label
      bottomNavigationBar: FadeTransition(
        opacity: _textFade,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Text(
            'Pakistan · 1973 Constitution',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// Scales of justice icon drawn with CustomPainter
class _ScalesIcon extends StatelessWidget {
  final double size;
  const _ScalesIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ScalesPainter(),
    );
  }
}

class _ScalesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;

    // Top knob
    canvas.drawCircle(Offset(cx, size.height * 0.1), 5, fillPaint);

    // Pole
    canvas.drawLine(
      Offset(cx, size.height * 0.1),
      Offset(cx, size.height * 0.72),
      paint,
    );

    // Beam
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.3),
      Offset(size.width * 0.92, size.height * 0.3),
      paint,
    );

    // Left chain
    final chainPaint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.3),
      Offset(size.width * 0.2, size.height * 0.46),
      chainPaint,
    );
    // Right chain
    canvas.drawLine(
      Offset(size.width * 0.8, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.46),
      chainPaint,
    );

    // Left pan (arc)
    final leftPanRect = Rect.fromCenter(
      center: Offset(size.width * 0.2, size.height * 0.52),
      width: size.width * 0.28,
      height: size.height * 0.18,
    );
    canvas.drawArc(leftPanRect, 0, 3.14159, false, paint);

    // Right pan (arc)
    final rightPanRect = Rect.fromCenter(
      center: Offset(size.width * 0.8, size.height * 0.52),
      width: size.width * 0.28,
      height: size.height * 0.18,
    );
    canvas.drawArc(rightPanRect, 0, 3.14159, false, paint);

    // Stand
    final standPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, size.height * 0.72),
      Offset(cx, size.height * 0.85),
      standPaint,
    );

    // Base
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.88),
      Offset(size.width * 0.75, size.height * 0.88),
      standPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Animated loading dots
class _LoadingDots extends StatelessWidget {
  final AnimationController controller;
  final bool isDark;

  const _LoadingDots({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final value = ((controller.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (value < 0.4)
                ? value / 0.4
                : (value < 0.8)
                    ? 1.0 - (value - 0.4) / 0.4
                    : 0.2;

            final colors = isDark
                ? [
                    AppColors.darkBorder,
                    AppColors.darkBorder2,
                    AppColors.darkText3,
                  ]
                : [
                    AppColors.lightBorder2,
                    AppColors.lightText3,
                    AppColors.lightText2,
                  ];

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors[i].withOpacity(opacity.clamp(0.2, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}