import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _otpSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FamHub Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_otpSent) ...[
              const Text(
                'Enter your phone number',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+254712345678',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ] else ...[
              const Text(
                'Enter OTP sent to your phone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'OTP Code',
                  hintText: '000000',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.pin),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : _otpSent
                      ? _verifyOtp
                      : _sendOtp,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                _loading
                    ? 'Please wait...'
                    : _otpSent
                        ? 'Verify OTP'
                        : 'Send OTP',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            if (_otpSent) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : _resetOtp,
                child: const Text('Change Phone Number'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Step 1: Send OTP to phone
  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }

    setState(() => _loading = true);

    try {
      await _supabase.auth.signInWithOtp(phone: phone);
      setState(() {
        _otpSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP sent to $phone')),
        );
      }
    } on AuthException catch (e) {
      _showError('Failed to send OTP: ${e.message}');
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Step 2: Verify OTP using Supabase method
  Future<void> _verifyOtp() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    
    if (otp.isEmpty || otp.length < 6) {
      _showError('Please enter a valid 6-digit OTP');
      return;
    }

    setState(() => _loading = true);

    try {
      // Use Supabase's built-in verifyOTP (v2.12.0+)
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful!')),
          );
          // Navigate to home - handled by AuthGate in main.dart
        }
      }
    } on AuthException catch (e) {
      _showError('Verification failed: ${e.message}');
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Reset to phone entry
  void _resetOtp() {
    setState(() {
      _otpSent = false;
      _otpController.clear();
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
