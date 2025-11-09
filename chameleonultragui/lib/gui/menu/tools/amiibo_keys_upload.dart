import 'dart:io';
import 'dart:typed_data';
import 'package:chameleonultragui/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

// Localizations
import 'package:chameleonultragui/generated/i18n/app_localizations.dart';

class AmiiboKeysUploadMenu extends StatefulWidget {
  const AmiiboKeysUploadMenu({super.key});

  @override
  State<AmiiboKeysUploadMenu> createState() => AmiiboKeysUploadMenuState();
}

class AmiiboKeysUploadMenuState extends State<AmiiboKeysUploadMenu> {
  bool _isLoading = false;
  bool? _keysLoaded;

  @override
  void initState() {
    super.initState();
    _checkKeysStatus();
  }

  Future<void> _checkKeysStatus() async {
    var appState = context.read<ChameleonGUIState>();
    if (appState.communicator == null) return;

    try {
      final status = await appState.communicator!.amiiboGetKeysStatus();
      if (mounted) {
        setState(() {
          _keysLoaded = status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _keysLoaded = false;
        });
      }
    }
  }

  Future<void> _uploadKeys(AppLocalizations localizations) async {
    var appState = context.read<ChameleonGUIState>();
    if (appState.communicator == null) return;

    // Pick file (allow any file type due to Linux zenity issues with custom extensions)
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result == null) {
      // User cancelled
      return;
    }

    if (result.files.single.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to get file path')),
        );
      }
      return;
    }

    // Read file from path
    File file = File(result.files.single.path!);
    Uint8List fileBytes = await file.readAsBytes();

    // Validate file size
    if (fileBytes.length != 160) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.amiibo_keys_file_invalid)),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload keys to device
      await appState.communicator!.amiiboSetKeys(fileBytes);

      // Save to flash
      await appState.communicator!.saveSettings();

      // Update status
      await _checkKeysStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.amiibo_keys_upload_success)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.amiibo_keys_upload_error)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.amiibo_keys_upload),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status section
            Text(
              localizations.amiibo_keys_current_status,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _keysLoaded == true ? Icons.check_circle : Icons.cancel,
                  color: _keysLoaded == true ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(_keysLoaded == true
                    ? localizations.amiibo_keys_loaded
                    : localizations.amiibo_keys_not_loaded),
              ],
            ),
            const SizedBox(height: 24),
            // Upload button
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _uploadKeys(localizations),
                  icon: const Icon(Icons.upload_file),
                  label: Text(localizations.amiibo_keys_upload_select),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.close),
        ),
      ],
    );
  }
}
