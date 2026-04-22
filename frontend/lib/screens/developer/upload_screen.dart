import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';

class DeveloperUploadScreen extends ConsumerStatefulWidget {
  const DeveloperUploadScreen({super.key});

  @override
  ConsumerState<DeveloperUploadScreen> createState() => _DeveloperUploadScreenState();
}

class _DeveloperUploadScreenState extends ConsumerState<DeveloperUploadScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _versionController = TextEditingController(text: '1.0.0');
  final _shortDescription = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController(text: 'Tools');
  final _iosPwaUrl = TextEditingController();

  File? _androidFile;
  File? _windowsFile;
  File? _macFile;
  List<File> _linuxFiles = [];
  File? _iconFile;
  List<File> _screenshots = [];

  bool _submitting = false;
  double _progress = 0;

  @override
  void dispose() {
    _name.dispose();
    _versionController.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _category.dispose();
    _iosPwaUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload App')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text('Basic information', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'App name',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _versionController,
                decoration: const InputDecoration(
                  labelText: 'Version',
                  hintText: 'x.y.z (example: 1.2.0)',
                  border: OutlineInputBorder(),
                ),
                validator: _validateVersion,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _shortDescription,
                decoration: const InputDecoration(
                  labelText: 'Short description',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _description,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Full description',
                  border: OutlineInputBorder(),
                ),
                validator: _required,
              ),
              const SizedBox(height: 16),
              Text('Platform files', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _platformTile(
                title: 'Android (.apk/.aab)',
                optional: true,
                file: _androidFile,
                onPick: () async {
                  _androidFile = await _pickSingle(['apk', 'aab']);
                  setState(() {});
                },
              ),
              TextFormField(
                controller: _iosPwaUrl,
                decoration: const InputDecoration(
                  labelText: 'iOS PWA URL',
                  helperText:
                      'A PWA URL is a web app link (HTTPS) that iOS users open in Safari and add to Home Screen.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final uri = Uri.tryParse(text);
                  if (uri == null || !uri.hasScheme || uri.scheme != 'https') {
                    return 'Enter a valid HTTPS URL';
                  }
                  return null;
                },
              ),
              _platformTile(
                title: 'Windows (.exe/.msix)',
                optional: true,
                file: _windowsFile,
                onPick: () async {
                  _windowsFile = await _pickSingle(['exe', 'msix']);
                  setState(() {});
                },
              ),
              _platformTile(
                title: 'Mac (.dmg)',
                optional: true,
                file: _macFile,
                onPick: () async {
                  _macFile = await _pickSingle(['dmg']);
                  setState(() {});
                },
              ),
              Card(
                child: ListTile(
                  title: const Text('Linux packages'),
                  subtitle: Text('Selected: ${_linuxFiles.length} file(s) • Optional'),
                  trailing: IconButton(
                    icon: const Icon(Icons.upload_file),
                    onPressed: _pickLinux,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'At least one platform is required before submission.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text('Visual assets', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              _platformTile(
                title: 'App icon',
                optional: false,
                file: _iconFile,
                onPick: () async {
                  _iconFile = await _pickSingle(['png', 'jpg', 'jpeg', 'webp']);
                  setState(() {});
                },
              ),
              Card(
                child: ListTile(
                  title: const Text('Screenshots'),
                  subtitle: Text('Selected: ${_screenshots.length} file(s) • Required: 2 to 8'),
                  trailing: IconButton(
                    icon: const Icon(Icons.photo_library),
                    onPressed: _pickScreenshots,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_submitting) ...[
                LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                const SizedBox(height: 8),
                Text('Uploading ${(100 * _progress).toStringAsFixed(0)}%'),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_submitting ? 'Submitting...' : 'Submit App'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _platformTile({
    required String title,
    required bool optional,
    required File? file,
    required VoidCallback onPick,
  }) {
    final fileName = file == null ? 'No file selected' : file.path.split('/').last;
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text('$fileName ${optional ? '• Optional' : ''}'),
        trailing: IconButton(
          icon: const Icon(Icons.attach_file),
          onPressed: onPick,
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateVersion(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Version is required';
    final semverPattern = RegExp(r'^\d+\.\d+\.\d+$');
    if (!semverPattern.hasMatch(text)) return 'Use x.y.z format (example: 1.0.0)';
    return null;
  }

  bool _hasAtLeastOnePlatform() {
    return _androidFile != null ||
        _windowsFile != null ||
        _macFile != null ||
        _linuxFiles.isNotEmpty ||
        _iosPwaUrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;
    if (!_hasAtLeastOnePlatform()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one platform (Android/iOS/Windows/Mac/Linux).')),
      );
      return;
    }
    if (_iconFile == null || _screenshots.length < 2 || _screenshots.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Provide an app icon and 2–8 screenshots.')),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _progress = 0;
    });

    try {
      await ref.read(apiServiceProvider).uploadApp(
            metadata: {
              'name': _name.text.trim(),
              'version': _versionController.text.trim(),
              'short_description': _shortDescription.text.trim(),
              'description': _description.text.trim(),
              'category': _category.text.trim(),
              if (_iosPwaUrl.text.trim().isNotEmpty) 'ios_pwa_url': _iosPwaUrl.text.trim(),
            },
            androidFile: _androidFile,
            windowsFile: _windowsFile,
            macFile: _macFile,
            linuxFiles: _linuxFiles,
            iconFile: _iconFile,
            screenshots: _screenshots,
            onSendProgress: (sent, total) {
              if (!mounted) return;
              if (total <= 0) return;
              setState(() => _progress = sent / total);
            },
          );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Upload complete'),
          content: const Text('Scan started!'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/developer/dashboard');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<File?> _pickSingle(List<String> extensions) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    final path = result?.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  Future<void> _pickLinux() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['deb', 'appimage', 'rpm'],
    );
    if (result != null) {
      setState(() {
        _linuxFiles = result.paths.whereType<String>().map(File.new).toList();
      });
    }
  }

  Future<void> _pickScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _screenshots = result.paths.whereType<String>().map(File.new).toList();
      });
    }
  }
}
