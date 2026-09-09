import 'package:flutter/material.dart';

class AppLoadingScreen extends StatefulWidget {
  const AppLoadingScreen({super.key});

  @override
  State<AppLoadingScreen> createState() => _AppLoadingScreenState();
}

class _AppLoadingScreenState extends State<AppLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _brandBlue = Color(0xFF2F80ED);
  static const _skyTop = Color(0xFFE8F2FF);
  static const _skyBottom = Color(0xFFF7FBFF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _pulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_skyTop, _skyBottom, Colors.white],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: _brandBlue.withValues(alpha: 0.22),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: Image.asset(
                          'assets/images/app_logo.jpeg',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.home_work_rounded,
                            size: 64,
                            color: _brandBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'MyHome AI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Color(0xFF1B3A5F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Finding your next home',
                      style: TextStyle(
                        fontSize: 14,
                        color: _brandBlue.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(flex: 2),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: _brandBlue.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Loading…',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey.shade400,
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
