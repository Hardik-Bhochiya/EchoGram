import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/local_store_service.dart';
import '../main_nav_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _customLocationController = TextEditingController();

  String _selectedLocation = 'Nadiad';
  List<String> _locations = ['Nadiad', 'Ahmedabad', 'Mumbai', 'Dwarka'];
  bool _isCustomLocation = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  Timer? _debounceTimer;
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String _usernameStatusMessage = '';

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    final savedLocs = LocalStoreService().getLocations();
    if (savedLocs.isNotEmpty) {
      _locations = List.from(savedLocs);
      if (!_locations.contains(_selectedLocation)) {
        _selectedLocation = _locations.first;
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _usernameController.removeListener(_onUsernameChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final raw = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
    _debounceTimer?.cancel();

    if (raw.isEmpty) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameStatusMessage = '';
      });
      return;
    }

    if (raw.length < 3) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatusMessage = 'Username must be at least 3 characters';
      });
      return;
    }

    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(raw)) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
        _usernameStatusMessage = 'Only lowercase letters, numbers, and underscores allowed';
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameStatusMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final auth = context.read<AuthProvider>();
      bool available = await auth.checkUsernameAvailable(raw);

      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = available;
        _usernameStatusMessage = available
            ? '@$raw is available!'
            : '@$raw is already taken. Try another.';
      });
    });
  }

  void _handleSignUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_isUsernameAvailable == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose an available username first.')),
        );
        return;
      }

      final effectiveLocation = _isCustomLocation && _customLocationController.text.trim().isNotEmpty
          ? _customLocationController.text.trim()
          : _selectedLocation;

      // Automatically register the location into app registry if new
      LocalStoreService().addLocation(effectiveLocation);

      final auth = context.read<AuthProvider>();
      final uName = _usernameController.text.trim().toLowerCase().replaceAll('@', '');
      final fName = _firstNameController.text.trim();
      final lName = _lastNameController.text.trim();
      final fullName = '$fName $lName'.trim();

      final success = await auth.signUp(
        name: fullName,
        username: uName,
        firstName: fName,
        lastName: lName,
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        campusOrCity: effectiveLocation,
        majorOrBio: '$effectiveLocation Community Member',
      );

      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF238636),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            content: Text('Welcome to NearTalk, @$uName! 🎉'),
          ),
        );
      } else if (!success && mounted) {
        final err = auth.errorMessage ?? 'Registration failed. Please check details.';
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFF85149), width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Color(0xFFF85149), size: 24),
                SizedBox(width: 10),
                Text(
                  'Sign Up Notice',
                  style: TextStyle(color: Color(0xFFF0F6FC), fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  err,
                  style: const TextStyle(color: Color(0xFFC9D1D9), fontSize: 13.5, height: 1.5),
                ),
                if (err.contains('Firebase') || err.contains('Console')) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: const Text(
                      '📌 How to enable in Firebase Console:\n'
                      '1. Go to console.firebase.google.com\n'
                      '2. Select your project: neartalk-app-2433c\n'
                      '3. Go to Build > Authentication\n'
                      '4. Click "Get Started"\n'
                      '5. Under Sign-in method, click Email/Password > Enable > Save\n'
                      '6. Go to Firestore Database > Create Database',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12, height: 1.45),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it', style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
        title: const Text(
          'Sign Up — NearTalk',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFF0F6FC)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Color(0xFF21262D),
                        child: Text('📍', style: TextStyle(fontSize: 22)),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Join Location Communities',
                              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Color(0xFFF0F6FC)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Connect with peers in your city, join local groups, and chat.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8B949E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // First Name & Last Name Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FIRST NAME *',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF30363D)),
                            ),
                            child: TextFormField(
                              controller: _firstNameController,
                              style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Hardik',
                                hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LAST NAME',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF161B22),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF30363D)),
                            ),
                            child: TextFormField(
                              controller: _lastNameController,
                              style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Bhochiya',
                                hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Username *
                const Text(
                  'USERNAME * (PRIMARY KEY)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isUsernameAvailable == true
                          ? const Color(0xFF238636)
                          : (_isUsernameAvailable == false
                              ? const Color(0xFFF85149)
                              : const Color(0xFF30363D)),
                      width: _isUsernameAvailable != null ? 1.5 : 1,
                    ),
                  ),
                  child: TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: Color(0xFFF0F6FC), fontWeight: FontWeight.w600, fontSize: 14.5),
                    decoration: InputDecoration(
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '@',
                          style: TextStyle(color: Color(0xFF58A6FF), fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      hintText: 'hardik_07',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: _isCheckingUsername
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF58A6FF)),
                              ),
                            )
                          : (_isUsernameAvailable != null
                              ? Icon(
                                  _isUsernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  color: _isUsernameAvailable! ? const Color(0xFF238636) : const Color(0xFFF85149),
                                  size: 20,
                                )
                              : null),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Username is required';
                      final clean = v.trim().toLowerCase().replaceAll('@', '');
                      if (clean.length < 3) return 'Must be at least 3 characters';
                      if (_isUsernameAvailable == false) return 'Username is already taken';
                      return null;
                    },
                  ),
                ),
                if (_usernameStatusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _usernameStatusMessage,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isUsernameAvailable == true ? const Color(0xFF238636) : const Color(0xFFF85149),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Email *
                const Text(
                  'EMAIL ADDRESS *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF8B949E), size: 18),
                      hintText: 'hardik@gmail.com',
                      hintStyle: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Location * Dropdown & Add Location
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COLLEGE / LOCATION *',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isCustomLocation = !_isCustomLocation;
                        });
                      },
                      child: Text(
                        _isCustomLocation ? 'Select from list' : '+ Add New Location',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (!_isCustomLocation)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _locations.contains(_selectedLocation) ? _selectedLocation : (_locations.isNotEmpty ? _locations.first : null),
                        dropdownColor: const Color(0xFF21262D),
                        style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF58A6FF)),
                        isExpanded: true,
                        items: [
                          ..._locations.map((loc) {
                            return DropdownMenuItem(
                              value: loc,
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Color(0xFF58A6FF), size: 16),
                                  const SizedBox(width: 8),
                                  Text(loc, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }),
                          const DropdownMenuItem(
                            value: '__ADD_NEW__',
                            child: Row(
                              children: [
                                Icon(Icons.add_location_alt_rounded, color: Color(0xFF238636), size: 16),
                                SizedBox(width: 8),
                                Text('+ Add New Location / College...', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF238636))),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_NEW__') {
                            setState(() => _isCustomLocation = true);
                          } else if (val != null) {
                            setState(() => _selectedLocation = val);
                          }
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF58A6FF)),
                    ),
                    child: TextFormField(
                      controller: _customLocationController,
                      style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF58A6FF), size: 18),
                        hintText: 'Enter college or city (e.g. DDU, Nadiad)',
                        hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF8B949E), size: 18),
                          onPressed: () => setState(() => _isCustomLocation = false),
                        ),
                      ),
                      validator: (v) {
                        if (_isCustomLocation && (v == null || v.trim().isEmpty)) {
                          return 'Please enter your location or college';
                        }
                        return null;
                      },
                    ),
                  ),
                const SizedBox(height: 16),

                // Password *
                const Text(
                  'PASSWORD *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8B949E), size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8B949E), size: 18),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      hintText: 'Minimum 6 characters',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Confirm Password *
                const Text(
                  'CONFIRM PASSWORD *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8B949E), letterSpacing: 0.6),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Color(0xFFF0F6FC), fontSize: 14),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF8B949E), size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF8B949E), size: 18),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      hintText: 'Re-enter your password',
                      hintStyle: const TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm password';
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Inline Notice / Error Banner if any
                if (auth.errorMessage != null && auth.errorMessage!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF85149)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFF85149), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Color(0xFFF85149), fontSize: 12.5, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Sign Up Button
                ElevatedButton(
                  onPressed: auth.status == AuthStatus.authenticating ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF238636),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                    ),
                    elevation: 2,
                  ),
                  child: auth.status == AuthStatus.authenticating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: 18),

                // Link back to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? ', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(color: Color(0xFF58A6FF), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
