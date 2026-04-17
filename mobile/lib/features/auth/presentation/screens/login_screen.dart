import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_background.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Graceful request at login
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleGoogleLogin() async {
    await ref.read(authProvider.notifier).signInWithGoogle();
  }

  void _handleEmailLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnack("Please enter both email and password.");
      return;
    }

    if (_isSignUp) {
      await ref.read(authProvider.notifier).signUpWithEmail(email, password);
    } else {
      await ref.read(authProvider.notifier).signInWithEmail(email, password);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                _buildHeader(),
                const SizedBox(height: 50),
                _buildAuthToggle(),
                const SizedBox(height: 32),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildPasswordField(),
                const SizedBox(height: 32),
                _buildLoginButton(authState),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleButton(authState),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => ref.read(authProvider.notifier).continueAsGuest(),
                  child: Text(
                    'Continue as Guest',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildFooterText(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return RepaintBoundary(
      child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2),
          ),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon.png', width: 48, height: 48, fit: BoxFit.contain),
            ),
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        Text(
          _isSignUp ? 'Join FitCoach' : 'Welcome Back',
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp ? 'Start your fitness journey today' : 'Continue your transformation',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ));
  }

  Widget _buildAuthToggle() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          _buildToggleTab('Login', !_isSignUp),
          _buildToggleTab('Sign Up', _isSignUp),
        ],
      ),
    );
  }

  Widget _buildToggleTab(String title, bool isActive) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isSignUp = title == 'Sign Up'),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive ? [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ] : null,
          ),
          margin: const EdgeInsets.all(4),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: const InputDecoration(
        hintText: 'Email Address',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        hintText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  Widget _buildLoginButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : _handleEmailLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shadowColor: AppColors.primary.withOpacity(0.4),
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: authState.isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            : Text(_isSignUp ? 'CREATE ACCOUNT' : 'LOGIN'),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: GoogleFonts.outfit(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildGoogleButton(AuthState authState) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: authState.isLoading ? null : _handleGoogleLogin,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata_rounded, size: 28),
            const SizedBox(width: 8),
            Text('Continue with Google', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterText() {
    return Text(
      'By continuing, you agree to our Terms and Privacy Policy.',
      textAlign: TextAlign.center,
      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMuted),
    );
  }
}

