import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../shared/widgets/app_background.dart';
import '../../../../shared/utils/auth_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/image_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic> _profile = {};
  List<dynamic> _history = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _profile = ref.read(authProvider).profile ?? StorageService.getProfile();
    _history = StorageService.getWorkoutHistory();
  }

  Future<void> _pickImage() async {
    if (AuthUtils.requireLogin(context: context, ref: ref)) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 50,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      // Update Profile immediately with Base64 (Saves directly to DB)
      final updatedProfile = Map<String, dynamic>.from(_profile);
      updatedProfile['avatar_url'] = dataUrl;

      final messenger = ScaffoldMessenger.maybeOf(context);
      await ref.read(authProvider.notifier).saveProfile(updatedProfile);

      if (mounted && messenger != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to update image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    _profile = authState.profile ?? _profile;
    
    final name = _profile['name'] ?? 'Gym Warrior';
    final email = authState.user?.email ?? 'Athlete';
    final goal = (_profile['goal'] ?? 'Fitness');
    final level = _profile['activity_level'] ?? 'Intermediate';
    final weight = _profile['weight'] ?? '--';
    final height = _profile['height'] ?? '--';
    final age = _profile['age'] ?? '--';

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('My Profile', 
          style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 24)),
        centerTitle: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              children: [
                // Avatar + Name
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _isUploading ? null : _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                      boxShadow: [
                        BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 20, spreadRadius: 5)
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.bgSoft,
                          backgroundImage: ImageUtils.getAvatarImage(_profile['avatar_url']),
                          child: _profile['avatar_url'] == null 
                            ? const Text('💪', style: TextStyle(fontSize: 48)) 
                            : null,
                        ),
                        if (_isUploading)
                          const CircularProgressIndicator(color: AppColors.primary),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(name,
                    style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(email, 
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(goal.toString().toUpperCase(), 
                    style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)),
                ),
                const SizedBox(height: 40),

                // Stats Section
                _buildStatsSection(weight, height, age, level),

                const SizedBox(height: 24),
                _buildHowItWorks(),

                const SizedBox(height: 40),
                // Action Buttons
                _buildActionButtons(context),
                
                const SizedBox(height: 100), // Bottom nav space
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(dynamic weight, dynamic height, dynamic age, dynamic level) {
    return Column(
      children: [
        Row(
          children: [
            _statCard('Weight', '$weight', 'kg'),
            const SizedBox(width: 16),
            _statCard('Height', '$height', 'cm'),
          ],
        ),
        const SizedBox(height: 16),
        _statCard('Age', '$age', 'yrs', isFullWidth: true),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity Level', 
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(level.toString(), 
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
              const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 32),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _repsPerSetCard(),
        const SizedBox(height: 16),
        _voiceAssistantCard(),
      ],
    );
  }


  Widget _voiceAssistantCard() {
    bool enabled = StorageService.isVoiceAssistantEnabled();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VOICE ASSISTANT', 
                    style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(enabled ? 'Enabled' : 'Disabled', 
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                ],
              ),
              Switch.adaptive(
                value: enabled,
                activeColor: AppColors.primary,
                onChanged: (val) async {
                  await StorageService.setVoiceAssistantEnabled(val);
                  setState(() {});
                },
              ),
            ],
          ),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Voice commands and feedback are inactive.', 
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('HOW IT WORKS', 
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Your AI Coach handles everything hands-free! It uses advanced speech recognition to follow your commands and provides real-time voice motivation.',
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          Text('VOICE COMMANDS:', 
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 1)),
          const SizedBox(height: 12),
          _commandItem('“Start” or “Go”', 'Begins the exercise detection'),
          _commandItem('“Pause” or “Hold”', 'Pauses the detection'),
          _commandItem('“Record”', 'Starts/Stops video recording'),
          _commandItem('“Finish” or “Done”', 'Completes and saves workout'),
          _commandItem('“Flip”', 'Switches between cameras'),
        ],
      ),
    );
  }

  Widget _commandItem(String cmd, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cmd, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text('— $desc', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  Widget _repsPerSetCard() {
    int reps = StorageService.getRepsPerSet();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reps calculation per SET', 
                style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text('$reps Reps = 1 Set', 
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            ],
          ),
          Row(
            children: [
              _circleButton(Icons.remove_rounded, () async {
                if (reps > 1) {
                  await StorageService.saveRepsPerSet(reps - 1);
                  setState(() {});
                }
              }),
              const SizedBox(width: 12),
              _circleButton(Icons.add_rounded, () async {
                if (reps < 50) {
                  await StorageService.saveRepsPerSet(reps + 1);
                  setState(() {});
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  Widget _statCard(String label, String value, String unit, {bool isFullWidth = false}) {
    final card = Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, 
              style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, 
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(width: 4),
                Text(unit, 
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
    );

    return isFullWidth ? card : Expanded(child: card);
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              if (AuthUtils.requireLogin(context: context, ref: ref)) return;
              context.go('/setup');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_rounded, size: 20),
                const SizedBox(width: 12),
                Text('EDIT PROFILE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _confirmLogout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red[600],
              side: BorderSide(color: Colors.red[100]!, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.red[50]?.withOpacity(0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, size: 20),
                const SizedBox(width: 12),
                Text('LOGOUT', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
            }, 
            child: Text('LOGOUT', style: GoogleFonts.outfit(color: Colors.red[600], fontWeight: FontWeight.w900))
          ),
        ],
      ),
    );
  }
}
