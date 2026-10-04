import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:to_do_app/components/app_toggle.dart';
import 'package:to_do_app/components/form_controls.dart';
import 'package:to_do_app/components/sync_page_widgets.dart';
import 'package:to_do_app/services/import_from_ics.dart';
import 'package:to_do_app/themes/app_colors.dart';
import '../data/database.dart';

class ImportICSPage extends StatefulWidget {
  const ImportICSPage({super.key});

  @override
  State<ImportICSPage> createState() => _ImportICSPageState();
}

class _ImportICSPageState extends State<ImportICSPage> {
  List<String> repeatTypes = ["none", "daily", "weekly", "monthly", "yearly"];
  List<String> priorityTypes = ["Low", "Medium", "High"];
  List<String> remainderTypes = ["minutes", "hours", "days", "weeks", "none"];
  String _selectedPriority = "Low";

  bool _isStarred = false;

  String _selectedCategory = "None";

  String _selectedRepeatType = "none";

  String _selectedRemainderType = "none";

  TextEditingController remainderAmountController = TextEditingController(
    text: "10",
  );
  List<Map<String, dynamic>> _parsedTasks = [];
  bool _isLoading = false;
  bool _importFailed = false;
  final db = ToDoDataBase();

  Future<void> _handlePickAndParse() async {
    setState(() => _isLoading = true);
    final parsed = await ImportFromIcsService.pickAndParseICS();
    if (!mounted) return;
    setState(() {
      _importFailed = parsed.isEmpty;
      _parsedTasks = parsed;
      _isLoading = false;
    });
  }

  Future<void> _handleImport() async {
    await ImportFromIcsService.importTasksToDB(
      context,
      db,
      _parsedTasks,
      _selectedPriority,
      _selectedCategory,
      _selectedRepeatType,
      int.tryParse(remainderAmountController.text) ?? 0,
      _selectedRemainderType,
      _isStarred,
    );
  }

  @override
  void initState() {
    super.initState();
    db.loadData();
  }

  @override
  void dispose() {
    remainderAmountController.dispose();
    super.dispose();
  }

  Color _priorityDot(String p) {
    final c = context.appColors;
    switch (p) {
      case 'High':
        return c.priorityHigh;
      case 'Medium':
        return c.priorityMedium;
      default:
        return c.priorityLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: syncAppBar(context, "Import Tasks from .ics"),
      body: _parsedTasks.isEmpty ? _buildEmptyState() : _buildParsedState(),
    );
  }

  // ── No file yet / file had no tasks ───────────────────────────────────────

  Widget _buildEmptyState() {
    final colors = context.appColors;
    final failed = _importFailed && !_isLoading;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        child: CustomPaint(
          foregroundPainter: _DashedBorderPainter(
            color: colors.trackOff,
            radius: 20,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    failed ? Icons.warning : Icons.file_upload,
                    size: 44,
                    color:
                        failed ? colors.priorityHigh : context.appColors.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed ? 'No tasks found' : 'No tasks yet',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  failed
                      ? 'The selected .ics file has no tasks.'
                      : 'Select an .ics file to import tasks from a calendar export.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.muted),
                ),
                const SizedBox(height: 20),
                if (_isLoading)
                  SizedBox(
                    height: 48,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: context.appColors.accent,
                      ),
                    ),
                  )
                else
                  _PillButton(
                    icon: Icons.file_upload,
                    label: failed ? 'Choose another file' : 'Select .ics file',
                    onTap: _handlePickAndParse,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tasks parsed ──────────────────────────────────────────────────────────

  Widget _buildParsedState() {
    final colors = context.appColors;
    final cs = Theme.of(context).colorScheme;

    TextStyle bold(double size) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Summary + pick another file
        Row(
          children: [
            Expanded(
              child: Text(
                '${_parsedTasks.length} task${_parsedTasks.length == 1 ? '' : 's'} found',
                style: bold(16),
              ),
            ),
            InkWell(
              onTap: _isLoading ? null : _handlePickAndParse,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_upload,
                      size: 20,
                      color: context.appColors.accent,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Choose another file',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.appColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Parsed tasks
        for (final task in _parsedTasks) ...[
          _ParsedTaskCard(task: task),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),

        // Options applied to every imported task
        Text('Mark these tasks as', style: bold(16)),
        const SizedBox(height: 12),
        OptionsCard(
          rows: [
            OptionRow(
              icon: Icons.star,
              label: 'Star these tasks',
              trailing: AppToggle(
                value: _isStarred,
                onChanged: (value) => setState(() => _isStarred = value),
              ),
            ),
            OptionRow(
              icon: Icons.label_outline,
              label: 'Task category',
              trailing: DropChip(
                value: _selectedCategory,
                options: db.categories,
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
            ),
            OptionRow(
              icon: Icons.notifications,
              label: 'Remind before',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outline),
                    ),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      controller: remainderAmountController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropChip(
                    value: _selectedRemainderType,
                    options: remainderTypes,
                    onChanged:
                        (v) => setState(() => _selectedRemainderType = v),
                  ),
                ],
              ),
            ),
            OptionRow(
              icon: Icons.repeat,
              label: 'Repeat',
              trailing: DropChip(
                value: _selectedRepeatType,
                options: repeatTypes,
                onChanged: (v) => setState(() => _selectedRepeatType = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Priority
        Text(
          'Task priority',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < priorityTypes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: SheetChip(
                  label: priorityTypes[i],
                  selected: _selectedPriority == priorityTypes[i],
                  dotColor: _priorityDot(priorityTypes[i]),
                  center: true,
                  onTap: () {
                    setState(() => _selectedPriority = priorityTypes[i]);
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),

        _PillButton(
          icon: Icons.check_circle,
          label: 'Import to Tasks',
          onTap: _handleImport,
        ),
      ],
    );
  }
}

/// Full-width amber pill button with a leading icon.
class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.accent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: context.appColors.onAccent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One parsed task: title, optional note and due date.
class _ParsedTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  const _ParsedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final muted = context.appColors.muted;
    final note = (task['taskNote'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${task['taskName']}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: muted),
            ),
          ],
          if (task['dueDate'] != null) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: muted),
                const SizedBox(width: 6),
                Text(
                  'Due: ${task['dueDate']}',
                  style: TextStyle(fontSize: 13, color: muted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Dashed rounded-rectangle outline for the file drop zone.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.0;
    const dash = 8.0;
    const gap = 6.0;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path =
        Path()
          ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
