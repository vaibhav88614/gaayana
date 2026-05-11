import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Sleep timer bottom-sheet — requirement #7.
class SleepTimerSheet extends ConsumerStatefulWidget {
  const SleepTimerSheet({super.key});
  @override
  ConsumerState<SleepTimerSheet> createState() => _SleepTimerSheetState();
}

class _SleepTimerSheetState extends ConsumerState<SleepTimerSheet> {
  static const _presets = [5, 10, 15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final timer = ref.read(sleepTimerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sleep timer',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          if (timer.isActive)
            Text(
              timer.firesAt != null
                  ? 'Active — fires at ${TimeOfDay.fromDateTime(timer.firesAt!).format(context)}'
                  : 'Active — pauses after current playback condition',
              style: TextStyle(color: scheme.primary),
            )
          else
            Text('Music will fade out and pause.',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                ChoiceChip(
                  label: Text('$m min'),
                  selected: false,
                  onSelected: (_) {
                    timer.startAfter(Duration(minutes: m));
                    Navigator.pop(context);
                  },
                ),
              ChoiceChip(
                label: const Text('End of track'),
                selected: false,
                onSelected: (_) {
                  timer.startAtEndOfTrack();
                  Navigator.pop(context);
                },
              ),
              ChoiceChip(
                avatar: const Icon(Icons.edit, size: 16),
                label: const Text('Custom…'),
                selected: false,
                onSelected: (_) async {
                  final minutes = await _askCustomMinutes(context);
                  if (minutes != null && minutes > 0) {
                    timer.startAfter(Duration(minutes: minutes));
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
              ChoiceChip(
                avatar: const Icon(Icons.queue_music, size: 16),
                label: const Text('After N tracks…'),
                selected: false,
                onSelected: (_) async {
                  final n = await _askTrackCount(context);
                  if (n != null && n > 0) {
                    timer.startAfterTracks(n);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (timer.isActive)
            OutlinedButton.icon(
              onPressed: () {
                timer.cancel();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.close),
              label: const Text('Cancel timer'),
            ),
        ],
      ),
    );
  }
}

Future<int?> _askCustomMinutes(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Custom sleep timer'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g. 25',
            suffixText: 'min',
          ),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null || n <= 0) return 'Enter a positive number';
            if (n > 24 * 60) return 'Max 1440';
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
          child: const Text('Start'),
        ),
      ],
    ),
  );
}

Future<int?> _askTrackCount(BuildContext context) async {
  final controller = TextEditingController(text: '3');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Stop after N tracks'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tracks',
            hintText: 'e.g. 3',
            suffixText: 'tracks',
          ),
          validator: (v) {
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null || n <= 0) return 'Enter a positive number';
            if (n > 999) return 'Max 999';
            return null;
          },
          onFieldSubmitted: (_) {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.pop(ctx, int.parse(controller.text.trim()));
            }
          },
          child: const Text('Start'),
        ),
      ],
    ),
  );
}
