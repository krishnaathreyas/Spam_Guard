import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class BertTokenizer {
  final Map<String, int> vocab;
  final int maxLen;

  BertTokenizer(this.vocab, {this.maxLen = 128});

  static Future<BertTokenizer> fromAsset(String vocabPath) async {
    final vocabData = await rootBundle.loadString(vocabPath);
    final lines = const LineSplitter().convert(vocabData);

    final vocab = <String, int>{};
    for (int i = 0; i < lines.length; i++) {
      vocab[lines[i]] = i;
    }

    return BertTokenizer(vocab);
  }

  List<int> tokenizeToIds(String text) {
    text = text.toLowerCase();

    final tokens = text.split(RegExp(r"\s+"));
    final tokenIds = <int>[];

    tokenIds.add(vocab['[CLS]']!);

    for (final token in tokens) {
      if (vocab.containsKey(token)) {
        tokenIds.add(vocab[token]!);
      } else {
        // WordPiece fallback
        tokenIds.addAll(_wordpiece(token));
      }
    }

    tokenIds.add(vocab['[SEP]']!);

    // pad / truncate
    if (tokenIds.length < maxLen) {
      tokenIds.addAll(List.filled(maxLen - tokenIds.length, vocab['[PAD]']!));
    } else if (tokenIds.length > maxLen) {
      tokenIds.removeRange(maxLen, tokenIds.length);
    }

    return tokenIds;
  }

  List<int> _wordpiece(String word) {
    int start = 0;
    final pieces = <int>[];

    while (start < word.length) {
      int end = word.length;
      String? match;

      while (start < end) {
        String sub = word.substring(start, end);
        if (start > 0) sub = '##$sub';
        if (vocab.containsKey(sub)) {
          match = sub;
          break;
        }
        end--;
      }

      if (match == null) {
        // Use [UNK] token if no match found
        pieces.add(vocab['[UNK]'] ?? 100);
        start += 1;
      } else {
        pieces.add(vocab[match]!);
        start = end;
      }
    }

    return pieces;
  }
}
