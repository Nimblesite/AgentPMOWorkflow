import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsPanel extends StatefulWidget {
  final String scanDirectory;
  final int intervalMinutes;
  final bool launchdLoaded;
  final ValueChanged<String> onScanDirectoryChanged;
  final ValueChanged<int> onIntervalChanged;
  final VoidCallback onToggleLaunchd;
  final VoidCallback onKick;

  const SettingsPanel({
    super.key,
    required this.scanDirectory,
    required this.intervalMinutes,
    required this.launchdLoaded,
    required this.onScanDirectoryChanged,
    required this.onIntervalChanged,
    required this.onToggleLaunchd,
    required this.onKick,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late TextEditingController _dirController;
  late double _intervalSlider;

  @override
  void initState() {
    super.initState();
    _dirController = TextEditingController(text: widget.scanDirectory);
    _intervalSlider = widget.intervalMinutes.toDouble().clamp(1, 120);
  }

  @override
  void didUpdateWidget(SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanDirectory != widget.scanDirectory) {
      _dirController.text = widget.scanDirectory;
    }
    if (oldWidget.intervalMinutes != widget.intervalMinutes) {
      _intervalSlider = widget.intervalMinutes.toDouble().clamp(1, 120);
    }
  }

  @override
  void dispose() {
    _dirController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings_outlined,
                    color: AppColors.textPrimary, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('SCAN DIRECTORY'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _dirController,
                    hint: '/Users/you/Code',
                    onSubmitted: widget.onScanDirectoryChanged,
                  ),
                  const SizedBox(height: 28),
                  _sectionLabel('REFRESH INTERVAL'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: AppColors.border,
                            thumbColor: AppColors.accent,
                            overlayColor: AppColors.accent.withValues(alpha: 0.1),
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                          ),
                          child: Slider(
                            value: _intervalSlider,
                            min: 1,
                            max: 120,
                            divisions: 119,
                            onChanged: (v) {
                              setState(() => _intervalSlider = v);
                            },
                            onChangeEnd: (v) {
                              widget.onIntervalChanged(v.round());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.headerBg,
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: AppColors.border, width: 1),
                        ),
                        child: Text(
                          '${_intervalSlider.round()} min',
                          style: const TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _sectionLabel('LAUNCHD JOB'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statusDot(widget.launchdLoaded
                          ? AppColors.success
                          : AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        widget.launchdLoaded ? 'Loaded' : 'Not loaded',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.launchdLoaded
                              ? AppColors.success
                              : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _actionButton(
                          label: widget.launchdLoaded ? 'Stop' : 'Start',
                          color: widget.launchdLoaded
                              ? AppColors.error
                              : AppColors.success,
                          onTap: widget.onToggleLaunchd,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionButton(
                          label: 'Force Run',
                          color: AppColors.accent,
                          onTap: widget.onKick,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontFamily: 'Menlo',
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
