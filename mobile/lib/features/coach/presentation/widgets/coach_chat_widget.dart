import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/storage_service.dart';

class CoachChatWidget extends StatefulWidget {
  final bool isBottomSheet;
  final bool isDialog;
  const CoachChatWidget({super.key, this.isBottomSheet = false, this.isDialog = false});

  @override
  State<CoachChatWidget> createState() => _CoachChatWidgetState();
}

class _CoachChatWidgetState extends State<CoachChatWidget> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'coach',
      'text': 'Hey! I\'m your FitCoach AI. How can I help you today?'
    });
  }

  Future<void> _send() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) return;
    _msgController.clear();
    setState(() {
      _messages.add({'role': 'user', 'text': msg});
      _loading = true;
    });
    _scrollToBottom();

    final profile = StorageService.getProfile();
    final result = await ApiService.chat(msg, profile, _messages);
    setState(() {
      _messages.add({'role': 'coach', 'text': result['response'] ?? 'I apologize, I am having trouble connecting right now.'});
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: widget.isDialog ? 500 : (widget.isBottomSheet ? MediaQuery.of(context).size.height * 0.8 : double.infinity),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -10))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.isBottomSheet || widget.isDialog) 
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: AppColors.primary,
              child: Row(
                children: [
                  Expanded(
                    child: Text('FITCOACH AI', 
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i == _messages.length) return _typingBubble();
                final m = _messages[i];
                final isCoach = m['role'] == 'coach';
                return _messageBubble(m['text'], isCoach);
              },
            ),
          ),
          
          _inputBar(),
        ],
      ),
    );
  }

  Widget _messageBubble(String text, bool isCoach) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isCoach ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isCoach) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCoach ? AppColors.bgSoft : AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isCoach ? 4 : 20),
                  bottomRight: Radius.circular(isCoach ? 20 : 4),
                ),
                boxShadow: [
                  if (!isCoach) BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Text(text,
                  style: GoogleFonts.outfit(
                    color: isCoach ? AppColors.textPrimary : Colors.white, 
                    fontSize: 14, 
                    fontWeight: isCoach ? FontWeight.w500 : FontWeight.w600,
                    height: 1.4,
                  )),
            ),
          ),
          if (!isCoach) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.bgSoft,
              child: Icon(Icons.person_rounded, size: 14, color: AppColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.smart_toy_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSoft, 
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [ _dot(0), _dot(150), _dot(300) ]),
        ),
      ],
    );
  }

  Widget _dot(int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delay),
      builder: (_, v, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primary.withOpacity(0.4 + 0.6 * v))),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Ask your AI coach...',
                hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 14),
                filled: true,
                fillColor: AppColors.bgSoft,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _loading ? null : _send,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
