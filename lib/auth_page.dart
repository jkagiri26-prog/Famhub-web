import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  final String role;
  final VoidCallback onAuthComplete;

  const AuthPage({super.key, required this.role, required this.onAuthComplete});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  String _selectedRole = "Farmer";
  bool _otpSent = false;
  bool _isLoading = false;
  String _errorMessage = "";

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _bypass() => widget.onAuthComplete();

  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 9) {
      setState(() => _errorMessage = "Invalid phone number");
      return;
    }
    setState(() { _isLoading = true; _errorMessage = ""; });
    try {
      String phone = _phoneController.text.trim();
      if (phone.startsWith('0')) phone = phone.substring(1);
      final formatted = "+254$phone";
      
      await _supabase.auth.signInWithOtp(phone: formatted);
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _errorMessage = "Auth error. Use Guest mode for now.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeGreen = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -50, right: -50,
            child: CircleAvatar(radius: 100, backgroundColor: themeGreen.withOpacity(0.05)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    const Text("Welcome to", style: TextStyle(fontSize: 16, color: Colors.grey)),
                    Text("FAMHUB", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: themeGreen, letterSpacing: -1)),
                    const SizedBox(height: 40),
                    
                    if (!_otpSent) ...[
                      const Text("Sign up or Login as a...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      _buildRoleSelector(),
                      const SizedBox(height: 32),
                      _buildPhoneInput(),
                    ] else ...[
                      const Text("Verify Phone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                      const SizedBox(height: 32),
                      _buildOtpInput(),
                    ],

                    if (_errorMessage.isNotEmpty) 
                      Padding(padding: const EdgeInsets.only(top: 16), child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),

                    const SizedBox(height: 32),
                    _buildSubmitButton(themeGreen),
                    
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: _bypass,
                        child: Text("Continue as Guest", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
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

  Widget _buildRoleSelector() {
    return Row(
      children: [
        _roleIcon(Icons.agriculture, "Farmer"),
        const SizedBox(width: 12),
        _roleIcon(Icons.storefront, "Trader"),
        const SizedBox(width: 12),
        _roleIcon(Icons.hub, "Stakeholder"),
      ],
    );
  }

  Widget _roleIcon(IconData icon, String label) {
    bool isSelected = _selectedRole == label;
    Color primary = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primary : Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 28),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        hintText: "712 345 678",
        prefixText: "+254 ",
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildOtpInput() {
    return TextField(
      controller: _otpController,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      decoration: InputDecoration(counterText: "", filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
    );
  }

  Widget _buildSubmitButton(Color color) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 54,
        child: ElevatedButton(
          onPressed: _isLoading ? null : (_otpSent ? null : _sendOtp),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("GET STARTED"),
        ),
      ),
    );
  }
}