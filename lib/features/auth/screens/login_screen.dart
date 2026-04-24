import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

import '../../../core/controllers/auth_controller.dart';
import '../../../core/theme/app_theme.dart';

/// Phone + Password login & registration screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final AuthController authController = Get.find<AuthController>();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  XFile? _imageFile;
  Uint8List? _imageBytes;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // ─── Background ───────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF0D1B2A), const Color(0xFF1B263B), const Color(0xFF0D1B2A)]
                    : [const Color(0xFF667EEA), const Color(0xFF764BA2)],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.blue.withOpacity(0.1),
            ),
          ),

          // ─── Content ──────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 12),
                    Text(
                      'Box Cricket',
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Professional League Management',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Glass Card ───────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isDark ? 0.05 : 0.1),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSignUp ? 'Create Account' : 'Welcome Back',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isSignUp
                                      ? 'Join the league and start playing.'
                                      : 'Sign in to continue scoring.',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // ── Sign-up only fields ──────
                                if (_isSignUp) ...[
                                  _buildImagePicker(isDark),
                                  const SizedBox(height: 20),
                                  _buildTextField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    icon: Icons.person_outline,
                                    isDark: isDark,
                                    textCapitalization: TextCapitalization.words,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Name is required';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // ── Phone field ──────────────
                                _buildPhoneField(isDark),
                                const SizedBox(height: 16),

                                // ── Password field ───────────
                                _buildTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  isDark: isDark,
                                  obscureText: _obscurePassword,
                                  onToggleVisibility: () =>
                                      setState(() => _obscurePassword = !_obscurePassword),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return 'Password is required';
                                    if (_isSignUp && v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 28),
                                _buildSubmitButton(),
                                const SizedBox(height: 20),

                                // ── Toggle Sign In / Sign Up ──
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isSignUp = !_isSignUp;
                                        _formKey.currentState?.reset();
                                        authController.clearError();
                                      });
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        text: _isSignUp
                                            ? 'Already have an account? '
                                            : "Don't have an account? ",
                                        style: GoogleFonts.inter(
                                            color: Colors.white.withOpacity(0.6)),
                                        children: [
                                          TextSpan(
                                            text: _isSignUp ? 'Sign In' : 'Sign Up',
                                            style: const TextStyle(
                                              color: AppTheme.primaryGreen,
                                              fontWeight: FontWeight.bold,
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
    );
  }

  // ─── Widgets ─────────────────────────────────────────────

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5),
        ],
      ),
      child: const Icon(Icons.sports_cricket, size: 50, color: AppTheme.primaryGreen),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.phone_outlined,
                  color: Colors.white.withOpacity(0.5), size: 20),
              const SizedBox(width: 8),
              Text('+91',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: Colors.white24),
            ],
          ),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: (v) {
        if (v == null || v.length < 10) {
          return 'Enter a valid 10-digit phone number';
        }
        return null;
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon:
            Icon(icon, color: Colors.white.withOpacity(0.5), size: 20),
        suffixIcon: onToggleVisibility != null
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white.withOpacity(0.5),
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
      validator: validator,
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.5), width: 2),
                image: _imageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                    : null,
              ),
              child: _imageBytes == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 26,
                            color: Colors.white.withOpacity(0.5)),
                        const SizedBox(height: 4),
                        Text('Optional',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: Colors.white38)),
                      ],
                    )
                  : null,
            ),
            if (_imageBytes != null)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.edit, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() => SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: authController.isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: authController.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _isSignUp ? 'Create Account' : 'Sign In',
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ));
  }

  // ─── Actions ─────────────────────────────────────────────

  void _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    authController.clearError();

    final phone = '+91${_phoneController.text.trim()}';
    final password = _passwordController.text;

    if (_isSignUp) {
      final success = await authController.signUpWithPhone(
        phone: phone,
        password: password,
        name: _nameController.text.trim(),
        profileImage: _imageFile,
      );
      if (success) {
        setState(() {
          _isSignUp = false;
          _phoneController.clear();
          _passwordController.clear();
          _nameController.clear();
          _imageFile = null;
          _imageBytes = null;
        });
      }
    } else {
      await authController.signInWithPhone(phone: phone, password: password);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageFile = pickedFile;
        _imageBytes = bytes;
      });
    }
  }
}
