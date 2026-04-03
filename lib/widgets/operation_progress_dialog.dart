import 'package:flutter/material.dart';

class OperationProgressDialog extends StatelessWidget {
  const OperationProgressDialog({super.key, required this.message});

  final String message;

  static Future<void> show(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OperationProgressDialog(message: message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class OperationResultDialog extends StatelessWidget {
  const OperationResultDialog({
    super.key,
    required this.success,
    required this.message,
    this.title,
  });

  final bool success;
  final String message;
  final String? title;

  static Future<void> show(
    BuildContext context, {
    required bool success,
    required String message,
    String? title,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => OperationResultDialog(success: success, message: message, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: success ? Colors.green : colorScheme.error,
        size: 40,
      ),
      title: Text(title ?? (success ? '操作成功' : '操作失败')),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('确定'))],
    );
  }
}
