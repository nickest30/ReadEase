import 'dart:async';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../models/word.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';

class PronunciationModal extends StatefulWidget {
  final Word word;
  final int studentId;
  final bool isOnline;
  final bool updateMastery;

  const PronunciationModal({
    super.key,
    required this.word,
    required this.studentId,
    required this.isOnline,
    this.updateMastery = true,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Word word,
    required int studentId,
    required bool isOnline,
    bool updateMastery = true,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => PronunciationModal(
        word: word,
        studentId: studentId,
        isOnline: isOnline,
        updateMastery: updateMastery,
      ),
    );
  }

  @override
  State<PronunciationModal> createState() => _PronunciationModalState();
}

enum _Phase { ready, listening, evaluating, mismatch, success, cooldown, error }

class _PronunciationModalState extends State<PronunciationModal> {
  static const int _maxAttempts = 3;
  static const int _barCount = 40;

  final SpeechToText _speech = SpeechToText();
  final AudioPlayer _audio = AudioPlayer();

  bool _speechInitialized = false;
  bool _speechAvailable = false;

  _Phase _phase = _Phase.ready;
  int _attempts = 0;
  String _lastTranscript = '';
  String? _errorMessage;
  final List<double> _bars = List.filled(_barCount, 0.0);

  bool _evaluateLock = false;
  Timer? _evaluateTimeout;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _evaluateTimeout?.cancel();
    _debounceTimer?.cancel();
    _speech.cancel();
    _audio.dispose();
    super.dispose();
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechInitialized) return _speechAvailable;

    final perm = await Permission.microphone.status;
    if (perm.isPermanentlyDenied) {
      _speechInitialized = true;
      _speechAvailable = false;
      return false;
    }

    final available = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    _speechInitialized = true;
    _speechAvailable = available;
    if (mounted) setState(() {});
    return available;
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      if (_phase == _Phase.listening && !_evaluateLock) {
        // Debounce: give the final result a chance to arrive first
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          if (_phase == _Phase.listening && !_evaluateLock) {
            debugPrint('Debounced evaluate after status done');
            _evaluate();
          }
        });
      }
    }
  }

  void _onSpeechError(dynamic e) {
    final msg = e.errorMsg.toString().toLowerCase();
    debugPrint('Speech error: $msg');

    if (!mounted) return;
    if (_phase != _Phase.listening) return;

    if (msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('unavailable')) {
      setState(() {
        _phase = _Phase.error;
        _errorMessage =
            'Connection dropped or mic interrupted. Tap the mic to try again.';
      });
      return;
    }

    // error_no_match and similar: DEBOUNCE. Android sometimes fires this
    // BEFORE the actual result arrives. Waiting gives the result time.
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      if (_phase == _Phase.listening && !_evaluateLock) {
        debugPrint('Debounced evaluate after error');
        _evaluate();
      }
    });
  }

  Future<void> _onMicTap() async {
    if (!widget.isOnline) return;
    if (_phase == _Phase.listening || _phase == _Phase.evaluating) return;
    if (_phase == _Phase.success || _phase == _Phase.cooldown) return;

    final ready = await _ensureSpeechReady();
    if (!ready) {
      if (!mounted) return;
      _showMicPermissionDialog();
      return;
    }

    final status = await Permission.microphone.request();
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      _showMicPermissionDialog(permanentlyDenied: true);
      return;
    }
    if (!status.isGranted) {
      if (!mounted) return;
      _showMicPermissionDialog();
      return;
    }

    if (!mounted) return;
    _debounceTimer?.cancel();
    _evaluateTimeout?.cancel();
    _evaluateLock = false;
    setState(() {
      _phase = _Phase.listening;
      _lastTranscript = '';
      _errorMessage = null;
      for (int i = 0; i < _barCount; i++) {
        _bars[i] = 0.0;
      }
    });

    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: _onSoundLevel,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 5),
          pauseFor: const Duration(seconds: 2),
          localeId: 'en_US',
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      debugPrint('Listen failed: $e');
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _errorMessage = 'Could not start the microphone. Please try again.';
      });
    }
  }

  void _onSoundLevel(double level) {
    if (!mounted || _phase != _Phase.listening) return;
    final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
    setState(() {
      _bars.removeAt(0);
      _bars.add(normalized);
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords;
    debugPrint(
        'Speech result: "$transcript" final=${result.finalResult}');
    _lastTranscript = transcript;

    if (result.finalResult && !_evaluateLock && _phase == _Phase.listening) {
      _debounceTimer?.cancel();
      _evaluate();
    }
  }

  Future<void> _evaluate() async {
    if (_evaluateLock) return;
    _evaluateLock = true;

    _debounceTimer?.cancel();

    _evaluateTimeout?.cancel();
    _evaluateTimeout = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_phase == _Phase.evaluating || _phase == _Phase.listening) {
        debugPrint('Evaluation timeout, forcing mismatch');
        _finalizeAsMismatch();
      }
    });

    try {
      await _speech.cancel().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      try {
        await _speech.stop().timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _phase = _Phase.evaluating;
      for (int i = 0; i < _barCount; i++) {
        _bars[i] = 0.0;
      }
    });

    final target = _normalize(widget.word.text);
    final heard = _normalize(_lastTranscript);
    final matched = _matches(heard, target);
    debugPrint('EVAL: target="$target" heard="$heard" matched=$matched');

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final latestTranscript = _normalize(_lastTranscript);
    final lateMatched = _matches(latestTranscript, target);
    if (!matched && lateMatched) {
      debugPrint('EVAL: late transcript rescued: "$latestTranscript"');
    }

    _evaluateTimeout?.cancel();

    if (matched || lateMatched) {
      setState(() => _phase = _Phase.success);

      if (widget.updateMastery) {
        try {
          await DatabaseService.instance.markWordMastered(
            studentId: widget.studentId,
            wordId: widget.word.id!,
          );
        } catch (e) {
          debugPrint('Mastery update failed (continuing): $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    }

    _finalizeAsMismatch();
  }

  void _finalizeAsMismatch() {
    if (!mounted) return;
    _evaluateTimeout?.cancel();

    _attempts++;

    if (_attempts >= _maxAttempts) {
      setState(() => _phase = _Phase.cooldown);
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) Navigator.of(context).pop(false);
      });
      return;
    }

    setState(() => _phase = _Phase.mismatch);
  }

  /// Robust match: handles case, punctuation, extra words, and concatenation.
  bool _matches(String heard, String target) {
    if (heard.isEmpty || target.isEmpty) return false;
    if (heard == target) return true;

    // Token match: "the dog" -> contains "dog"
    final tokens = heard.split(RegExp(r'\s+'));
    if (tokens.contains(target)) return true;

    // Concatenation match: "sun flower" -> "sunflower"
    if (heard.replaceAll(' ', '') == target) return true;

    // Contains fallback: "dog barking" contains "dog"
    if (heard.contains(target) && target.length >= 3) return true;

    return false;
  }

  String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '').trim();

  Future<void> _playReference() async {
    final asset = widget.word.audioAsset;
    if (asset.isEmpty) return;
    try {
      final clean = asset.startsWith('assets/')
          ? asset.substring('assets/'.length)
          : asset;
      await _audio.stop();
      await _audio.play(AssetSource(clean));
    } catch (e) {
      debugPrint('Reference audio failed: $e');
    }
  }

  void _showMicPermissionDialog({bool permanentlyDenied = false}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Microphone needed',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        ),
        content: Text(
          permanentlyDenied
              ? 'Microphone access is disabled. Enable it in your device settings to practice pronunciation.'
              : 'Please allow microphone access so ReadEase can hear you.',
          style: const TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:
                const Text('Cancel', style: TextStyle(fontFamily: 'Nunito')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (permanentlyDenied) openAppSettings();
            },
            child: Text(
              permanentlyDenied ? 'Open Settings' : 'OK',
              style: const TextStyle(fontFamily: 'Nunito'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.md,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _handle(),
              const SizedBox(height: AppSpacing.sm),
              _header(),
              const SizedBox(height: AppSpacing.md),
              _imageCard(),
              const SizedBox(height: AppSpacing.md),
              _referenceButton(),
              const SizedBox(height: AppSpacing.md),
              _waveform(),
              const SizedBox(height: AppSpacing.md),
              _mascotAndStatus(),
              const SizedBox(height: AppSpacing.lg),
              _micButton(),
              const SizedBox(height: AppSpacing.sm),
              _attemptFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _handle() => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header() => Row(
        children: [
          Expanded(
            child: Text(
              widget.word.text.toUpperCase(),
              style: AppText.h1.copyWith(
                color: AppColors.accentTeal,
                letterSpacing: 1.5,
                fontSize: 26,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textPrimary),
          ),
        ],
      );

  Widget _imageCard() => Container(
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.studentBg,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          widget.word.imageAsset,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(
            Icons.image_outlined,
            size: 52,
            color: AppColors.textMuted,
          ),
        ),
      );

  Widget _referenceButton() => SizedBox(
        height: 46,
        child: OutlinedButton.icon(
          onPressed: _playReference,
          icon: const Icon(Icons.volume_up_rounded, size: 20),
          label: const Text(
            'Hear it',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w800,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentTeal,
            side: const BorderSide(color: AppColors.accentTeal, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
          ),
        ),
      );

  Widget _waveform() {
    Color borderColor;
    Color barColor;
    switch (_phase) {
      case _Phase.listening:
        borderColor = AppColors.accentTeal;
        barColor = AppColors.accentTeal;
        break;
      case _Phase.evaluating:
        borderColor = AppColors.textMuted;
        barColor = AppColors.border;
        break;
      case _Phase.mismatch:
      case _Phase.cooldown:
      case _Phase.error:
        borderColor = AppColors.accentCoral;
        barColor = AppColors.accentCoral;
        break;
      case _Phase.success:
        borderColor = const Color(0xFF4CAF50);
        barColor = const Color(0xFF4CAF50);
        break;
      case _Phase.ready:
        borderColor = AppColors.border;
        barColor = AppColors.border;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.studentBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: borderColor, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_barCount, (i) {
          final h = 6.0 + _bars[i] * 54.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                height: h,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _mascotAndStatus() {
    String? mascot;
    String text;
    Color color;

    switch (_phase) {
      case _Phase.ready:
        text = widget.isOnline
            ? 'Tap the mic and say the word'
            : 'Pronunciation practice needs internet';
        color =
            widget.isOnline ? AppColors.textMuted : AppColors.textCoral;
        break;
      case _Phase.listening:
        text = 'Listening…';
        color = AppColors.accentTeal;
        break;
      case _Phase.evaluating:
        mascot = 'assets/images/mascot/yse_thinking.png';
        text = 'Checking…';
        color = AppColors.textMuted;
        break;
      case _Phase.mismatch:
        mascot = 'assets/images/mascot/yse_try_again.png';
        text = "That wasn't quite it. Try again!";
        color = AppColors.textCoral;
        break;
      case _Phase.success:
        mascot = 'assets/images/mascot/yse_nice.png';
        text = 'Nice! Great pronunciation.';
        color = AppColors.textTeal;
        break;
      case _Phase.cooldown:
        mascot = 'assets/images/mascot/yse_try_again.png';
        text = "Let's try this word again later.";
        color = AppColors.textCoral;
        break;
      case _Phase.error:
        mascot = 'assets/images/mascot/yse_try_again.png';
        text = _errorMessage ??
            'Something went wrong. Tap the mic to try again.';
        color = AppColors.textCoral;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (mascot != null) ...[
          SizedBox(
            width: 70,
            height: 70,
            child: Image.asset(
              mascot,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (_phase == _Phase.mismatch &&
                  _lastTranscript.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'We heard: "$_lastTranscript"',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _micButton() {
    final enabled = widget.isOnline &&
        _phase != _Phase.listening &&
        _phase != _Phase.evaluating &&
        _phase != _Phase.success &&
        _phase != _Phase.cooldown;

    Color bg;
    switch (_phase) {
      case _Phase.mismatch:
      case _Phase.error:
        bg = AppColors.accentCoral;
        break;
      case _Phase.success:
        bg = const Color(0xFF4CAF50);
        break;
      default:
        bg = enabled
            ? AppColors.accentTeal
            : AppColors.border.withValues(alpha: 0.6);
    }

    return Center(
      child: GestureDetector(
        onTap: enabled ? _onMicTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            _phase == _Phase.listening
                ? Icons.graphic_eq_rounded
                : Icons.mic_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
      ),
    );
  }

  Widget _attemptFooter() => Text(
        'Attempt ${_attempts.clamp(0, _maxAttempts)} of $_maxAttempts',
        textAlign: TextAlign.center,
        style: AppText.caption,
      );
}