import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpPage extends StatefulWidget {
  final String role;
  final VoidCallback onAuthComplete;

  const OtpPage({super.key, required this.role, required this.onAuthComplete});

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isLoading = false;
  String _errorMessage = "";

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  String _getFormattedPhone() {
    String raw = _phoneController.text.trim();
    if (raw.startsWith('0')) raw = raw.substring(1);
    if (raw.startsWith('+254')) return raw;
    return "+254$raw";
  }

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 9) {
      setState(() => _errorMessage = "Enter a valid Safaricom/Airtel number");
      return;
    }
    setState(() { _isLoading = true; _errorMessage = ""; });

    try {
      await _supabase.auth.signInWithOtp(
        phone: _getFormattedPhone(),
        data: {'role': widget.role}, 
      );
      if (mounted) setState(() => _otpSent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Check connection and try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length < 6) return;
    setState(() { _isLoading = true; _errorMessage = ""; });
    try {
      final res = await _supabase.auth.verifyOTP(
        phone: _getFormattedPhone(),
        token: _otpController.text.trim(),
        type: OtpType.sms,
      );

      if (res.user != null && mounted) {
        widget.onAuthComplete(); 
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60), 
            Text(
              _otpSent ? "Verify Identity" : "Join as ${widget.role}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent ? "Enter code sent to ${_getFormattedPhone()}" : "Quick SMS verification to get started.",
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 32),
            
            _otpSent ? _buildOtpInput() : _buildPhoneInput(),

            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
            ],

            const SizedBox(height: 24),
            _buildSubmitButton(),
            
            if (_otpSent) ...[
              const SizedBox(height: 8),
              Center(
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: () => setState(() { _otpSent = false; _otpController.clear(); }),
                    child: const Text("Change number", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      autofocus: true,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        prefixIcon: const Padding(
          padding: EdgeInsets.all(14),
          child: Text("+254", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        hintText: "712 345 678",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildOtpInput() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      autofocus: true,
      maxLength: 6,
      style: const TextStyle(fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.w900),
      decoration: InputDecoration(
        counterText: "",
        hintText: "000000",
        hintStyle: const TextStyle(color: Colors.black12),
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      onChanged: (v) { if (v.length == 6) _verifyOtp(); },
    );
  }

  Widget _buildSubmitButton() {
    final Color primaryColor = Theme.of(context).colorScheme.primary; 
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_otpSent ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          // FIXED: Use withValues for modern Flutter to avoid build warnings
          disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
          : Text(_otpSent ? "VERIFY & LOGIN" : "SEND OTP", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}