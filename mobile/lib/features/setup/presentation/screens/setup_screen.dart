import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_background.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _currentStep = 1;
  final _nameCtl = TextEditingController();
  final _weightCtl = TextEditingController();
  final _heightCtl = TextEditingController();
  final _ageCtl = TextEditingController();
  String? _avatarUrl;
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        final String? name = user.userMetadata?['full_name'] ?? user.userMetadata?['name'];
        if (name != null && _nameCtl.text.isEmpty) {
          setState(() {
            _nameCtl.text = name;
            _avatarUrl = user.userMetadata?['avatar_url'];
          });
        }
      }
    });
  }
  
  String _gender = 'Male';
  String _goal = 'Aggressive Cut';
  String _activityLevel = 'Beginner';

  void _nextStep() {
    if (_currentStep == 1) {
      if (_nameCtl.text.trim().isEmpty) {
        _showSnack('Please enter your name');
        return;
      }
    }
    if (_currentStep == 2) {
      final h = _heightCtl.text.trim();
      final w = _weightCtl.text.trim();
      final a = _ageCtl.text.trim();
      if (h.isEmpty || w.isEmpty || a.isEmpty) {
        _showSnack('Please fill in all physical stats');
        return;
      }
      
      final height = double.tryParse(h);
      final weight = double.tryParse(w);
      final age = int.tryParse(a);
      
      if (height == null || weight == null || age == null) {
        _showSnack('Please enter valid numeric values');
        return;
      }
      
      if (age < 13 || age > 100) {
        _showSnack('Age must be between 13 and 100');
        return;
      }
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final profile = {
        'name': _nameCtl.text.trim(),
        'email': ref.read(authProvider).user?.email,
        'gender': _gender,
        'age': int.tryParse(_ageCtl.text) ?? 25,
        'height': double.tryParse(_heightCtl.text) ?? 175,
        'weight': double.tryParse(_weightCtl.text) ?? 70,
        'goal': _goal,
        'activity_level': _activityLevel,
      };
      
      await ref.read(authProvider.notifier).saveProfile(profile);
      
      if (mounted && ref.read(authProvider).error == null) {
        context.go('/');
      }
    } catch (e) {
      _showSnack('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.error != null && previous?.error != next.error) {
        _showSnack(next.error!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FitCoach AI',
                              style: GoogleFonts.outfit(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Profile Setup',
                              style: GoogleFonts.outfit(
                                color: AppColors.textPrimary,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_currentStep/4',
                            style: GoogleFonts.outfit(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Progress Bar
                    _buildProgressBar(),
                  ],
                ),
              ).animate().fadeIn().slideY(begin: -0.1),
              
              const SizedBox(height: 40),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedSwitcher(
                    duration: 400.ms,
                    child: _buildCurrentStep(),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Bottom Nav
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_currentStep > 1)
                      GestureDetector(
                        onTap: _prevStep,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.cardBorder),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                )
                            ]
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                        ),
                      ),
                    if (_currentStep > 1) const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                          child: _isSaving
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                            : Text(
                                _currentStep == 4 ? 'GET STARTED' : 'CONTINUE',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Stack(
      children: [
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.bgSoft,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        AnimatedContainer(
          duration: 400.ms,
          height: 8,
          width: (MediaQuery.of(context).size.width - 48) * (_currentStep / 4),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1: return _step1();
      case 2: return _step2();
      case 3: return _step3();
      case 4: return _step4();
      default: return Container();
    }
  }

  Widget _step1() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.bgSoft,
                backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                child: _avatarUrl == null ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 36) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('NICE TO MEET YOU', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
                  Text('Tell us about yourself', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _label('YOUR FULL NAME'),
        _textField(_nameCtl, 'e.g. John Doe', Icons.person_outline),
        const SizedBox(height: 32),
        _label('IDENTIFY AS'),
        Row(
          children: [
            Expanded(child: _pill('♂️ Male', _gender == 'Male', () => setState(() => _gender = 'Male'))),
            const SizedBox(width: 14),
            Expanded(child: _pill('♀️ Female', _gender == 'Female', () => setState(() => _gender = 'Female'))),
          ],
        ),
      ],
    );
  }

  Widget _step2() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THE BASICS', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
        Text('Physical Stats', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 40),
        _label('AGE (YEARS)'),
        _textField(_ageCtl, 'e.g. 24', Icons.calendar_today_rounded, isNumeric: true),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('HEIGHT (CM)'),
                  _textField(_heightCtl, '175', Icons.height_rounded, isNumeric: true),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('WEIGHT (KG)'),
                  _textField(_weightCtl, '70', Icons.monitor_weight_outlined, isNumeric: true),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _step3() {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('GOAL SETTING', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
        Text('Target Outcome', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 32),
        _selectionCard('Aggressive Cut', 'Intensive fat loss & definition', '🔥', _goal == 'Aggressive Cut', () => setState(() => _goal = 'Aggressive Cut')),
        _selectionCard('Fat Loss', 'Efficiently burn body fat', '🏃🏻‍♂️', _goal == 'Fat Loss', () => setState(() => _goal = 'Fat Loss')),
        _selectionCard('Body Recomposition', 'Gain muscle and lose fat', '⚡', _goal == 'Body Recomposition', () => setState(() => _goal = 'Body Recomposition')),
        _selectionCard('Maintenance', 'Hold current weight & health', '🏅', _goal == 'Maintenance', () => setState(() => _goal = 'Maintenance')),
        _selectionCard('Lean Bulk', 'Steady muscle gain with minimal fat', '📈', _goal == 'Lean Bulk', () => setState(() => _goal = 'Lean Bulk')),
        _selectionCard('Aggressive Bulk', 'Maximum muscle growth & strength', '💪', _goal == 'Aggressive Bulk', () => setState(() => _goal = 'Aggressive Bulk')),
      ],
    );
  }

  Widget _step4() {
    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('EXPERIENCE', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.5)),
        Text('Activity Level', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 32),
        _selectionCard('Beginner', 'New to structured training', '🌱', _activityLevel == 'Beginner', () => setState(() => _activityLevel = 'Beginner')),
        _selectionCard('Moderate', 'Trained for 1-2 years', '🔰', _activityLevel == 'Moderate', () => setState(() => _activityLevel = 'Moderate')),
        _selectionCard('Advanced', 'Heavy lifter / Athlete', '🥊', _activityLevel == 'Advanced', () => setState(() => _activityLevel = 'Advanced')),
        _selectionCard('Sedentary', 'Minimal physical activity', '🛋️', _activityLevel == 'Sedentary', () => setState(() => _activityLevel = 'Sedentary')),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
  );

  Widget _textField(TextEditingController ctl, String hint, IconData icon, {bool isNumeric = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
            )
        ]
      ),
      child: TextField(
        controller: ctl,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: AppColors.textMuted.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: AppColors.primary.withOpacity(0.6), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _pill(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.cardBorder, width: 2),
            boxShadow: isSelected ? [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                )
            ] : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                )
            ]
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectionCard(String title, String sub, String emoji, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: 300.ms,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.cardBorder,
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.black.withOpacity(0.04),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 2),
                    Text(sub, style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

