import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/session/app_session.dart';
import 'package:famhub_app/core/session/session_destination.dart';

void main() {
  group('resolveSessionDestination', () {
    test('initializing → splash (never routes early)', () {
      expect(
        resolveSessionDestination(const InitializingSession()),
        SessionDestination.splash,
      );
    });

    test('unauthenticated → welcome', () {
      expect(
        resolveSessionDestination(const UnauthenticatedSession()),
        SessionDestination.welcome,
      );
    });

    test('restore failure → error (NOT create-profile / welcome)', () {
      final failure = resolveSessionDestination(
        const SessionFailure(
          message: 'network down',
        ),
      );
      expect(failure, SessionDestination.error);
    });

    test('authenticated without profile → createProfile', () {
      final session = AuthenticatedSession(
        userId: 'u1',
        displayName: 'User',
        hasProfile: false,
      );
      expect(
        resolveSessionDestination(session),
        SessionDestination.createProfile,
      );
    });

    test('authenticated with profile but no workspaces → workspaceSelection',
        () {
      final session = AuthenticatedSession(
        userId: 'u1',
        displayName: 'User',
        hasProfile: true,
        workspaceIds: const [],
      );
      expect(
        resolveSessionDestination(session),
        SessionDestination.workspaceSelection,
      );
    });

    test('authenticated with profile and workspaces → dashboard', () {
      final session = AuthenticatedSession(
        userId: 'u1',
        displayName: 'User',
        hasProfile: true,
        workspaceIds: const ['ws-1', 'ws-2'],
        defaultWorkspaceId: 'ws-1',
        hasCompletedOnboarding: true,
      );
      expect(
        resolveSessionDestination(session),
        SessionDestination.dashboard,
      );
    });

    test('refresh keeps dashboard (regression: Scenario A)', () {
      // State produced on a refresh after full onboarding.
      final refreshed = AuthenticatedSession(
        userId: 'u1',
        displayName: 'User',
        profile: {
          'id': 'p1',
          'first_name': 'User',
          'current_workspace_id': 'ws-1',
        },
        hasProfile: true,
        workspaceIds: const ['ws-1', 'ws-2'],
        defaultWorkspaceId: 'ws-1',
        hasCompletedOnboarding: true,
      );
      expect(
        resolveSessionDestination(refreshed),
        SessionDestination.dashboard,
      );
    });
  });
}
