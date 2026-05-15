import 'package:flutter/material.dart';

import '../../../../shared/layout/section_container_widget.dart';

class AuthSectionCardWidget extends StatelessWidget {
  final Widget child;

  const AuthSectionCardWidget({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SectionContainerWidget(
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }
}