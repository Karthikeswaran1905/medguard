import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/repositories/auth_repository.dart';
import 'patient_sign_up_screen.dart';

/// Shared sign-in for every role (Section 25: "Sign up" row — everyone
/// except the Patient is provisioned by the person above them in the
/// management chain and simply logs in here; only a Patient can
/// self-register, via [PatientSignUpScreen]).
///
/// Visual style follows a branded "welcome back" card layout, restyled to
/// MedGuard's own teal identity (the real app logo + palette, not a
/// generic mockup's colors) rather than copied wholesale from a reference
/// image. Two things worth knowing about what's real here:
///  - "Remember me" doesn't do extra work of its own — Firebase Auth
///    already persists the session across app restarts by default on
///    every platform this app ships to, so the checkbox mostly documents
///    that behavior rather than switching it on.
///  - There's no "Continue with Google" button. Google Sign-In isn't
///    wired up in this Firebase project (it needs enabling in the
///    Firebase Console plus the google_sign_in package), so a button for
///    it here would just be decorative — left out rather than shown
///    non-functional.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _authRepo = AuthRepository();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepo.signIn(email: _email.text.trim(), password: _password.text);
      // AuthGate listens to onAuthStateChange and will route automatically.
    } catch (e) {
      setState(() => _error = 'Could not sign in. Check your email and password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset your password'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    if (target == null || target.isEmpty || !target.contains('@')) return;
    try {
      await _authRepo.sendPasswordResetEmail(email: target);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $target.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send reset link: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF7F5), Color(0xFFF7FBFA)],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(top: -70, right: -60, child: _Blob(size: 220, opacity: 0.10)),
            const Positioned(bottom: 120, left: -70, child: _Blob(size: 200, opacity: 0.08)),
            SafeArea(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 28),
                        _Header(),
                        const SizedBox(height: 28),
                        _WelcomeCard(
                          formKey: _formKey,
                          email: _email,
                          password: _password,
                          obscurePassword: _obscurePassword,
                          onToggleObscure: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                          rememberMe: _rememberMe,
                          onRememberMeChanged: (v) =>
                              setState(() => _rememberMe = v ?? true),
                          onForgotPassword: _forgotPassword,
                          error: _error,
                          loading: _loading,
                          onSubmit: _submit,
                          onSignUp: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PatientSignUpScreen(),
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Image.asset('assets/branding/logo.png'),
        ),
        const SizedBox(height: 16),
        Text(
          'MedGuard',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0B3B37),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'No medicine confirmation should go unnoticed.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6B69),
              ),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primary.withValues(alpha: opacity),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool rememberMe;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onForgotPassword;
  final String? error;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onSignUp;

  const _WelcomeCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.rememberMe,
    required this.onRememberMeChanged,
    required this.onForgotPassword,
    required this.error,
    required this.loading,
    required this.onSubmit,
    required this.onSignUp,
  });

  InputDecoration _fieldDecoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primary),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF3F8F7),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 30, offset: Offset(0, 12)),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 28),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Welcome back!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0B3B37)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign in to continue to your account',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: _fieldDecoration(hint: 'Email', icon: Icons.mail_outline),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: password,
              obscureText: obscurePassword,
              decoration: _fieldDecoration(
                hint: 'Password',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF9AA5A3),
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: rememberMe,
                  onChanged: onRememberMeChanged,
                  activeColor: AppTheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
                const Text('Remember me', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
                const Spacer(),
                TextButton(
                  onPressed: onForgotPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Forgot Password?', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            _GradientButton(loading: loading, onPressed: onSubmit),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? ", style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                GestureDetector(
                  onTap: onSignUp,
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Doctor, Incharge and Caretaker accounts are created for you '
              'by the person managing you in MedGuard.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF9AA5A3)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _GradientButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onPressed,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [AppTheme.primary, const Color(0xFF14B8A6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Login',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
