import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:to_do_app/services/AiTaskService.dart';
import 'package:to_do_app/themes/app_colors.dart';

class AiGenerationButton extends StatefulWidget {
  final BuildContext context;
  final TextEditingController goal;
  final String timeframe;
  final void Function(Map<String, dynamic>)? onResult;

  AiGenerationButton({
    super.key,
    required this.timeframe,
    required this.goal,
    this.onResult,
    required this.context,
  });

  @override
  State<AiGenerationButton> createState() => _AiGenerationButtonState();
}

class _AiGenerationButtonState extends State<AiGenerationButton> {
  bool isLoading = false;

  Future<void> callApi(BuildContext context) async {
    try {
      await AiTaskService.generateTasks(
        goal: widget.goal.text,
        timeframe: widget.timeframe,
      ).then((response) {
        if (widget.onResult != null) {
          widget.onResult!(response);
        }

        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tasks generated successfully')),
        );
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Error occurred.Check network connection.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          isLoading
              ? null
              : () {
                isLoading = true;
                callApi(context);
                setState(() {});
              },
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.appColors.accentSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              isLoading
                  ? const SizedBox(
                    key: ValueKey('ai_loading'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: kAccent,
                    ),
                  )
                  : const Icon(
                    Icons.auto_awesome,
                    key: ValueKey('ai_icon'),
                    size: 26,
                    color: kAccent,
                  ),
        ),
      ),
    );
  }
}
