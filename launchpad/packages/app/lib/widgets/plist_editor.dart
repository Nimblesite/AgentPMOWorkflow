import 'package:flutter/material.dart';
import 'package:launchpad_core/core.dart';

import '../theme.dart';

class PlistEditor extends StatefulWidget {
  final String content;
  final String path;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const PlistEditor({
    super.key,
    required this.content,
    required this.path,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<PlistEditor> createState() => _PlistEditorState();
}

class _PlistEditorState extends State<PlistEditor> {
  late TextEditingController _controller;
  List<String> _errors = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final plistService = PlistService();
    final errors = await plistService.validate(_controller.text);
    setState(() => _errors = errors);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final plistService = PlistService();
      final errors = await plistService.validate(_controller.text);
      if (errors.isNotEmpty) {
        setState(() {
          _errors = errors;
          _saving = false;
        });
        return;
      }
      await plistService.write(widget.path, _controller.text);
      widget.onSaved();
    } catch (e) {
      setState(() {
        _errors = ['Save failed: $e'];
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: _errors.isNotEmpty ? AppColors.error : AppColors.border),
          ),
          child: TextField(
            controller: _controller,
            maxLines: null,
            style: AppTheme.monoStyle.copyWith(fontSize: 11),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            onChanged: (_) {
              if (_errors.isNotEmpty) setState(() => _errors = []);
            },
          ),
        ),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final err in _errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.error, size: 14, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(err,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: _validate,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Validate',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  }
}
