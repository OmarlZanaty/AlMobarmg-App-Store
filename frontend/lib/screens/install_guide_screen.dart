import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class InstallGuideScreen extends StatefulWidget {
  const InstallGuideScreen({super.key});

  @override
  State<InstallGuideScreen> createState() => _InstallGuideScreenState();
}

class _InstallGuideScreenState extends State<InstallGuideScreen> {
  int step = 0;

  @override
  Widget build(BuildContext context) {
    final target = detectPlatform();
    final steps = _stepsFor(target);

    return Scaffold(
      appBar: AppBar(title: Text('$target Install Guide')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Card(
                  key: ValueKey(step),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_iconFor(target), size: 72),
                        const SizedBox(height: 16),
                        Text(
                          steps[step],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(_screenshotHint(target)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: step == 0 ? null : () => setState(() => step--),
                  child: const Text('Previous'),
                ),
                OutlinedButton(
                  onPressed: step == steps.length - 1 ? null : () => setState(() => step++),
                  child: const Text('Next'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('I did it — Install now'),
            ),
          ],
        ),
      ),
    );
  }

  String detectPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return _detectIosVersion();
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'Mac';
    if (Platform.isLinux) return 'Linux';
    return 'Device';
  }

  String _detectIosVersion() {
    final version = Platform.operatingSystemVersion;
    if (version.contains('18')) return 'iOS 18';
    if (version.contains('17')) return 'iOS 17';
    if (version.contains('16')) return 'iOS 16';
    if (version.contains('15')) return 'iOS 15';
    return 'iOS';
  }

  List<String> _stepsFor(String platform) {
    if (platform.contains('Android')) {
      return const [
        'Tap Install in Al Mobarmg Store.',
        'If prompted, allow "Install unknown apps" for this app.',
        'Confirm Package Installer and finish setup.',
      ];
    }
    if (platform.contains('iOS')) {
      return const [
        'Open app page in Safari.',
        'Tap Share button in Safari toolbar.',
        'Choose Add to Home Screen then Add.',
      ];
    }
    return const [
      'Click Download for your desktop platform.',
      'Open downloaded installer file.',
      'Follow setup wizard and launch app.',
    ];
  }

  IconData _iconFor(String platform) {
    if (platform.contains('Android')) return Icons.android;
    if (platform.contains('iOS')) return Icons.phone_iphone;
    if (platform.contains('Windows')) return Icons.window;
    if (platform.contains('Mac')) return Icons.laptop_mac;
    return Icons.computer;
  }

  String _screenshotHint(String platform) {
    if (platform.contains('iOS')) return 'Show Safari Share button and Add to Home Screen screenshots.';
    if (platform.contains('Android')) return 'Show Play Protect / Install from source settings screenshots.';
    return 'Show installer download and run screenshots.';
  }
}
