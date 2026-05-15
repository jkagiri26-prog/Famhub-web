import 'package:flutter/material.dart';

class NavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> go(String route) async {
    navigatorKey.currentState?.pushNamed(route);
  }

  static Future<void> replace(String route) async {
    navigatorKey.currentState?.pushReplacementNamed(route);
  }

  static void back() {
    navigatorKey.currentState?.pop();
  }
}