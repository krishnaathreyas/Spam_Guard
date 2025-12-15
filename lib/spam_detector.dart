import 'services/tflite_spam_classifier.dart';

class SpamDetector {
  static final SpamDetector instance = SpamDetector._internal();
  SpamDetector._internal();

  final ONNXSpamClassifier classifier =
      ONNXSpamClassifier(); // TFLite classifier
  bool initialized = false;

  // Spam keyword patterns for fallback detection
  static final List<RegExp> _spamPatterns = [
    // Urgency/Threats
    RegExp(
      r'\b(urgent|immediately|act now|limited time|expire|suspended?|blocked?|locked?)\b',
      caseSensitive: false,
    ),
    // Account/Verification scams
    RegExp(
      r'\b(verify|confirm|update).{0,20}\b(account|information|details|identity|credentials)\b',
      caseSensitive: false,
    ),
    // Prize/Money scams
    RegExp(
      r'\b(won|winner|prize|cash|reward|\$\d+|claim|free money|lottery)\b',
      caseSensitive: false,
    ),
    // Phishing links
    RegExp(
      r'\b(click here|tap here|visit|link|http[s]?://(?!.*(google|apple|microsoft|amazon|facebook|twitter|instagram)))\b',
      caseSensitive: false,
    ),
    // Financial threats
    RegExp(
      r'\b(refund|payment|debt|owed|tax|irs|bank|credit card).{0,30}\b(urgent|expire|suspend|verify|update)\b',
      caseSensitive: false,
    ),
    // Generic spam indicators
    RegExp(
      r'\b(congratulations|act fast|don.t miss|limited offer|call now|text back)\b',
      caseSensitive: false,
    ),
  ];

  /// Check if message matches spam keyword patterns
  bool _hasSpamKeywords(String message) {
    final lowerMessage = message.toLowerCase();
    int matchCount = 0;
    List<String> matchedPatterns = [];

    for (int i = 0; i < _spamPatterns.length; i++) {
      final pattern = _spamPatterns[i];
      if (pattern.hasMatch(lowerMessage)) {
        matchCount++;
        matchedPatterns.add('Pattern ${i + 1}');
        if (matchCount >= 2) {
          // If 2+ patterns match, highly likely spam
          print(
            '🎯 [KEYWORD_FILTER] Matched $matchCount patterns: ${matchedPatterns.join(", ")}',
          );
          return true;
        }
      }
    }

    if (matchCount > 0) {
      print(
        'ℹ️ [KEYWORD_FILTER] Matched $matchCount pattern(s): ${matchedPatterns.join(", ")} (need 2+ for spam)',
      );
    }

    return false;
  }

  Future<void> init() async {
    if (!initialized) {
      await classifier.init();
      initialized = true;
    }
  }

  /// Analyze message and return both spam classification and probability in one call
  /// This prevents running the model twice
  Future<({bool isSpam, double probability})> analyzeMessage(
    String message,
  ) async {
    await init(); // ensures initialized

    // Check keyword patterns first (fast fallback)
    final hasKeywords = _hasSpamKeywords(message);

    // Run ML model once
    final mlProb = await classifier.predict(message);

    double finalProb;
    bool isSpam;

    if (hasKeywords) {
      print(
        '🎯 [KEYWORD_FILTER] Spam keywords detected - boosting probability',
      );
      // Boost by 0.3 but cap at 0.95
      finalProb = (mlProb + 0.3).clamp(0.0, 0.95);
      isSpam = true; // Keywords + any ML signal = spam
    } else {
      finalProb = mlProb;
      isSpam =
          mlProb >=
          0.4; // threshold (lowered from 0.5 due to dataset imbalance)
    }

    return (isSpam: isSpam, probability: finalProb);
  }

  // Legacy methods for backwards compatibility
  Future<bool> isSpam(String message) async {
    final result = await analyzeMessage(message);
    return result.isSpam;
  }

  Future<double> getSpamProbability(String message) async {
    final result = await analyzeMessage(message);
    return result.probability;
  }
}
