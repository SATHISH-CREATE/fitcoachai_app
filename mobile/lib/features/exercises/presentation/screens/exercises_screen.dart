import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/exercise_data_service.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/utils/auth_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  final String category;
  const ExercisesScreen({super.key, required this.category});
  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  Category? _category;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final category = await ExerciseDataService.getCategory(widget.category);
    setState(() {
      _category = category;
      _loading = false;
    });
  }

  void _playDemoVideo(String url) {
    String? videoId;
    if (url.contains('v=')) {
      videoId = url.split('v=')[1];
      final ampersandPosition = videoId.indexOf('&');
      if (ampersandPosition != -1) videoId = videoId.substring(0, ampersandPosition);
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/')[1];
      final questionMarkPosition = videoId.indexOf('?');
      if (questionMarkPosition != -1) videoId = videoId.substring(0, questionMarkPosition);
    }

    if (videoId == null) return;
    showDialog(context: context, builder: (context) => _DemoVideoDialog(videoId: videoId!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => context.canPop() ? context.pop() : context.go('/library'),
        ),
        title: Text(
          (_category?.name ?? widget.category).toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _category == null
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                          child: Text(
                            'Choose an exercise to start your AI-guided session.',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_category!.subcategories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(48),
                            child: Center(child: Text('No exercises found in this category')),
                          )
                        else
                          ..._category!.subcategories.map((sub) => _SubcategorySection(
                                key: ValueKey(sub.title),
                                title: sub.title,
                                exercises: sub.exercises,
                                onTrain: (exercise) {
                                  if (AuthUtils.requireLogin(context: context, ref: ref)) return;
                                  context.push('/warmup?exercise=${Uri.encodeComponent(exercise.name)}');
                                },
                                onDemo: _playDemoVideo,
                              )),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 80, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('Category not found', 
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/library'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Back to Library'),
          )
        ],
      ),
    );
  }
}

class _SubcategorySection extends StatelessWidget {
  final String title;
  final List<Exercise> exercises;
  final Function(Exercise) onTrain;
  final Function(String) onDemo;

  const _SubcategorySection({
    super.key,
    required this.title,
    required this.exercises,
    required this.onTrain,
    required this.onDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: exercises.asMap().entries.map<Widget>((entry) {
              final index = entry.key;
              final exercise = entry.value;
              return _ExerciseCard(
                exercise: exercise,
                index: index,
                onTrain: () => onTrain(exercise),
                onDemo: () => onDemo(exercise.videoUrl),
              ).animate(delay: (index * 100).ms).fadeIn(duration: 500.ms).slideX(begin: 0.1, end: 0);
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  final Exercise exercise;
  final int index;
  final VoidCallback onTrain;
  final VoidCallback onDemo;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.onTrain,
    required this.onDemo,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTrain,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(bottom: 24),
        child: Stack(
          children: [
            // Depth Shadow Layer
            Positioned(
              bottom: 0, left: 10, right: 10,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isPressed ? 0.05 : 0.1),
                      blurRadius: _isPressed ? 10 : 25,
                      offset: Offset(0, _isPressed ? 5 : 15),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main Card 3D Transform
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_isPressed ? 0.02 : 0.05)
                ..scale(_isPressed ? 0.98 : 1.0),
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildExerciseImage(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.exercise.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.exercise.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _actionButton(
                                      onTap: widget.onTrain, 
                                      label: 'TRAIN', 
                                      isPrimary: true
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  _actionButton(
                                    onTap: widget.onDemo, 
                                    label: 'DEMO', 
                                    isPrimary: false
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildExerciseImage() {
    return Container(
      width: 110,
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(5, 0))
        ],
      ),
      child: Image.network(
        widget.exercise.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.fitness_center_rounded, color: AppColors.textMuted, size: 32),
        ),
      ),
    );
  }

  Widget _actionButton({required VoidCallback onTap, required String label, required bool isPrimary}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isPrimary ? null : Border.all(color: AppColors.cardBorder, width: 1.5),
          boxShadow: isPrimary ? [
            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ] : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isPrimary ? Colors.white : AppColors.textSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _DemoVideoDialog extends StatefulWidget {
  final String videoId;
  const _DemoVideoDialog({super.key, required this.videoId});

  @override
  State<_DemoVideoDialog> createState() => _DemoVideoDialogState();
}

class _DemoVideoDialogState extends State<_DemoVideoDialog> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..loadRequest(Uri.parse('https://www.youtube.com/embed/${widget.videoId}'));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        clipBehavior: Clip.antiAlias,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * 9/16,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
