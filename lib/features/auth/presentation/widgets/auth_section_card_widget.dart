import 'package:flutter/material.dart';

import 'package:famhub_app/shared/layouts/section_container_widget.dart';

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