import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../core/services/storage_service.dart';

class WorkoutSummaryScreen extends StatelessWidget {
  final String exercise;
  final int reps;
  final String duration;
  final double accuracy;
  final int calories;

  const WorkoutSummaryScreen({
    super.key,
    required this.exercise,
    required this.reps,
    required this.duration,
    this.accuracy = 0,
    this.calories = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate sets based on reps and user preference
    final int repsPerSet = StorageService.getRepsPerSet();
    final int calculatedSets = reps > 0 ? (reps / repsPerSet).ceil() : 0;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Celebration Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 48),
                ),
                const SizedBox(height: 24),
                
                Text('SESSION COMPLETE', 
                  style: GoogleFonts.outfit(color: AppColors.primary, fontSize: 13, letterSpacing: 4, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(exercise.toUpperCase(), 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 36, fontWeight: FontWeight.w800)),
                const SizedBox(height: 40),

                // Main Stats Grid
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.cardBorder, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildStatItem('REPS', reps.toString(), Icons.repeat_rounded),
                          _buildDivider(),
                          _buildStatItem('SETS', calculatedSets.toString(), Icons.layers_rounded),
                          _buildDivider(),
                          _buildStatItem('TIME', duration, Icons.timer_rounded),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _buildResultTile(
                              'FORM GRADE', 
                              _getGrade(accuracy), 
                              '${accuracy.round()}% ACCURACY',
                              Colors.indigoAccent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildResultTile(
                              'CALORIES', 
                              calories.toString(), 
                              'KCAL BURNED',
                              AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Recovery Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.bgSoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RECOVERY TIP', 
                              style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            const SizedBox(height: 4),
                            Text(_getRecoveryTip(exercise), 
                              style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Footer Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.4),
                    ),
                    onPressed: () {
                      final category = _getExerciseCategory(exercise);
                      context.go('/exercises?category=$category');
                    },
                    child: Text('FINISH SESSION', 
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: AppColors.bgSoft);
  }

  Widget _buildResultTile(String label, String value, String subValue, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.outfit(color: accentColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 12),
          Text(value, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.w900, height: 1.1)),
          const SizedBox(height: 8),
          Text(subValue, 
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  String _getRecoveryTip(String exercise) {
    final lower = exercise.toLowerCase();
    if (lower.contains('push-up') || lower.contains('chest')) {
      return 'Perform a chest stretch by placing your arm against a wall at 90 degrees and rotating away slowly.';
    } else if (lower.contains('squat') || lower.contains('leg')) {
      return 'Stretch your quads: stand on one leg and pull your other heel toward your glutes for 30s.';
    } else if (lower.contains('plank') || lower.contains('core')) {
      return 'Try the Cobra stretch: lie face down and push your upper body up with your hands.';
    }
    return 'Drink at least 500ml of water and take a 5-minute light walk to help muscle recovery.';
  }

  String _getGrade(double accuracy) {
    if (accuracy >= 90) return 'S';
    if (accuracy >= 80) return 'A';
    if (accuracy >= 70) return 'B';
    if (accuracy >= 50) return 'C';
    return 'D';
  }

  String _getExerciseCategory(String exercise) {
    final lower = exercise.toLowerCase();
    
    // Chest
    if (lower.contains('push-up') || lower.contains('bench') || lower.contains('press') || 
        lower.contains('chest') || lower.contains('fly') || lower.contains('crossover') || 
        lower.contains('pec deck')) {
       if (lower.contains('shoulder') || lower.contains('overhead') || lower.contains('arnold')) {
         return 'Shoulders';
       }
       return 'Chest';
    }
    
    // Back
    if (lower.contains('pull-up') || lower.contains('pulldown') || lower.contains('row') || 
        lower.contains('deadlift') || lower.contains('chin-up') || lower.contains('back')) {
      return 'Back';
    }
    
    // Shoulders
    if (lower.contains('shoulder') || lower.contains('press') || lower.contains('lateral') || 
        lower.contains('raise') || lower.contains('shrug') || lower.contains('face pull')) {
      return 'Shoulders';
    }

    // Biceps / Arms
    if (lower.contains('curl') || lower.contains('bicep') || lower.contains('wrist')) {
      return 'Biceps';
    }
    
    // Triceps
    if (lower.contains('tricep') || lower.contains('extension') || lower.contains('pushdown') || 
        lower.contains('kickback') || lower.contains('dip') || lower.contains('skull crusher')) {
      return 'Triceps';
    }
    
    // Legs
    if (lower.contains('squat') || lower.contains('leg') || lower.contains('lunge') || 
        lower.contains('calf') || lower.contains('thrust') || lower.contains('glute')) {
      return 'Legs';
    }
    
    // Abs
    if (lower.contains('crunch') || lower.contains('sit-up') || lower.contains('abs') || 
        lower.contains('plank') || lower.contains('twist') || lower.contains('leg raise')) {
      return 'Abs';
    }

    // Full Body
    if (lower.contains('clean') || lower.contains('snatch') || lower.contains('burpee') || 
        lower.contains('get-up') || lower.contains('thruster')) {
      return 'Full Body';
    }

    // Default Fallback
    return 'Chest';
  }
}
