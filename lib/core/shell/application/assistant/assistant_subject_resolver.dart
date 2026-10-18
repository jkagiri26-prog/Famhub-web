/// ============================================================
/// ADVISOR SUBJECT RESOLVER — follow-ups before capability routing
/// ============================================================
///
/// 🧠 LOCATION CONTEXT:
///   core/shell/application/assistant/ = shell-level assistant seam
///
/// ✅ PURPOSE:
///   Resolve the farmer's *current subject* before any capability sees the
///   question, so follow-ups and references ("Do we have any maize?" after
///   a marketplace question) reach the right capability instead of falling
///   through to a context-blind advisory path.
///
///   Subject precedence, strongest first:
///     1. An explicit subject in the farmer's own words in this question.
///     2. The most recent subject named in an earlier farmer question.
///     3. The current module/route — a strong signal, never a restriction:
///        an explicit subject in the question always wins over the module.
///
///   The routing question is annotated with the active subject only when the
///   question itself names no subject AND carries a follow-up/reference cue,
///   so ordinary standalone questions reach capability gates unchanged and
///   general-knowledge questions are never dragged into a module.
///
/// ✅ ARCHITECTURE COMPLIANCE:
///   - Pure, side-effect free, no I/O, no identifiers, no model call
///   - Capability gates stay keyword-local: the annotation simply carries
///     the subject into the same `matches(question)` contract
///   - The gateway never receives the annotation — the farmer's own words
///     are sent verbatim; only routing sees the resolved form
///
/// ❌ Does NOT:
///   - Pick capabilities, fetch data, or hold conversation state
///   - Override an explicit subject the farmer stated in the question
/// ============================================================
library;

/// Why the subject was chosen.
enum AdvisorSubjectSource {
  /// The question itself named the subject.
  question,

  /// An earlier farmer question in this conversation named the subject.
  history,

  /// The current module/route implied the subject.
  module,

  /// No subject could be established.
  none,
}

/// Result of resolving one question's subject for routing.
class AdvisorSubjectResolution {
  const AdvisorSubjectResolution({
    required this.routingQuestion,
    required this.subject,
    required this.source,
  });

  /// The question as capability gates should see it: the farmer's own
  /// words, plus an `[active subject: …]` annotation when — and only
  /// when — a follow-up reference needed resolving.
  final String routingQuestion;

  /// Canonical subject token (`marketplace`, `weather`, `livestock`,
  /// `activity`, `farm`), or null when none is known.
  final String? subject;

  /// Where [subject] came from.
  final AdvisorSubjectSource source;

  /// True when the question itself stated the subject.
  bool get isExplicit => source == AdvisorSubjectSource.question;
}

/// Subject markers in the farmer's own words. Checked in order, so
/// `marketplace` is never swallowed by a farm marker and a weather word
/// wins over the generic farm module ("the weather on my farm").
const List<(String, List<String>)> kAdvisorSubjectMarkers =
    <(String, List<String>)>[
      ('marketplace', <String>['marketplace', 'market place', 'listing', 'listings']),
      (
        'weather',
        <String>[
          'weather',
          'forecast',
          'forecasted',
          'rainfall',
          'raining',
          'rains',
          'rain',
          'temperature',
          'storm',
          'drought',
          'frost',
        ],
      ),
      (
        'livestock',
        <String>[
          'livestock',
          'animal',
          'animals',
          'cattle',
          'cow',
          'cows',
          'calf',
          'calves',
          'bull',
          'goat',
          'goats',
          'sheep',
          'ewe',
          'ram',
          'lamb',
          'chicken',
          'chickens',
          'poultry',
          'hen',
          'rooster',
          'pig',
          'pigs',
          'herd',
          'flock',
        ],
      ),
      (
        'activity',
        <String>['activity', 'activities', 'schedule', 'scheduled', 'overdue'],
      ),
      (
        'farm',
        <String>[
          'farm',
          'farms',
          'field',
          'fields',
          'crop',
          'crops',
          'plot',
          'plots',
          'block',
          'blocks',
        ],
      ),
    ];

/// Module ids that imply a subject when the question names none.
const Map<String, String> kAdvisorModuleSubjects = <String, String>{
  'marketplace': 'marketplace',
  'weather': 'weather',
  'farm_management': 'farm',
};

/// Route prefixes (fallback when no module id resolved).
const Map<String, String> kAdvisorRouteSubjects = <String, String>{
  '/market': 'marketplace',
  '/weather': 'weather',
  '/farm': 'farm',
  '/crop': 'farm',
  '/field': 'farm',
  '/activit': 'activity',
};

/// Follow-up / reference cues: a question carrying one of these, with no
/// subject of its own, is a continuation of the current subject rather
/// than a new standalone question.
const List<String> kAdvisorFollowUpCues = <String>[
  'do we have',
  'do i have',
  'have we',
  'are there',
  'is there',
  'how many',
  'what about',
  'how about',
  'what is in',
  "what's in",
  'show me',
  'tell me about',
  'list',
  'them',
  'those',
  'these',
  'same',
  'another',
  'others',
  'mean',
  'instead',
  'rather',
  'still',
  'also',
  'any',
  'anything',
  'got',
  'available',
  'which',
];

/// Matches [word] (or a phrase) only on word boundaries.
bool _containsWord(String haystackLower, String word) {
  final RegExp pattern = RegExp(
    r'\b' + RegExp.escape(word) + r'\b',
    caseSensitive: false,
  );
  return pattern.hasMatch(haystackLower);
}

/// The explicit subject named in [question], or null.
String? _subjectIn(String question) {
  final String lower = question.toLowerCase();
  for (final (String subject, List<String> markers)
      in kAdvisorSubjectMarkers) {
    for (final String marker in markers) {
      if (_containsWord(lower, marker)) return subject;
    }
  }
  return null;
}

/// The most recent earlier farmer question that named a subject, or null.
String? _subjectInHistory(Iterable<String> priorQuestions) {
  final List<String> newestFirst = priorQuestions.toList(growable: false);
  for (final String question in newestFirst.reversed) {
    final String? subject = _subjectIn(question);
    if (subject != null) return subject;
  }
  return null;
}

/// The subject implied by the current module or route, or null.
String? _subjectInModule({String? moduleId, String? route}) {
  if (moduleId != null) {
    final String? byModule = kAdvisorModuleSubjects[moduleId];
    if (byModule != null) return byModule;
  }
  if (route != null) {
    for (final MapEntry<String, String> entry
        in kAdvisorRouteSubjects.entries) {
      if (route.startsWith(entry.key)) return entry.value;
    }
  }
  return null;
}

/// Resolves the active subject for [question] and returns the question in
/// the form capability gates should see.
///
/// [priorQuestions] are the farmer's own earlier questions, oldest first —
/// the current question must not be included. [moduleId] and [route] are
/// the shell's current context (a signal, not a restriction).
AdvisorSubjectResolution resolveAdvisorSubject({
  required String question,
  List<String> priorQuestions = const <String>[],
  String? moduleId,
  String? route,
}) {
  final String trimmed = question.trim();
  final String lower = trimmed.toLowerCase();

  // 1 — the farmer said it in this question: no annotation, routing runs
  // on the words exactly as asked.
  final String? explicit = _subjectIn(trimmed);
  if (explicit != null) {
    return AdvisorSubjectResolution(
      routingQuestion: trimmed,
      subject: explicit,
      source: AdvisorSubjectSource.question,
    );
  }

  // 2 — the conversation carries an unresolved subject.
  final String? fromHistory = _subjectInHistory(priorQuestions);
  // 3 — the current module/route.
  final String? fromModule = _subjectInModule(
    moduleId: moduleId,
    route: route,
  );
  final String? subject = fromHistory ?? fromModule;
  final AdvisorSubjectSource source = fromHistory != null
      ? AdvisorSubjectSource.history
      : fromModule != null
          ? AdvisorSubjectSource.module
          : AdvisorSubjectSource.none;

  // Only a reference-like question adopts the subject. Standalone
  // questions — including general-knowledge ones — stay untouched.
  final bool followUp = kAdvisorFollowUpCues.any(
    (String cue) => _containsWord(lower, cue),
  );
  if (subject == null || !followUp) {
    return AdvisorSubjectResolution(
      routingQuestion: trimmed,
      subject: subject,
      source: source,
    );
  }

  return AdvisorSubjectResolution(
    routingQuestion: '$trimmed [active subject: $subject]',
    subject: subject,
    source: source,
  );
}
