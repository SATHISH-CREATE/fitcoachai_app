import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class LandingVideoScreen extends StatefulWidget {
  const LandingVideoScreen({super.key});

  @override
  State<LandingVideoScreen> createState() => _LandingVideoScreenState();
}

class _LandingVideoScreenState extends State<LandingVideoScreen> {
  bool _isStarted = false;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/welcome.png'), context);
      precacheImage(const AssetImage('assets/icon.png'), context);
    });
  }

  void _handleStart() async {
    if (_isStarted) return;
    setState(() {
      _isStarted = true;
      _dragOffset = 0; // Reset drag offset to let the animation take over
    });
    
    await Future.delayed(const Duration(milliseconds: 150));
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          _buildBlob(top: -50, right: -40, color: Colors.orange, size: 160),
          _buildBlob(top: 150, left: -60, color: Colors.yellow, size: 140),
          _buildBlob(bottom: 100, left: -20, color: Colors.green, size: 130),
          _buildBlob(bottom: -30, right: 30, color: Colors.green.withOpacity(0.4), size: 150),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Text(
                  'Welcome to',
                  style: GoogleFonts.outfit(
                    fontSize: 24, fontWeight: FontWeight.w500, color: Colors.black,
                  ),
                ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),
                
                Text(
                  'FitCoach AI',
                  style: GoogleFonts.outfit(
                    fontSize: 48, fontWeight: FontWeight.w900, color: Colors.black,
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 600.ms).scale(begin: const Offset(0.9, 0.9)),
                
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Image.asset('assets/welcome.png', fit: BoxFit.contain),
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 60),
                  child: _buildAnimatedStartButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob({double? top, double? left, double? right, double? bottom, required Color color, required double size}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: RepaintBoundary(
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(color: color.withOpacity(0.6), shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _buildAnimatedStartButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = constraints.maxWidth - 140;
        
        return GestureDetector(
          onTap: _isStarted ? null : _handleStart,
          onHorizontalDragUpdate: (details) {
            if (_isStarted) return;
            setState(() {
                _dragOffset += details.delta.dx;
                if (_dragOffset < 0) _dragOffset = 0;
                if (_dragOffset > maxDrag) _dragOffset = maxDrag;
            });
          },
          onHorizontalDragEnd: (details) {
            if (_isStarted) return;
            if (_dragOffset > maxDrag * 0.6) {
                _handleStart();
            } else {
                setState(() => _dragOffset = 0);
            }
          },
          child: Container(
            height: 64,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                // Text in background
                Center(
                  child: AnimatedOpacity(
                    duration: 200.ms,
                    opacity: (_dragOffset / maxDrag) > 0.5 ? 0 : 1,
                    child: Text(
                      'Swipe to Start',
                      style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.4), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                
                // Animated Pill
                AnimatedPositioned(
                  duration: Duration(milliseconds: _dragOffset == 0 || _isStarted ? 300 : 0),
                  curve: Curves.easeOutCubic,
                  left: _isStarted ? maxDrag : _dragOffset,
                  top: 0, bottom: 0,
                  child: Container(
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC107), Color(0xFFFF9800)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                         BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 15, spreadRadius: 2),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _isStarted ? 'Let\'s Go!' : 'Start!',
                        style: GoogleFonts.outfit(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                
                // Arrows (Fade out as we swipe)
                if (!_isStarted)
                  Positioned(
                    right: 24, top: 0, bottom: 0,
                    child: AnimatedOpacity(
                      duration: 200.ms,
                      opacity: 1.0 - (_dragOffset / maxDrag),
                      child: Row(
                        children: [
                          _buildArrow(0),
                          _buildArrow(1),
                          _buildArrow(2),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.5, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildArrow(int index) {
    return Icon(
      Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.6), size: 28,
    ).animate(onPlay: (c) => c.repeat())
      .fadeIn(delay: (index * 200).ms, duration: 400.ms)
      .fadeOut(delay: (index * 200 + 400).ms, duration: 400.ms);
  }
}
