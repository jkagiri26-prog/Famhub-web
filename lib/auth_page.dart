import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleSelectionPage();
  }
}

// --------------------
// 1️⃣ ROLE SELECTION PAGE
// --------------------
class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  void navigateToOtp(BuildContext context, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OtpPage(role: role)),
    );
  }

  Widget roleCard(String role, String emoji, Color color, BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => navigateToOtp(context, role),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  role,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Your Role"),
        backgroundColor: Colors.green[700],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 700;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text(
                  "Who are you?",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Choose the option that best describes you to continue.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        children: [
                          Row(
                            children: [
                              roleCard("Farmer", "👨🏽‍🌾", Colors.green[700]!, context),
                              const SizedBox(width: 12),
                              roleCard("Trader / Buyer", "🧺", Colors.orange[700]!, context),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              roleCard("Agri-Business", "🏢", Colors.blue[700]!, context),
                              const SizedBox(width: 12),
                              roleCard("Other Stakeholder", "🧑🏽‍💼", Colors.purple[700]!, context),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          roleCard("Farmer", "👨🏽‍🌾", Colors.green[700]!, context),
                          roleCard("Trader / Buyer", "🧺", Colors.orange[700]!, context),
                          roleCard("Agri-Business", "🏢", Colors.blue[700]!, context),
                          roleCard("Other Stakeholder", "🧑🏽‍💼", Colors.purple[700]!, context),
                        ],
                      ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------
// 2️⃣ OTP PAGE
// --------------------
class OtpPage extends StatefulWidget {
  final String role;
  const OtpPage({super.key, required this.role});

  @override
  _OtpPageState createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();
  bool otpSent = false;
  bool isLoading = false;
  String message = "";
  final _supabase = Supabase.instance.client;

  Future<void> sendOtp() async {
    final phoneNumber = phoneController.text.trim();
    if (phoneNumber.isEmpty || phoneNumber.length < 9) {
      setState(() {
        message = "Please enter a valid phone number";
      });
      return;
    }

    final phone = "+254$phoneNumber"; // Assuming Kenyan numbers for now

    setState(() {
      isLoading = true;
      message = "";
    });

    try {
      // Send OTP using Supabase (which you've configured to use Africa's Talking)
      await _supabase.auth.signInWithOtp(phone: phone);

      setState(() {
        otpSent = true;
        message = "OTP sent! Enter it below.";
      });
    } on AuthException catch (e) {
      setState(() {
        message = "Failed to send OTP: ${e.message}";
      });
    } catch (e) {
      setState(() {
        message = "Error sending OTP: ${e.toString()}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> verifyOtp() async {
    final phone = "+254${phoneController.text.trim()}";
    final otp = otpController.text.trim();

    if (otp.isEmpty || otp.length != 6) {
      setState(() {
        message = "Please enter a valid 6-digit OTP";
      });
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Verify OTP using Supabase
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user != null) {
        setState(() {
          message = "Verified! Redirecting…";
        });
        // Small delay for user to see the message
        await Future.delayed(const Duration(seconds: 1));
        redirectByRole(widget.role);
      }
    } on AuthException catch (e) {
      setState(() {
        message = "Verification failed: ${e.message}";
      });
    } catch (e) {
      setState(() {
        message = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void redirectByRole(String role) {
    Widget targetPage;
    if (role.toLowerCase() == "farmer") {
      targetPage = const Scaffold(body: Center(child: Text("Farmer Dashboard")));
    } else if (role.toLowerCase() == "trader / buyer") {
      targetPage = const Scaffold(body: Center(child: Text("Trader Dashboard")));
    } else if (role.toLowerCase() == "agri-business") {
      targetPage = const Scaffold(body: Center(child: Text("Agri-Business Dashboard")));
    } else {
      targetPage = const Scaffold(body: Center(child: Text("Stakeholder Dashboard")));
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => targetPage));
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Phone Verification"),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 24 : 48),
        child: Column(
          children: [
            Icon(Icons.smartphone_rounded, size: 60, color: Colors.green[700]),
            const SizedBox(height: 16),
            const Text(
              "Verify your phone",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Enter your phone number and OTP to continue",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.number,
              maxLength: 9,
              decoration: InputDecoration(
                labelText: "Phone Number",
                hintText: "7XXXXXXXX",
                prefixText: "+254 ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: "", // Hide character counter
              ),
            ),
            if (otpSent) ...[
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: "Enter OTP",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : (otpSent ? verifyOtp : sendOtp),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.green[700],
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(otpSent ? "Verify OTP" : "Send OTP"),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
