import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../main.dart' show navigatorKey;
import '../../core/theme/app_colors.dart';
import '../../features/coach/presentation/widgets/coach_chat_widget.dart';
import '../utils/auth_utils.dart';

class FloatingAICoach extends ConsumerStatefulWidget {
  const FloatingAICoach({super.key});

  @override
  ConsumerState<FloatingAICoach> createState() => _FloatingAICoachState();
}

class _FloatingAICoachState extends ConsumerState<FloatingAICoach> {
  Offset _position = const Offset(0, 0);
  bool _isInitialized = false;
  bool _isDragging = false;
  bool _showGreeting = true;
  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();
    _startGreetingTimer();
  }

  void _startGreetingTimer() {
    _greetingTimer?.cancel();
    _greetingTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showGreeting = false);
      }
    });
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final size = MediaQuery.of(context).size;
      // Adjusted position to be lower right, matching the second image
      _position = Offset(size.width - 70, size.height - 150);
      _isInitialized = true;
    }
  }

  void _openChat() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    
    AuthUtils.requireLogin(
      context: ctx,
      ref: ref,
      onAuthenticated: () {
        showDialog(
          context: ctx,
          barrierColor: Colors.black54,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 80),
            child: const CoachChatWidget(isDialog: true),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) => setState(() => _isDragging = true),
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          setState(() => _isDragging = false);
          final size = MediaQuery.of(context).size;
          double newX = _position.dx;
          double newY = _position.dy;
          if (newX < 20) newX = 20;
          if (newX > size.width - 60) newX = size.width - 60;
          if (newY < 50) newY = 50;
          if (newY > size.height - 120) newY = size.height - 120;
          setState(() => _position = Offset(newX, newY));
        },
        onTap: _openChat,
        child: _buildCoachIcon(isDragging: _isDragging),
      ),
    );
  }

  Widget _buildCoachIcon({bool isDragging = false}) {
    const coachColor = AppColors.primary;
    
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(Icons.smart_toy_rounded, color: Colors.black, size: 24),
          ),
          Positioned(
            top: 2, right: 2,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1.5)),
            ),
          ),
          if (!isDragging)
            Positioned(
              right: 70, top: 10,
              child: AnimatedOpacity(
                opacity: _showGreeting ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Hi! Ask me anything 👋', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
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
