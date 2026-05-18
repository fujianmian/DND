import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RuleListEmptyState extends StatelessWidget {
  const RuleListEmptyState({
    super.key,
    required this.bottomSafePadding,
    required this.onCreateRule,
  });

  final double bottomSafePadding;
  final VoidCallback onCreateRule;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalPadding = AppTheme.pagePadding * 2;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppTheme.pagePadding,
            verticalPadding,
            AppTheme.pagePadding,
            96 + bottomSafePadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - 96 - bottomSafePadding,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 64,
                    color: AppTheme.logoCyan,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No rules yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.pureBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first rule to automate Do Not Disturb.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.pureBlack.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onCreateRule,
                    icon: const Icon(Icons.add),
                    label: const Text('Create rule'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
