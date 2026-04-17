import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final bool useGradient;
  final bool useBlobs;
  final bool isInternal;
  
  const AppBackground({
    super.key, 
    required this.child,
    this.useGradient = true,
    this.useBlobs = true,
    this.isInternal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: useGradient
          ? const BoxDecoration(
              gradient: AppColors.bgGradient,
            )
          : const BoxDecoration(
              color: AppColors.bgMain,
            ),
      child: Stack(
        children: [
          if (useBlobs) ...[
            // Static decorative blobs — no continuous animations for performance
            _buildBlob(top: -50, right: -40, color: Colors.orange.withOpacity(0.12), size: 250),
            _buildBlob(top: 350, left: -60, color: Colors.yellow.withOpacity(0.08), size: 200),
            _buildBlob(bottom: 250, right: -20, color: Colors.green.withOpacity(0.1), size: 220),
            _buildBlob(bottom: -60, left: 30, color: AppColors.primary.withOpacity(0.08), size: 180),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildBlob({double? top, double? left, double? right, double? bottom, required Color color, required double size}) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _ThreeDAnimatedBackground extends StatefulWidget {
  const _ThreeDAnimatedBackground();

  @override
  State<_ThreeDAnimatedBackground> createState() => _ThreeDAnimatedBackgroundState();
}

class _ThreeDAnimatedBackgroundState extends State<_ThreeDAnimatedBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(20, (i) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ThreeDPainter(_particles, _controller.value),
        );
      },
    );
  }
}

class _Particle {
  double x = math.Random().nextDouble();
  double y = math.Random().nextDouble();
  double z = math.Random().nextDouble();
  double size = math.Random().nextDouble() * 2 + 1;
  double speed = math.Random().nextDouble() * 0.002 + 0.001;
}

class _ThreeDPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ThreeDPainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.primary.withOpacity(0.15);
    final linePaint = Paint()..color = AppColors.primary.withOpacity(0.05)..strokeWidth = 0.5;

    for (var i = 0; i < particles.length; i++) {
        var p = particles[i];
        double currentZ = (p.z + progress) % 1.0;
        double scale = 1.0 / (currentZ + 0.5);
        
        double px = (p.x - 0.5) * scale * size.width + size.width / 2;
        double py = (p.y - 0.5) * scale * size.height + size.height / 2;
        
        canvas.drawCircle(Offset(px, py), p.size * scale, paint);

        // Connect nearby particles
        for (var j = i + 1; j < particles.length; j++) {
            var p2 = particles[j];
            double z2 = (p2.z + progress) % 1.0;
            double s2 = 1.0 / (z2 + 0.5);
            double px2 = (p2.x - 0.5) * s2 * size.width + size.width / 2;
            double py2 = (p2.y - 0.5) * s2 * size.height + size.height / 2;

            double dist = math.sqrt(math.pow(px - px2, 2) + math.pow(py - py2, 2));
            if (dist < 150) {
                linePaint.color = AppColors.primary.withOpacity((1.0 - dist / 150) * 0.1);
                canvas.drawLine(Offset(px, py), Offset(px2, py2), linePaint);
            }
        }
    }
  }
  @override
  bool shouldRepaint(_ThreeDPainter oldDelegate) => oldDelegate.progress != progress;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 0.5;

    const double step = 40;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class GradientBackground extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  
  const GradientBackground({
    super.key, 
    required this.child,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors ?? [
            AppColors.bgCream,
            AppColors.bgMain,
          ],
        ),
      ),
      child: child,
    );
  }
}

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? accentColor;
  
  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.elevated = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor?.withOpacity(0.3) ?? AppColors.cardBorder,
        ),
        boxShadow: elevated ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ] : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

class NeonButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const NeonButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(30),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}