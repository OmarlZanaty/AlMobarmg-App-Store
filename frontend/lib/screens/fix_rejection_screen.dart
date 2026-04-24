import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../providers.dart';
import 'developer/upload_screen.dart';

class FixRejectionScreen extends ConsumerStatefulWidget {
  const FixRejectionScreen({super.key});

  @override
  ConsumerState<FixRejectionScreen> createState() => _FixRejectionScreenState();
}

class _FixRejectionScreenState extends ConsumerState<FixRejectionScreen> {
  final _reasonController = TextEditingController();

  int _step = 0;
  bool _busy = false;
  File? _androidFile;
  String? _clientSecret;
  String? _reportId;
  String _processingStatus = 'Scanning your app...';
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fix My Rejection — \$4.99')),
      body: Stepper(
        currentStep: _step,
        controlsBuilder: (context, details) {
          if (_step == 2 || _step == 3) return const SizedBox.shrink();
          return Row(
            children: [
              ElevatedButton(
                onPressed: _busy ? null : details.onStepContinue,
                child: Text(_step == 1 ? 'Pay \$4.99' : 'Continue'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _busy || _step == 0 ? null : details.onStepCancel,
                child: const Text('Back'),
              ),
            ],
          );
        },
        onStepContinue: _onContinue,
        onStepCancel: _step > 0 ? () => setState(() => _step--) : null,
        steps: [
          Step(
            title: const Text('Step 1: Rejection Details'),
            isActive: _step == 0,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Upload rejected app file (optional)'),
                  subtitle: Text(_androidFile?.path.split('/').last ?? 'No file selected'),
                  trailing: IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: _pickFile,
                  ),
                ),
                TextField(
                  controller: _reasonController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Paste rejection message from Google/Apple',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Minimum 20 characters required.'),
              ],
            ),
          ),
          Step(
            title: const Text('Step 2: Payment'),
            isActive: _step == 1,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What you get:'),
                const SizedBox(height: 8),
                const Text('• AI diagnosis of rejection type and root cause'),
                const Text('• Actionable fix steps with code examples'),
                const Text('• Clear answer: can this app be published on Al Mobarmg?'),
                const SizedBox(height: 16),
                if (_clientSecret == null)
                  const Text('Preparing secure Stripe payment...')
                else ...[
                  const Text('Card Payment'),
                  const SizedBox(height: 8),
                  CardFormField(
                    style: CardFormStyle(
                      borderColor: Colors.grey.shade300,
                      backgroundColor: Colors.white,
                      borderRadius: 8,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Step(
            title: const Text('Step 3: Processing'),
            isActive: _step == 2,
            content: Column(
              children: [
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_processingStatus),
                const SizedBox(height: 6),
                const Text('Analyzing rejection reason...'),
                const SizedBox(height: 6),
                const Text('Generating fix guide...'),
              ],
            ),
          ),
          Step(
            title: const Text('Step 4: Results'),
            isActive: _step == 3,
            content: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final data = _result ?? {};
    final rejectionType = (data['rejection_type'] ?? 'mixed').toString();
    final rootCause = (data['root_cause'] ?? 'No diagnosis available yet.').toString();
    final steps = (data['fix_steps'] as List?)?.cast<Map>().toList() ?? const [];
    final canPublish = data['can_publish_on_almobarmg'] == true;
    final publishReason = (data['almobarmg_reason'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Chip(
          label: Text(_badgeLabel(rejectionType)),
          backgroundColor: _badgeColor(rejectionType),
        ),
        const SizedBox(height: 8),
        Text('Root cause: $rootCause'),
        const SizedBox(height: 12),
        const Text('Fix steps:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        if (steps.isEmpty)
          const Text('No fix steps returned yet.')
        else
          ...steps.map((s) {
            final stepNumber = s['step']?.toString() ?? '-';
            final action = s['action']?.toString() ?? '';
            final code = s['code_example']?.toString() ?? '';
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 12, child: Text(stepNumber)),
              title: Text(action),
              subtitle: code.isNotEmpty ? Text(code) : null,
            );
          }),
        const Divider(height: 24),
        Text(
          'Can be published on Al Mobarmg? ${canPublish ? 'YES' : 'NO'}',
          style: TextStyle(fontWeight: FontWeight.bold, color: canPublish ? Colors.green : Colors.red),
        ),
        const SizedBox(height: 6),
        Text(publishReason),
        const SizedBox(height: 12),
        const Text('Full report sent to your email'),
        if (canPublish)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeveloperUploadScreen()));
              },
              child: const Text('Publish on Al Mobarmg'),
            ),
          ),
      ],
    );
  }

  Color _badgeColor(String value) {
    switch (value) {
      case 'policy_violation':
        return Colors.orange.shade200;
      case 'security_issue':
        return Colors.red.shade200;
      case 'technical_issue':
        return Colors.blue.shade200;
      default:
        return Colors.purple.shade200;
    }
  }

  String _badgeLabel(String value) {
    switch (value) {
      case 'policy_violation':
        return 'Policy';
      case 'security_issue':
        return 'Security';
      case 'technical_issue':
        return 'Technical';
      default:
        return 'Mixed';
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['apk', 'aab']);
    if (result != null && result.files.single.path != null) {
      setState(() => _androidFile = File(result.files.single.path!));
    }
  }

  Future<void> _onContinue() async {
    if (_step == 0) {
      final reason = _reasonController.text.trim();
      if (reason.length < 20) {
        Fluttertoast.showToast(msg: 'Rejection reason must be at least 20 characters');
        return;
      }
      await _createPaymentIntent();
      return;
    }

    if (_step == 1) {
      await _pay();
    }
  }

  Future<void> _createPaymentIntent() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.createFixRejectionPayment(
        _reasonController.text.trim(),
        androidFile: _androidFile,
      );

      _clientSecret = response['payment_intent_client_secret']?.toString();
      _reportId = response['report_id']?.toString();
      if (_clientSecret == null || _reportId == null) {
        throw Exception('Missing payment details from server');
      }
      setState(() => _step = 1);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Failed to start payment: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pay() async {
    if (_clientSecret == null) {
      Fluttertoast.showToast(msg: 'Payment not ready yet');
      return;
    }

    setState(() => _busy = true);
    try {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _clientSecret!,
        data: const PaymentMethodParams.card(paymentMethodData: PaymentMethodData()),
      );
      setState(() {
        _step = 2;
        _processingStatus = 'Scanning your app...';
      });
      await _pollResult();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Payment failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pollResult() async {
    final api = ref.read(apiServiceProvider);

    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted) return;

      if (i > 5) setState(() => _processingStatus = 'Analyzing rejection reason...');
      if (i > 10) setState(() => _processingStatus = 'Generating fix guide...');

      try {
        final body = await api.getFixRejectionStatus(_reportId!);
        if (body['status'] == 'completed') {
          setState(() {
            _result = Map<String, dynamic>.from(body['ai_diagnosis'] as Map? ?? {});
            _step = 3;
          });
          return;
        }
      } catch (_) {
        // Keep polling until timeout.
      }
    }

    setState(() {
      _step = 3;
      _result = {
        'rejection_type': 'mixed',
        'root_cause': 'Still processing. Please check your email for the final report.',
        'fix_steps': [
          {'step': 1, 'action': 'Wait for scan completion', 'code_example': 'Check your inbox in a few minutes.'},
        ],
        'can_publish_on_almobarmg': false,
        'almobarmg_reason': 'Decision pending full analysis.',
      };
    });
  }
}
