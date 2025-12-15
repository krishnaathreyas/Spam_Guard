## Quick orientation

This Flutter project (spam_guard) is a mobile/cross-platform spam classifier that bundles two TFLite models and JSON tokenizers under `assets/`.

- App entry: `lib/main.dart` (standard Flutter app)
- Core inference: `lib/spam_detector.dart` — loads interpreters and tokenizers and exposes `loadModels()` and `detectSpam(String)`.
- Assets: `assets/models/*.tflite` and `assets/tokenizer/*.json` (declared in `pubspec.yaml`).

If you are an AI coding agent: focus on small, verifiable changes. The codebase is Flutter/Dart; prefer edits that preserve compile and testability (run `flutter pub get` then `flutter test`).

## Architecture & important patterns

- Two separate models for SMS vs Email classification. The code chooses the model by message length in `lib/spam_detector.dart`.
- Tokenization is vocabulary-based: a JSON map string→int in `assets/tokenizer/`. Unknown token id is `100`, pad id is `0`, sequence length is `256`.
- Models and tokenizers live under `assets/` and must match the asset paths declared in `pubspec.yaml`.

Files to inspect when changing inference or assets:
- `lib/spam_detector.dart` — inference wiring, tokenization, model selection.
- `pubspec.yaml` — assets and dependency declarations (notably `tflite_flutter` and `tflite_flutter_helper`).
- `assets/models/*` & `assets/tokenizer/*` — ensure paths and filenames are consistent.

## Build, run, and test (commands you can execute)

- Install deps: `flutter pub get`
- Run on attached device: `flutter run -d <device-id>` (or use your IDE Run action)
- Build Android release: `flutter build apk`
- Build iOS: `flutter build ios` (macOS with Xcode installed)
- Run unit/widget tests: `flutter test`

Notes: native subprojects exist (android/ios/linux/windows/macos); prefer `flutter` top-level commands unless you need to modify platform code.

## Project-specific gotchas & actionable checks for changes

1. Asset path mismatches
   - `pubspec.yaml` lists assets under `assets/models/...` and `assets/tokenizer/...`. Code in `lib/spam_detector.dart` references `models/sms-model.tflite` and `tokenizer/vocab.json`; these paths may not match the actual asset keys. When changing assets or model-loading code, verify with `flutter pub get` and a simple runtime smoke test.

2. loadModels() must be called before inference
   - `lib/spam_detector.dart` uses global `late Interpreter` variables. Ensure `await loadModels()` runs during app initialization (before calling `detectSpam`). Add null-safety or guards if refactoring.

3. Tokenization details
   - Sequence length: 256. Padding id: 0. Unknown token id: 100. The tokenizer uses lowercasing and whitespace splitting — double-check the regex in `tokenize()` if changing token handling.

4. Small helper tests
   - Add a focused unit test that calls `loadModels()` (mocked or with CPU model) and a short `detectSpam()` invocation to ensure wiring is correct after edits.

## Where to look for examples and likely touchpoints

- `lib/main.dart` — app bootstrap. Hook `loadModels()` here so models are ready.
- `lib/spam_detector.dart` — main inference logic. Patch here for model path fixes, tokenization, or output mapping.
- `pubspec.yaml` — when adding/changing assets or updating tflite packages.

## Example fixes an agent might apply

- Fix asset path mismatch: change model load call from `Interpreter.fromAsset('models/sms-model.tflite')` to the path matching `pubspec.yaml` (e.g. `assets/models/sms-model.tflite`), OR update `pubspec.yaml` to expose `models/...` instead of `assets/models/...` (prefer minimal change).
- Add defensive initialization: ensure `loadModels()` is awaited in `main()` and wrap inference calls with a guard that returns a clear error string when interpreters are not ready.

## Do not change without a runtime check

- Any edit to model input shapes, padding, token ids, or vocabulary format must be validated by running a small inference (smoke test) — mismatched shapes will cause runtime exceptions.

## Quick checklist before submitting a PR

- Run `flutter analyze` and `flutter test` locally.
- Confirm asset paths in `pubspec.yaml` and the code match exactly.
- If you modify `lib/spam_detector.dart`, include or update a unit test that loads models (or a mocked substitute) and runs `detectSpam` on a short sample.

---
If anything above is unclear or you want me to expand any section (for example add concrete unit-test scaffolding or fix the asset path mismatches), tell me which part to iterate on.
