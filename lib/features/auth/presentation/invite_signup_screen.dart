import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

/// Invite Signup Screen - Users enter email + code to complete registration
class InviteSignupScreen extends ConsumerStatefulWidget {
  const InviteSignupScreen({super.key});

  @override
  ConsumerState<InviteSignupScreen> createState() => _InviteSignupScreenState();
}

class _InviteSignupScreenState extends ConsumerState<InviteSignupScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isVerifying = false;
  bool _isRegistering = false;
  bool _inviteVerified = false;
  
  Map<String, dynamic>? _invite;
  List<String> _availableInterests = [];
  List<String> _availableCourses = [];
  List<String> _selectedInterests = [];
  List<String> _selectedCourses = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    final interests = await SupabaseService.getPredefinedInterests();
    final courses = await SupabaseService.getPredefinedCourses();
    setState(() {
      _availableInterests = interests.map((i) => i['name'] as String).toList();
      _availableCourses = courses.map((c) => c['name'] as String).toList();
    });
  }

  Future<void> _verifyInvite() async {
    if (_emailController.text.isEmpty || _codeController.text.isEmpty) {
      _showError('Please enter email and invite code');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final invite = await SupabaseService.verifyInvite(
        email: _emailController.text.trim(),
        code: _codeController.text.trim().toUpperCase(),
      );

      if (invite != null) {
        setState(() {
          _invite = invite;
          _inviteVerified = true;
        });
      } else {
        _showError('Invalid invite code or email');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _completeRegistration() async {
    if (_nameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }

    setState(() => _isRegistering = true);

    try {
      await SupabaseService.completeInviteRegistration(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: _invite!['role'],
        interests: _selectedInterests,
        courses: _selectedCourses,
        inviteId: _invite!['id'],
        chaperoneId: _invite!['chaperone_id'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration complete! Please login.'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Registration failed: $e');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join LAMP'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _inviteVerified ? _buildRegistrationForm() : _buildInviteForm(),
        ),
      ),
    );
  }

  Widget _buildInviteForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        const Icon(Icons.mail_outline, size: 64, color: AppColors.primary),
        const SizedBox(height: 24),
        Text(
          'Enter Your Invite',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'You need an invite from an administrator to join LAMP.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Email
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),

        // Invite Code
        TextField(
          controller: _codeController,
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            prefixIcon: Icon(Icons.vpn_key_outlined),
            border: OutlineInputBorder(),
            hintText: 'e.g., ABC12345',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 24),

        // Verify Button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _verifyInvite,
            child: _isVerifying
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Verify Invite'),
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    final role = _invite?['role'] ?? 'protege';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Invite Verified!', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Role: ${role.toString().toUpperCase()}', style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text('Complete Your Profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),

        // Name
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            prefixIcon: Icon(Icons.person_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // Password
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: 'Create Password',
            prefixIcon: Icon(Icons.lock_outlined),
            border: OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 24),

        // Interests
        Text('Select Your Interests', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return FilterChip(
              label: Text(interest),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedInterests.add(interest);
                  } else {
                    _selectedInterests.remove(interest);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Courses
        Text('Courses Completed', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableCourses.map((course) {
            final isSelected = _selectedCourses.contains(course);
            return FilterChip(
              label: Text(course),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCourses.add(course);
                  } else {
                    _selectedCourses.remove(course);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // Register Button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isRegistering ? null : _completeRegistration,
            child: _isRegistering
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Complete Registration'),
          ),
        ),
      ],
    );
  }
}
