import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/auth_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SchedulesScreen extends ConsumerStatefulWidget {
  const SchedulesScreen({super.key});

  @override
  ConsumerState<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends ConsumerState<SchedulesScreen> {
  List<Map<String, dynamic>> _myPlan = <Map<String, dynamic>>[];
  bool _isLoading = true;

  final Map<String, List<String>> _exerciseDb = {
    'Chest': ['Flat Barbell Bench Press', 'Incline Barbell Bench Press', 'Incline Dumbbell Press', 'Pec Deck Fly', 'Cable Crossover', 'Push-Ups', 'Chest Press Machine', 'Decline Bench Press', 'Svend Press', 'Incline Machine Press'],
    'Back': ['Deadlift', 'Pull-ups', 'Barbell Bent-Over Rows', 'Seated Cable Row', 'Lat Pulldown (Wide Grip)', 'T-Bar Row', 'Chest-Supported Row', 'Romanian Deadlift', 'Hyperextensions', 'Straight Arm Pulldown'],
    'Shoulders': ['Overhead Barbell Press', 'Dumbbell Lateral Raises', 'Face Pull', 'Arnold Press', 'Push Press', 'Reverse Pec Deck', 'Barbell Shrugs', 'Upright Rows', 'Front Raises', 'Cable Y-Raise'],
    'Legs': ['Barbell Squats', 'Leg Press', 'Bulgarian Split Squat', 'Hip Thrust', 'Lying Leg Curl', 'Standing Calf Raises', 'Lunges', 'Front Squats', 'Seated Leg Curl', 'Sumo Deadlift'],
    'Bicep': ['Incline Dumbbell Curl', 'Hammer Curl', 'Preacher Curl', 'Concentration Curl', 'Barbell Curl', 'Spider Curl', 'Reverse Curl', 'Wrist Curl'],
    'Tricep': ['Skull Crushers', 'Tricep Pushdown (Straight Bar)', 'Rope Pushdown', 'Close Grip Bench Press', 'Dips', 'Overhead Triceps Extension', 'Diamond Push-ups', 'Cable Kickbacks'],
    'Core': ['Weighted Crunch', 'Hanging Leg Raises', 'Plank', 'Russian Twists', 'Ab Wheel Rollout', 'Cable Crunch', 'Bicycle Crunch', 'Dead Bug'],
    'Cardio': ['Burpees', 'Jumping Jacks', 'Mountain Climbers', 'High Knees', 'Butt Kicks', 'Jump Rope', 'Squat Jumps', 'Skater Jumps'],
    'Full Body': ['Clean and Press', 'Thrusters', 'Man Makers', 'Devil Press', 'Power Clean', 'Snatch', 'Turkish Get-Up', 'Burpee Pull-Up'],
  };

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  void _loadPlan() {
    try {
      final saved = StorageService.get6DayPlan();
      if (saved.isEmpty) {
        _myPlan = List.generate(7, (i) => <String, dynamic>{'day': i + 1, 'title': 'REST DAY', 'exercises': <String>[], 'isRest': true});
      } else {
        _myPlan = saved;
      }
    } catch (e) {
      _myPlan = List.generate(7, (i) => <String, dynamic>{'day': i + 1, 'title': 'REST DAY', 'exercises': <String>[], 'isRest': true});
    }
    setState(() => _isLoading = false);
  }

  void _savePlan() async {
    await StorageService.save6DayPlan(_myPlan);
    ref.read(authProvider.notifier).syncUserData();
  }

  @override
  Widget build(BuildContext context) {
    final days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    return Scaffold(
      backgroundColor: Colors.white,
      body: AppBackground(
        useBlobs: true,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
              else
                Expanded(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    itemCount: _myPlan.length,
                    itemBuilder: (ctx, i) => _buildDayTile(i, days[i]),
                  ),
                ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
            child: Text('TRAINING ARCHITECT', style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 12),
          Text('Weekly Plan', style: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.textPrimary, height: 1)),
          const SizedBox(height: 8),
          Text('Engineer your physical evolution.', style: GoogleFonts.outfit(fontSize: 15, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDayTile(int idx, String dayName) {
    final data = _myPlan[idx];
    return _DayPerspectiveCard(
      dayName: dayName,
      title: data['title'] as String? ?? 'REST DAY',
      isRest: data['isRest'] as bool? ?? true,
      exercises: (data['exercises'] as List?)?.cast<String>() ?? [],
      onTap: () {
        if (AuthUtils.requireLogin(context: context, ref: ref)) return;
        _openSplitArchitect(idx);
      },
    ).animate(delay: (idx * 100).ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0);
  }

  void _openSplitArchitect(int idx) {
    String? selectedMuscle1;
    String? selectedMuscle2;
    String? activeTabMuscle;
    String splitType = 'Single'; 
    final dayData = _myPlan[idx];
    final currentExercises = (dayData['exercises'] as List?)?.cast<String>() ?? <String>[];
    List<String> tempExercises = List<String>.from(currentExercises);
    final titleCtl = TextEditingController(text: (dayData['title'] as String? ?? 'REST DAY') == 'REST DAY' ? '' : dayData['title']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setS) {
          Widget buildExerciseList(String muscle) {
            final list = _exerciseDb[muscle] ?? [];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(muscle.toUpperCase(), style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                const SizedBox(height: 12),
                ...list.map((ex) => CheckboxListTile(
                  value: tempExercises.contains(ex),
                  title: Text(ex, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 15, fontWeight: tempExercises.contains(ex) ? FontWeight.w700 : FontWeight.w500)),
                  activeColor: AppColors.primary,
                  onChanged: (v) => setS(() { if (v == true) tempExercises.add(ex); else tempExercises.remove(ex); }),
                )),
              ],
            );
          }

          return Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            padding: EdgeInsets.fromLTRB(24, 32, 24, MediaQuery.of(ctx).viewInsets.bottom + 120), // Extra padding for bottom nav bar
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('SPLIT ARCHITECT', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                   const SizedBox(height: 24),
                   TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'WORKOUT TITLE')),
                   const SizedBox(height: 32),
                   Row(
                     children: ['Single', 'Double'].map((t) => GestureDetector(
                       onTap: () => setS(() { splitType = t; if (t == 'Single') selectedMuscle2 = null; }),
                       child: Container(
                         margin: const EdgeInsets.only(right: 12),
                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                         decoration: BoxDecoration(color: splitType == t ? AppColors.primary : AppColors.bgSoft, borderRadius: BorderRadius.circular(12)),
                         child: Text(t, style: GoogleFonts.outfit(color: splitType == t ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700)),
                       ),
                     )).toList(),
                   ),
                   const SizedBox(height: 32),
                   Wrap(
                     spacing: 12, runSpacing: 12,
                     children: _exerciseDb.keys.map((m) {
                       final isSel = selectedMuscle1 == m || selectedMuscle2 == m;
                       return GestureDetector(
                         onTap: () => setS(() {
                           if (isSel) { if (selectedMuscle1 == m) selectedMuscle1 = null; else selectedMuscle2 = null; }
                           else { if (selectedMuscle1 == null) selectedMuscle1 = m; else if (splitType == 'Double') selectedMuscle2 = m; }
                           activeTabMuscle = m;
                           
                           // Auto-update title based on selection
                           List<String> selected = [];
                           if (selectedMuscle1 != null) selected.add(selectedMuscle1!);
                           if (selectedMuscle2 != null) selected.add(selectedMuscle2!);
                           if (selected.isNotEmpty) {
                             titleCtl.text = selected.join(" & ") + " Workout";
                           } else {
                             titleCtl.text = '';
                           }
                         }),
                         child: Container(
                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                           decoration: BoxDecoration(color: isSel ? AppColors.primary.withOpacity(0.1) : AppColors.bgSoft, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSel ? AppColors.primary : Colors.transparent)),
                           child: Text(m, style: GoogleFonts.outfit(color: isSel ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w700)),
                         ),
                       );
                     }).toList(),
                   ),
                   if (activeTabMuscle != null) buildExerciseList(activeTabMuscle!),
                   const SizedBox(height: 32),
                   ElevatedButton(
                     onPressed: () {
                        setState(() { _myPlan[idx] = {'day': idx + 1, 'title': titleCtl.text.isEmpty ? 'REST DAY' : titleCtl.text, 'exercises': tempExercises, 'isRest': titleCtl.text.isEmpty && tempExercises.isEmpty}; });
                        _savePlan();
                        Navigator.pop(ctx);
                     },
                     style: ElevatedButton.styleFrom(
                       backgroundColor: AppColors.primary,
                       foregroundColor: Colors.white,
                       minimumSize: const Size(double.infinity, 60),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                     ),
                     child: Text('SAVE PLAN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16)),
                   ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DayPerspectiveCard extends StatefulWidget {
  final String dayName;
  final String title;
  final bool isRest;
  final List<String> exercises;
  final VoidCallback onTap;

  const _DayPerspectiveCard({required this.dayName, required this.title, required this.isRest, required this.exercises, required this.onTap});

  @override
  State<_DayPerspectiveCard> createState() => _DayPerspectiveCardState();
}

class _DayPerspectiveCardState extends State<_DayPerspectiveCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        margin: const EdgeInsets.only(bottom: 24),
        child: Stack(
          children: [
            Positioned(
              bottom: 0, left: 12, right: 12,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isRest ? Colors.black.withOpacity(0.06) : AppColors.primary.withOpacity(0.15),
                      blurRadius: _isPressed ? 10 : 25,
                      offset: Offset(0, _isPressed ? 5 : 15),
                    ),
                  ],
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(_isPressed ? 0.02 : 0.04)..scale(_isPressed ? 0.98 : 1.0),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), border: Border.all(color: widget.isRest ? Colors.white : AppColors.primary.withOpacity(0.3), width: 1.5)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.dayName, style: GoogleFonts.outfit(color: widget.isRest ? AppColors.textMuted : AppColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(widget.title, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
                          if (!widget.isRest && widget.exercises.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: widget.exercises.take(3).map((e) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(10)), child: Text(e, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700)))).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: widget.isRest ? AppColors.bgSoft : AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(widget.isRest ? Icons.add_rounded : Icons.edit_calendar_rounded, color: widget.isRest ? AppColors.textMuted : AppColors.primary, size: 26)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
