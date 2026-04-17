import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonStyle { primary, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = AppButtonStyle.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getHeight() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 40;
      case AppButtonSize.medium:
        return 52;
      case AppButtonSize.large:
        return 60;
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 13;
      case AppButtonSize.medium:
        return 15;
      case AppButtonSize.large:
        return 17;
    }
  }

  Color _getTextColor() {
    switch (widget.style) {
      case AppButtonStyle.primary:
        return Colors.black;
      case AppButtonStyle.secondary:
        return Colors.black;
      case AppButtonStyle.danger:
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  Widget _buildButton() {
    final content = widget.isLoading ? _buildLoading() : _buildContent();

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() => _isPressed = false);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: _getHeight(),
          width: widget.isFullWidth ? double.infinity : null,
          decoration: _getDecoration(),
          child: Center(child: content),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: _getTextColor(),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: _getIconSize(), color: _getTextColor()),
          const SizedBox(width: 10),
          Text(widget.label, style: TextStyle(color: _getTextColor(), fontSize: _getFontSize(), fontWeight: FontWeight.w700)),
        ],
      );
    }
    return Text(widget.label, style: TextStyle(color: _getTextColor(), fontSize: _getFontSize(), fontWeight: FontWeight.w700));
  }

  BoxDecoration _getDecoration() {
    switch (widget.style) {
      case AppButtonStyle.primary:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FF99), Color(0xFFD9FF4D), Color(0xFFBFFF00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_isPressed ? 0.6 : 0.4),
              blurRadius: _isPressed ? 8 : 20,
              offset: Offset(0, _isPressed ? 2 : 6),
            ),
          ],
        );
      case AppButtonStyle.secondary:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FF99), Color(0xFFBFFF00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case AppButtonStyle.danger:
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5B4D), Color(0xFFFF3B30)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        );
      case AppButtonStyle.outline:
        return BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.separator),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );
      default:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildButton();
  }
}

class AppIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = 48,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? AppColors.cardBgLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.separator),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, color: widget.iconColor ?? AppColors.textMain, size: widget.size * 0.5),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
