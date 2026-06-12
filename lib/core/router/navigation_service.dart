import 'package:go_router/go_router.dart';

class NavigationService {
  static GoRouter? _router;

  /// Must be initialized from app root
  static void setRouter(GoRouter router) {
    _router = router;
  }

  static void go(String route) {
    _router?.go(route);
  }

  static void push(String route) {
    _router?.push(route);
  }

  static void replace(String route) {
    _router?.replace(route);
  }

  static void back() {
    _router?.pop();
  }

  static bool canPop() {
    return _router?.canPop() ?? false;
  }
}