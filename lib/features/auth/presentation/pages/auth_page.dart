import 'package:flutter/material.dart';

import '../../../../shared/layout/responsive_wrapper_widget.dart';
import '../../../../shared/widgets/headers/module_header_widget.dart';

import '../widgets/role_selector_widget.dart';
import '../widgets/phone_input_widget.dart';
import '../widgets/otp_input_widget.dart';
import '../widgets/auth_button_widget.dart';
import '../widgets/auth_section_card_widget.dart';

class AuthPage extends StatefulWidget {
  final String role;
  final VoidCallback onAuthComplete;

  const AuthPage({
    super.key,
    this.role = '',
    this.onAuthComplete = _noop,
  });

  static void _noop() {}

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController phoneController =
      TextEditingController();

  final TextEditingController otpController =
      TextEditingController();

  String selectedRole = "Farmer";
  bool otpSent = false;
  bool loading = false;
  String error = "";

  @override
  void initState() {
    super.initState();

    selectedRole =
        widget.role.isNotEmpty
            ? widget.role
            : "Farmer";
  }

  @override
  void dispose() {
    phoneController.dispose();
    otpController.dispose();
    super.dispose();
  }

  void continueAsGuest() {
    widget.onAuthComplete();
  }

  Future<void> sendOtp() async {
    setState(() {
      loading = true;
      error = "";
    });

    await Future.delayed(
      const Duration(seconds: 1),
    );

    setState(() {
      otpSent = true;
      loading = false;
    });
  }

  Future<void> verifyOtp() async {
    setState(() {
      loading = true;
      error = "";
    });

    await Future.delayed(
      const Duration(seconds: 1),
    );

    setState(() {
      loading = false;
    });

    widget.onAuthComplete();
  }

  @override
  Widget build(BuildContext context) {
    final Color primary =
        Theme.of(context).colorScheme.primary;

    return ResponsiveWrapperWidget(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              /// MODULE HEADER
              ModuleHeaderWidget(
                title: "FAMHUB",
                subtitle:
                    "Authentication • Access • Identity",
                trailingIcon:
                    Icons.verified_user_outlined,
              ),

              const SizedBox(height: 28),

              /// AUTH CONTENT CARD
              AuthSectionCardWidget(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (!otpSent) ...[
                      const Text(
                        "Sign up or Login as a...",
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 20),

                      RoleSelectorWidget(
                        selected: selectedRole,
                        onChanged: (value) {
                          setState(() {
                            selectedRole = value;
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      PhoneInputWidget(
                        controller:
                            phoneController,
                      ),
                    ] else ...[
                      const Text(
                        "Verify Phone",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 20),

                      OtpInputWidget(
                        controller:
                            otpController,
                      ),
                    ],

                    if (error.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                              top: 12,
                            ),
                        child: Text(
                          error,
                          style:
                              const TextStyle(
                                color:
                                    Colors.red,
                              ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    AuthButtonWidget(
                      loading: loading,
                      isOtp: otpSent,
                      onPressed:
                          otpSent
                              ? verifyOtp
                              : sendOtp,
                      color: primary,
                    ),

                    const SizedBox(height: 20),

                    Center(
                      child: TextButton(
                        onPressed:
                            continueAsGuest,
                        child: const Text(
                          "Continue as Guest",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}