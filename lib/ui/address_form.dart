import 'package:flutter/material.dart';
import '../core/address.dart';
import '../core/format.dart';

/// Asks what the app should call the user and how it refers to itself.
/// Returns null when cancelled.
Future<Address?> askAddress(
  BuildContext context,
  Address current, {
  bool firstRun = false,
}) => showDialog<Address>(
  context: context,
  barrierDismissible: !firstRun,
  builder: (_) => _AddressDialog(current: current, firstRun: firstRun),
);

class _AddressDialog extends StatefulWidget {
  final Address current;
  final bool firstRun;
  const _AddressDialog({required this.current, required this.firstRun});
  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final name = TextEditingController(text: widget.current.name);
  late String self = widget.current.self;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Address get value => Address(name: name.text.trim(), self: self);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = value;
    return AlertDialog(
      icon: Icon(
        widget.firstRun
            ? Icons.waving_hand_rounded
            : Icons.record_voice_over_rounded,
        size: 40,
      ),
      title: Text(widget.firstRun ? 'Chào mừng đến Sổ việc' : 'Xưng hô'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.firstRun) ...[
              const Text(
                'Ứng dụng giúp ghi nhớ việc cần làm, có cả lịch âm. Trước tiên, cho biết cách xưng hô nhé.',
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Ứng dụng nên gọi bạn là gì?',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: name,
              autofocus: !widget.firstRun,
              textCapitalization: TextCapitalization.words,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Bà, Cô Lan, Anh Tuấn',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            Text(
              'Để trống thì ứng dụng gọi là "bạn".',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Ứng dụng tự xưng là', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in Address.selfOptions.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: self == e.key,
                    onSelected: (_) => setState(() => self = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${a.greet(greeting(DateTime.now()))}\n${a.call.isEmpty ? '' : a.call}${a.call.isEmpty ? a.Me : a.self} nhắc ${a.you}: đến giờ uống thuốc rồi${a.a}.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (widget.firstRun) ...[
              const SizedBox(height: 12),
              const Text(
                'Bước tiếp theo, hãy cho phép thông báo để được nhắc đúng giờ.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!widget.firstRun)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Thôi'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context, value),
          child: Text(widget.firstRun ? 'Bắt đầu' : 'Lưu'),
        ),
      ],
    );
  }
}
