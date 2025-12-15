import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math' as math;
import '../tokenizer.dart';

class ONNXSpamClassifier {
  late Interpreter interpreter;
  late BertTokenizer tokenizer;

  Future<void> init() async {
    try {
      print('🔄 [TFLITE_CLASSIFIER] Starting TFLite model initialization...');

      // Load tokenizer
      print(
        '📝 [TFLITE_CLASSIFIER] Loading tokenizer from assets/tokenizer/vocab.txt...',
      );
      tokenizer = await BertTokenizer.fromAsset("assets/tokenizer/vocab.txt");
      print('✅ [TFLITE_CLASSIFIER] Tokenizer loaded successfully');

      // Load TFLite model from assets
      print(
        '🤖 [TFLITE_CLASSIFIER] Loading TFLite model from assets/tflite/tinybert_fp16.tflite...',
      );
      interpreter = await Interpreter.fromAsset(
        "assets/tflite/tinybert_fp16.tflite",
      );
      print('✅ [TFLITE_CLASSIFIER] TFLite interpreter loaded successfully');

      // Debug: Print input/output tensor shapes
      print('📊 [DEBUG] Model input tensors:');
      for (int i = 0; i < interpreter.getInputTensors().length; i++) {
        final tensor = interpreter.getInputTensor(i);
        print('   Input $i: shape=${tensor.shape}, type=${tensor.type}');
      }
      print('📊 [DEBUG] Model output tensors:');
      for (int i = 0; i < interpreter.getOutputTensors().length; i++) {
        final tensor = interpreter.getOutputTensor(i);
        print('   Output $i: shape=${tensor.shape}, type=${tensor.type}');
      }

      print('✅ [TFLITE_CLASSIFIER] Model initialization complete!');
    } catch (e) {
      print('❌ [TFLITE_CLASSIFIER] Error during initialization:');
      print('   Error Type: ${e.runtimeType}');
      print('   Error Message: $e');
      print('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<double> predict(String text) async {
    try {
      print('🔍 [TFLITE_CLASSIFIER] Starting prediction for text: "$text"');

      final inputIds = tokenizer.tokenizeToIds(text);
      print('   Tokenized IDs count: ${inputIds.length} tokens');

      final attentionMask = inputIds.map((e) => e == 0 ? 0 : 1).toList();
      print('   Attention mask created');

      // Prepare inputs for TFLite - model expects [1, 128] for each input
      print('   Preparing inputs for TFLite...');
      final inputTensor = [inputIds]; // Shape: [1, 128]
      final maskTensor = [attentionMask]; // Shape: [1, 128]

      // Debug: Print actual input dimensions
      print(
        '   🔍 [DEBUG] Input 0 shape: [${inputTensor.length}, ${inputTensor[0].length}]',
      );
      print(
        '   🔍 [DEBUG] Input 1 shape: [${maskTensor.length}, ${maskTensor[0].length}]',
      );
      print('   🔍 [DEBUG] First 10 token IDs: ${inputIds.take(10).toList()}');

      // Run inference - model outputs [1, 2]
      print('   Running TFLite inference...');
      final output = {
        0: [List<double>.filled(2, 0.0)],
      }; // Shape: [1, 2]
      interpreter.runForMultipleInputs([inputTensor, maskTensor], output);
      print('   Inference completed');

      // The model outputs logits for each class. Convert logits -> probability via softmax.
      final logits = (output[0] as List)[0] as List<double>;
      double maxLogit = logits.reduce((a, b) => a > b ? a : b);
      final exps = logits.map((l) => math.exp(l - maxLogit)).toList();
      final sumExp = exps.fold<double>(0.0, (a, b) => a + b);
      final probClass1 = exps[1] / sumExp;
      print(
        '✅ [TFLITE_CLASSIFIER] Prediction complete: logits=${logits}, prob_spam=$probClass1',
      );

      return probClass1;
    } catch (e) {
      print('❌ [TFLITE_CLASSIFIER] Error during prediction:');
      print('   Error Type: ${e.runtimeType}');
      print('   Error Message: $e');
      print('   Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  void cleanup() {
    print('🧹 [TFLITE_CLASSIFIER] Cleaning up resources...');
    try {
      interpreter.close();
      print('✅ [TFLITE_CLASSIFIER] Cleanup complete');
    } catch (e) {
      print('⚠️  [TFLITE_CLASSIFIER] Error during cleanup: $e');
    }
  }
}
