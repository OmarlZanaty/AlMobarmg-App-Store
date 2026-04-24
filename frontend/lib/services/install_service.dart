import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class InstallService {
  InstallService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> installApp({
    required BuildContext context,
    required Map<String, dynamic> app,
    required String platform,
  }) async {
    try {
      switch (platform.toLowerCase()) {
        case 'android':
          await _installAndroid(
            context,
            app['android_download_url']?.toString() ?? app['android_signed_url']?.toString(),
          );
          return;
        case 'iphone':
        case 'ios':
          await _openIosPwa(context, app['pwa_url']?.toString() ?? app['ios_pwa_url']?.toString());
          return;
        case 'windows':
          await _openDesktopInstaller(app['windows_download_url']?.toString(), 'Windows');
          return;
        case 'mac':
        case 'macos':
          await _openDesktopInstaller(app['mac_download_url']?.toString(), 'Mac');
          return;
        case 'linux':
          await _openDesktopInstaller(app['linux_download_url']?.toString(), 'Linux');
          return;
        default:
          throw Exception('Unsupported platform: $platform');
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Install failed: $e');
      rethrow;
    }
  }

  Future<bool> checkInstallPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Install APK'),
            content: const Text('Android will ask for confirmation to install the APK file.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
            ],
          ),
        ) ??
        false;

    return shouldProceed;
  }

  String getInstallButtonLabel(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return 'Install';
      case 'ios':
      case 'iphone':
        return 'Open in Safari';
      case 'windows':
        return 'Download for Windows';
      case 'mac':
      case 'macos':
        return 'Download for Mac';
      case 'linux':
        return 'Download for Linux';
      default:
        return 'Install';
    }
  }

  Future<void> _installAndroid(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) throw Exception('Missing Android signed URL');

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      throw Exception('Could not show install progress');
    }

    final dir = await getTemporaryDirectory();
    final tempPath = '${dir.path}/al_mobarmg_${DateTime.now().millisecondsSinceEpoch}.apk';

    final progressNotifier = ValueNotifier<double>(0);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(days: 1),
        content: ValueListenableBuilder<double>(
          valueListenable: progressNotifier,
          builder: (context, progress, _) {
            final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
            return Text('Downloading APK... $percent%');
          },
        ),
      ),
    );

    await _dio.download(
      url,
      tempPath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          progressNotifier.value = received / total;
        }
      },
    );

    messenger.hideCurrentSnackBar();
    progressNotifier.dispose();

    final apkUri = Uri.file(tempPath);
    final launched = await launchUrl(apkUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      final downloadUri = Uri.parse(url);
      final fallbackLaunched = await launchUrl(downloadUri, mode: LaunchMode.externalApplication);
      if (!fallbackLaunched) throw Exception('Could not open Android installer');
    }

    Fluttertoast.showToast(msg: 'APK ready. Follow Android prompts to complete installation.');
  }

  Future<void> _openIosPwa(BuildContext context, String? pwaUrl) async {
    if (pwaUrl == null || pwaUrl.isEmpty) throw Exception('Missing iOS PWA URL');
    final uri = Uri.parse(pwaUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch Safari');
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _IosGuideSheet(),
    );
  }

  Future<void> _openDesktopInstaller(String? url, String platformName) async {
    if (url == null || url.isEmpty) throw Exception('Missing $platformName download URL');
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw Exception('Could not open installer link for $platformName');
    Fluttertoast.showToast(msg: 'Download started for $platformName');
  }
}

class _IosGuideSheet extends StatefulWidget {
  const _IosGuideSheet();

  @override
  State<_IosGuideSheet> createState() => _IosGuideSheetState();
}

class _IosGuideSheetState extends State<_IosGuideSheet> {
  int step = 0;
  final steps = const [
    '1) Open the website in Safari',
    '2) Tap Share button',
    '3) Choose Add to Home Screen',
    '4) Tap Add to finish',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('iOS 15/16/17/18 PWA install guide', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(steps[step], key: ValueKey(step)),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: step == 0 ? null : () => setState(() => step--),
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: step == steps.length - 1 ? null : () => setState(() => step++),
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
