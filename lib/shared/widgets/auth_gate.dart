import 'package:flutter/material.dart';
import '../../core/constants/app_strings.dart';
import '../../data/services/auth_gate_service.dart';

/// Single entry-point: returns `true` if the user passes the gate (biometric
/// success OR PIN verified OR fresh PIN set up), `false` if they cancel.
///
/// Strategy:
///   1. If biometrics are available, prompt biometric. On success → pass.
///   2. If biometric fails / cancels OR no biometrics enrolled, show the
///      PIN sheet. If a PIN is configured we verify it; otherwise we run
///      the setup flow (enter, confirm, store) and pass on completion.
///
/// [reason] is shown in the biometric system prompt and as the sheet title.
Future<bool> runAuthGate(
  BuildContext context, {
  required String reason,
  AuthGateService? service,
}) async {
  final svc = service ?? AuthGateService();

  if (await svc.isBiometricAvailable()) {
    final ok = await svc.authenticateBiometric(reason);
    if (ok) return true;
    // Biometric prompt was cancelled or failed. We don't auto-fall to PIN
    // here — the user explicitly cancelled, treat that as cancel. If the
    // device has no biometrics at all, we don't even reach this branch.
    return false;
  }

  // No biometrics. Use the PIN sheet.
  if (!context.mounted) return false;
  final hasPin = await svc.hasPin();
  if (!context.mounted) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _PinSheet(
      service: svc,
      title: reason,
      mode: hasPin ? _PinMode.verify : _PinMode.setup,
    ),
  );
  return result == true;
}

enum _PinMode { setup, verify }

class _PinSheet extends StatefulWidget {
  final AuthGateService service;
  final String title;
  final _PinMode mode;
  const _PinSheet({
    required this.service,
    required this.title,
    required this.mode,
  });

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  static const _pinLength = 4;

  /// Setup flow has two stages: 'enter' (first PIN) → 'confirm' (re-enter).
  /// Verify flow only uses 'enter'.
  String _stage = 'enter';
  String _firstPin = '';
  String _input = '';
  String? _error;

  bool get _isSetup => widget.mode == _PinMode.setup;

  String _stageTitle(_L10n s) {
    if (_isSetup) {
      return _stage == 'enter' ? s.tr('createPin') : s.tr('confirmPin');
    }
    return s.tr('enterPin');
  }

  Future<void> _onDigit(String d) async {
    if (_input.length >= _pinLength) return;
    setState(() {
      _input += d;
      _error = null;
    });
    if (_input.length == _pinLength) {
      await _onComplete();
    }
  }

  void _onBackspace() {
    if (_input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = null;
    });
  }

  Future<void> _onComplete() async {
    final s = AppStrings.of(context);
    if (_isSetup) {
      if (_stage == 'enter') {
        setState(() {
          _firstPin = _input;
          _stage = 'confirm';
          _input = '';
        });
        return;
      }
      // confirm
      if (_input == _firstPin) {
        await widget.service.setPin(_input);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _error = s.tr('pinDoesNotMatch');
          _stage = 'enter';
          _firstPin = '';
          _input = '';
        });
      }
      return;
    }
    // verify
    final ok = await widget.service.verifyPin(_input);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = s.tr('incorrectPin');
        _input = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Top row: cancel button + stage title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                Expanded(
                  child: Text(
                    _stageTitle(_L10n(s)),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // visual balance with the IconButton
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _PinDots(filled: _input.length, total: _pinLength, color: cs.primary),
            const SizedBox(height: 8),
            SizedBox(
              height: 18,
              child: _error == null
                  ? const SizedBox.shrink()
                  : Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            _Numpad(onDigit: _onDigit, onBackspace: _onBackspace),
          ],
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int filled;
  final int total;
  final Color color;
  const _PinDots(
      {required this.filled, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? color : Colors.transparent,
            border: Border.all(color: color, width: 2),
          ),
        );
      }),
    );
  }
}

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: cs.surfaceContainerHighest,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap ?? () => onDigit(label),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: child ??
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1', '2', '3'].map(key).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['4', '5', '6'].map(key).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['7', '8', '9'].map(key).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 76), // empty slot to keep 0 centered
            key('0'),
            key(
              '⌫',
              onTap: onBackspace,
              child: Icon(Icons.backspace_outlined, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

/// Thin wrapper to let _PinSheet accept either a `_L10nStrings` (returned
/// from `AppStrings.of(context)`) or a manually-built one — keeps the widget
/// independent from the private `_L10nStrings` symbol.
class _L10n {
  final dynamic _s;
  _L10n(this._s);
  String tr(String key) => _s.tr(key);
}
