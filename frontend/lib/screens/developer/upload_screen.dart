import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../services/api_service.dart';
import '../home_screen.dart';

final uploadStateProvider = StateProvider<double>((_) => 0);

class DeveloperUploadScreen extends ConsumerStatefulWidget {
  const DeveloperUploadScreen({super.key});

  @override
  ConsumerState<DeveloperUploadScreen> createState() => _DeveloperUploadScreenState();
}

class _DeveloperUploadScreenState extends ConsumerState<DeveloperUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 0;

  final _name = TextEditingController();
  final _version = TextEditingController(text: '1.0.0');
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

  @override
  void dispose() {
    _name.dispose();
    _version.dispose();
    _shortDescription.dispose();
    _description.dispose();
    _category.dispose();
    _iosPwaUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(uploadStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upload App')),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _step,
          onStepContinue: _onContinue,
          onStepCancel: _step == 0 ? null : () => setState(() => _step--),
          controlsBuilder: (context, details) {
            return Row(
              children: [
                ElevatedButton(onPressed: details.onStepContinue, child: Text(_step == 3 ? 'Submit' : 'Next')),
                const SizedBox(width: 8),
                TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
              ],
            );
          },
          steps: [
            Step(
              isActive: _step == 0,
              title: const Text('Basic Info'),
              content: Column(children: [
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'App name'), validator: _required),
                TextFormField(controller: _version, decoration: const InputDecoration(labelText: 'Version'), validator: _required),
                TextFormField(
                  controller: _shortDescription,
                  decoration: const InputDecoration(labelText: 'Short description'),
                  validator: _required,
                ),
                TextFormField(controller: _category, decoration: const InputDecoration(labelText: 'Category'), validator: _required),
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Full description'),
                  validator: _required,
                ),
              ]),
            ),
            Step(
              isActive: _step == 1,
              title: const Text('Platform files'),
              content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fileTile('Android (.apk/.aab)', _androidFile, () => _pickSingle(['apk', 'aab'], (f) => _androidFile = f)),
                TextFormField(
                  controller: _iosPwaUrl,
                  decoration: const InputDecoration(labelText: 'iOS PWA URL (https://...)'),
                ),
                _fileTile('Windows (.exe/.msix)', _windowsFile, () => _pickSingle(['exe', 'msix'], (f) => _windowsFile = f)),
                _fileTile('Mac (.dmg)', _macFile, () => _pickSingle(['dmg'], (f) => _macFile = f)),
                ListTile(
                  title: Text('Linux files selected: ${_linuxFiles.length}'),
                  subtitle: const Text('.deb / .appimage / .rpm (multiple)'),
                  trailing: IconButton(icon: const Icon(Icons.upload_file), onPressed: _pickLinux),
                ),
                const SizedBox(height: 8),
                const Text('At least one platform is required.'),
              ]),
            ),
            Step(
              isActive: _step == 2,
              title: const Text('Visual Assets'),
              content: Column(
                children: [
                  _fileTile('App icon', _iconFile, () => _pickSingle(['png', 'jpg', 'jpeg', 'webp'], (f) => _iconFile = f)),
                  ListTile(
                    title: Text('Screenshots selected: ${_screenshots.length}'),
                    subtitle: const Text('2 to 8 images required'),
                    trailing: IconButton(
                      icon: const Icon(Icons.photo_library),
                      onPressed: _pickScreenshots,
                    ),
                  ),
                ],
              ),
            ),
            Step(
              isActive: _step == 3,
              title: const Text('Review & Submit'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${_name.text}'),
                  Text('Category: ${_category.text}'),
                  Text('Version: ${_version.text}'),
                  Text('Android: ${_androidFile?.path.split('/').last ?? 'Not provided'}'),
                  Text('iOS PWA: ${_iosPwaUrl.text.isEmpty ? 'Not provided' : _iosPwaUrl.text}'),
                  Text('Windows: ${_windowsFile?.path.split('/').last ?? 'Not provided'}'),
                  Text('Mac: ${_macFile?.path.split('/').last ?? 'Not provided'}'),
                  Text('Linux files: ${_linuxFiles.length}'),
                  Text('Screenshots: ${_screenshots.length}'),
                  const SizedBox(height: 12),
                  LinearPercentIndicator(
                    lineHeight: 16,
                    percent: progress.clamp(0, 1),
                    center: Text('${(progress * 100).toStringAsFixed(0)}%'),
                  ),
                  if (_submitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(children: [CircularProgressIndicator(), SizedBox(width: 12), Text('Submitting to security scan...')]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'Required' : null;

  Future<void> _onContinue() async {
    if (_step == 0 && !_formKey.currentState!.validate()) return;
    if (_step == 1) {
      final hasPlatform = _androidFile != null ||
          _windowsFile != null ||
          _macFile != null ||
          _linuxFiles.isNotEmpty ||
          _iosPwaUrl.text.trim().isNotEmpty;
      if (!hasPlatform) {
        Fluttertoast.showToast(msg: 'Please add at least one platform');
        return;
      }
    }
    if (_step == 2) {
      if (_iconFile == null || _screenshots.length < 2 || _screenshots.length > 8) {
        Fluttertoast.showToast(msg: 'Icon and 2-8 screenshots are required');
        return;
      }
    }
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(apiServiceProvider).uploadApp(
            metadata: {
              'name': _name.text.trim(),
              'version': _version.text.trim(),
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
              if (total > 0) {
                ref.read(uploadStateProvider.notifier).state = sent / total;
              }
            },
          );
      Fluttertoast.showToast(msg: 'Upload submitted to security scan queue');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Upload failed: $e');
    } finally {
      setState(() => _submitting = false);
    }
  }

  Widget _fileTile(String title, File? file, VoidCallback onPick) {
    final fileName = file?.path.split('/').last ?? 'No file selected';
    final fileSize = file == null ? '' : ' • ${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB';
    return ListTile(
      title: Text(title),
      subtitle: Text('$fileName$fileSize'),
      trailing: IconButton(icon: const Icon(Icons.attach_file), onPressed: () async {
        onPick();
        setState(() {});
      }),
    );
  }

  Future<void> _pickSingle(List<String> ext, void Function(File?) assign) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ext);
    if (result != null && result.files.single.path != null) assign(File(result.files.single.path!));
  }

  Future<void> _pickLinux() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['deb', 'appimage', 'rpm'],
    );
    if (result != null) {
      _linuxFiles = result.paths.whereType<String>().map(File.new).toList();
      setState(() {});
    }
  }

  Future<void> _pickScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      _screenshots = result.paths.whereType<String>().map(File.new).toList();
      setState(() {});
    }
  }
}
