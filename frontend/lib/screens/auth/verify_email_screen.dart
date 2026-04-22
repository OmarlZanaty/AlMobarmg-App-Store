import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  static const int _otpLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  late final AnimationController _shakeController;
  Timer? _timer;

  bool _verifying = false;
  bool _resending = false;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeController.dispose();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  bool get _otpComplete => _otp.length == _otpLength && !_controllers.any((c) => c.text.isEmpty);

  Future<void> _verify() async {
    if (!_otpComplete || widget.email.isEmpty) {
      _showMessage('Please enter the 6-digit code');
      return;
    }

    setState(() => _verifying = true);
    FocusScope.of(context).unfocus();

    try {
      await ref.read(apiServiceProvider).verifyEmail(widget.email, _otp);
      if (!mounted) return;
      _showMessage('Email verified!');
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      await _shakeController.forward(from: 0);
      _clearOtp();
      _focusNodes.first.requestFocus();
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _resending || widget.email.isEmpty) return;

    setState(() => _resending = true);
    try {
      await ref.read(apiServiceProvider).resendVerification(widget.email);
      if (!mounted) return;
      _showMessage('A new OTP was sent to your email');
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_cooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _clearOtp() {
    for (final controller in _controllers) {
      controller.clear();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;

    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    email.isEmpty
                        ? 'No email provided. Please register again.'
                        : 'Enter the verification code sent to $email',
                  ),
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final progress = _shakeController.value;
                      final offset = (1 - progress) * 8 * (progress < 0.5 ? 1 : -1);
                      return Transform.translate(offset: Offset(offset, 0), child: child);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_otpLength, (index) {
                        return SizedBox(
                          width: 48,
                          child: TextField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textInputAction: index == _otpLength - 1
                                ? TextInputAction.done
                                : TextInputAction.next,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                              if (digitsOnly != value) {
                                _controllers[index].text = digitsOnly;
                                _controllers[index].selection = TextSelection.fromPosition(
                                  TextPosition(offset: _controllers[index].text.length),
                                );
                              }

                              if (digitsOnly.isNotEmpty && index < _otpLength - 1) {
                                _focusNodes[index + 1].requestFocus();
                              }
                              if (digitsOnly.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              setState(() {});
                            },
                            onSubmitted: (_) {
                              if (index == _otpLength - 1) {
                                _verify();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _verifying || !_otpComplete || email.isEmpty ? null : _verify,
                    child: _verifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_cooldown == 0 && !_resending && email.isNotEmpty) ? _resend : null,
                    child: _resending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _cooldown == 0
                                ? 'Resend OTP'
                                : 'Resend OTP in ${_cooldown.toString().padLeft(2, '0')}s',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
