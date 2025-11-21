import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../utils/app_colors.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // ❌ REMOVE THIS LINE - We'll use static methods instead
  // final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  int _loginAttempts = 0;
  bool _isAccountLocked = false;

  @override
  void initState() {
    super.initState();
    _checkAccountStatus();
  }

  Future<void> _checkAccountStatus() async {
    final attempts = await AuthService.getLoginAttempts();
    final isLocked = await AuthService.isAccountLocked();
    setState(() {
      _loginAttempts = attempts;
      _isAccountLocked = isLocked;
    });
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isAccountLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account locked. Use Forgot Password.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      await AuthService.saveLoginState(_emailController.text.trim());
      
      if (mounted) {
        Provider.of<UserModel>(context, listen: false)
            .login(_emailController.text.trim());
        
        Navigator.pushReplacementNamed(context, '/home');
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome back!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      final attempts = await AuthService.incrementLoginAttempts();
      final isLocked = await AuthService.isAccountLocked();
      
      setState(() {
        _loginAttempts = attempts;
        _isAccountLocked = isLocked;
      });
      
      if (isLocked) _showLockedAccountDialog();
      
      if (mounted) {
        final remaining = 3 - attempts;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLocked 
                  ? 'Account locked. Use Forgot Password.'
                  : result['message'] ?? 'Invalid credentials. $remaining attempt(s) remaining.',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ✅ FIXED: Use static method instead of instance method
  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    // ✅ CHANGED: AuthService.signInWithGoogle() instead of _authService.signInWithGoogle()
    final result = await AuthService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      Provider.of<UserModel>(context, listen: false).login(result['email'] ?? '');
      Navigator.pushReplacementNamed(context, '/home');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Sign-In successful!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Google Sign-In failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showLockedAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppColors.error),
            SizedBox(width: 12),
            Text('Account Locked'),
          ],
        ),
        content: const Text(
          'Your account has been locked due to multiple failed attempts.\n\n'
          'Use "Forgot Password" to reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ForgotPasswordScreen(
                    email: _emailController.text.trim(),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Forgot Password'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.visibility,
                        size: 50,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Locked warning
                    if (_isAccountLocked)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Account Locked! Use Forgot Password',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Login Card
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Text(
                                'RoadEye AI',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              
                              // Login attempts
                              if (_loginAttempts > 0 && !_isAccountLocked)
                                Container(
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Failed attempts: $_loginAttempts/3',
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              
                              const SizedBox(height: 24),
                              
                              // Email
                              TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  prefixIcon: const Icon(Icons.email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                enabled: !_isAccountLocked,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter email';
                                  }
                                  if (!AuthService.isValidEmail(value)) {
                                    return 'Invalid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                enabled: !_isAccountLocked,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter password';
                                  }
                                  return null;
                                },
                              ),
                              
                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ForgotPasswordScreen(
                                          email: _emailController.text.trim(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: (_isLoading || _isAccountLocked) ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _isAccountLocked ? 'ACCOUNT LOCKED' : 'LOGIN',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Divider
                              const Row(
                                children: [
                                  Expanded(child: Divider()),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('OR'),
                                  ),
                                  Expanded(child: Divider()),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // ✅ GOOGLE SIGN-IN BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _googleSignIn,
                                  icon: Image.asset(
                                    'assets/google_logo.png',
                                    height: 24,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(Icons.g_mobiledata, size: 24);
                                    },
                                  ),
                                  label: const Text('Sign in with Google'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Register Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Don't have an account? "),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Register',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
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
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}