import 'package:flutter/material.dart';

class Module {
  final String key;
  final String name;
  final String? icon;
  final Widget Function() builder;

  const Module({
    required this.key,
    required this.name,
    required this.builder,
    this.icon,
  });
}