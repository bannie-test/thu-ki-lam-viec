import 'package:speech_to_text/speech_to_text.dart';

/// Vietnamese voice input. Wrapped so tests can run without the plugin.
abstract class Voice {
  Future<bool> start(void Function(String words, bool done) onWords);
  Future<void> stop();
}

class PhoneVoice implements Voice {
  final _speech = SpeechToText();
  bool _ready = false;

  @override
  Future<bool> start(void Function(String words, bool done) onWords) async {
    if (!_ready) {
      _ready = await _speech.initialize(onError: (_) {});
    }
    if (!_ready) return false;
    await _speech.listen(
      onResult: (r) => onWords(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 60),
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}

class NoVoice implements Voice {
  @override
  Future<bool> start(void Function(String words, bool done) onWords) async =>
      false;
  @override
  Future<void> stop() async {}
}
