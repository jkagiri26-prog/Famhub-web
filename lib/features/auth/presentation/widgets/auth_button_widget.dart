import 'package:flutter/material.dart';

class AuthButtonWidget extends StatelessWidget {
  final bool loading;
  final bool isOtp;
  final VoidCallback onPressed;
  final Color color;

  const AuthButtonWidget({
    super.key,
    required this.loading,
    required this.isOtp,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed:
            loading
                ? null
                : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
        child:
            loading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child:
                      CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                )
                : Text(
                  isOtp
                      ? 'Verify OTP'
                      : 'Send OTP',
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
      ),
    );
  }
}