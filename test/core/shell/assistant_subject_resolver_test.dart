import 'package:flutter_test/flutter_test.dart';

import 'package:famhub_app/core/shell/application/assistant/assistant_subject_resolver.dart';

void main() {
  group('resolveAdvisorSubject', () {
    test('an explicit subject in the question wins over history and module',
        () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: "What's the weather forecast this week?",
        priorQuestions: <String>['What is in FAMHUB Marketplace?'],
        moduleId: 'marketplace',
      );

      expect(resolution.subject, 'weather');
      expect(resolution.source, AdvisorSubjectSource.question);
      // The farmer's own words reach the gates untouched.
      expect(resolution.routingQuestion,
          "What's the weather forecast this week?");
      expect(resolution.routingQuestion, isNot(contains('active subject')));
    });

    test('a subject-less follow-up resolves from the recent chat history',
        () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'Do we have any maize?',
        priorQuestions: <String>['What is in FAMHUB Marketplace?'],
        moduleId: 'marketplace',
      );

      expect(resolution.subject, 'marketplace');
      expect(resolution.source, AdvisorSubjectSource.history);
      expect(
        resolution.routingQuestion,
        'Do we have any maize? [active subject: marketplace]',
      );
    });

    test('the current module supplies the subject when history has none',
        () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'Do we have any maize?',
        moduleId: 'marketplace',
      );

      expect(resolution.subject, 'marketplace');
      expect(resolution.source, AdvisorSubjectSource.module);
      expect(
        resolution.routingQuestion,
        contains('[active subject: marketplace]'),
      );
    });

    test('history subject outranks the module', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'How many do we have?',
        priorQuestions: <String>['What is in FAMHUB Marketplace?'],
        moduleId: 'farm_management',
      );

      expect(resolution.subject, 'marketplace');
      expect(resolution.source, AdvisorSubjectSource.history);
      expect(
        resolution.routingQuestion,
        contains('[active subject: marketplace]'),
      );
    });

    test('the newest subject in history wins over an older one', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'Do we have any?',
        priorQuestions: <String>[
          'What is in FAMHUB Marketplace?',
          'Which animals are registered on my farm?',
        ],
        moduleId: 'marketplace',
      );

      expect(resolution.subject, 'livestock');
      expect(resolution.source, AdvisorSubjectSource.history);
      expect(resolution.routingQuestion, contains('[active subject: livestock]'));
    });

    test('a standalone question without a cue is never annotated', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'How does composting work?',
        moduleId: 'marketplace',
      );

      // The subject is still known (and travels to the gateway), but the
      // gates see the question exactly as asked.
      expect(resolution.subject, 'marketplace');
      expect(resolution.routingQuestion, 'How does composting work?');
    });

    test('no history and no module leaves the question untouched', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'Why are my maize leaves yellow?',
      );

      expect(resolution.subject, isNull);
      expect(resolution.source, AdvisorSubjectSource.none);
      expect(resolution.routingQuestion, 'Why are my maize leaves yellow?');
    });

    test('an animal subject is never swallowed by the farm marker', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'Which animals are registered on my farm?',
      );

      expect(resolution.subject, 'livestock');
      expect(resolution.source, AdvisorSubjectSource.question);
      expect(resolution.routingQuestion,
          'Which animals are registered on my farm?');
    });

    test('a weather subject is never swallowed by the farm marker', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: "What's the weather on my farm?",
      );

      expect(resolution.subject, 'weather');
      expect(resolution.source, AdvisorSubjectSource.question);
    });

    test('the route supplies the subject when no module id resolved', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'What about these?',
        route: '/marketplace/create',
      );

      expect(resolution.subject, 'marketplace');
      expect(resolution.source, AdvisorSubjectSource.module);
      expect(resolution.routingQuestion, contains('[active subject: marketplace]'));
    });

    test('a question that names marketplace itself needs no annotation', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: 'I mean in marketplace.',
        priorQuestions: <String>['Do we have any maize?'],
        moduleId: 'farm_management',
      );

      expect(resolution.subject, 'marketplace');
      expect(resolution.source, AdvisorSubjectSource.question);
      expect(resolution.routingQuestion, 'I mean in marketplace.');
    });

    test('trims the question before resolving', () {
      final AdvisorSubjectResolution resolution = resolveAdvisorSubject(
        question: '  Do we have any maize?  ',
        moduleId: 'marketplace',
      );

      expect(
        resolution.routingQuestion,
        'Do we have any maize? [active subject: marketplace]',
      );
    });
  });
}
