import 'dart:ui';
import 'package:flutter/material.dart';

// Mock Model strictly for Phase 2 UI demonstration
class DndRule {
  final String id;
  final String name;
  final String triggerSummary;
  final IconData icon;
  bool isActive;

  DndRule({
    required this.id,
    required this.name,
    required this.triggerSummary,
    required this.icon,
    this.isActive = true,
  });
}

class RuleListScreen extends StatefulWidget {
  const RuleListScreen({super.key});

  @override
  State<RuleListScreen> createState() => _RuleListScreenState();
}

class _RuleListScreenState extends State<RuleListScreen> {
  // Start empty to showcase the Ghost UI.
  // Adding a rule will trigger the AnimatedSwitcher.
  final List<DndRule> _rules = [];

  void _addMockRule() {
    setState(() {
      _rules.add(
        DndRule(
          id: DateTime.now().toString(),
          name: 'Deep Work',
          triggerSummary: 'Office • 9:00 AM - 5:00 PM',
          icon: Icons.work_outline,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automation Rules'),
        centerTitle: false,
        scrolledUnderElevation: 0, // Enforces flat minimalist look on scroll
      ),
      // Smooth fade/scale transition between empty state and list
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _rules.isEmpty
            ? _buildEmptyState(colorScheme)
            : _buildRuleList(colorScheme),
      ),
      // Scaffold natively animates the FAB appearance when it transitions from null
      floatingActionButton: _rules.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _addMockRule,
              icon: const Icon(Icons.add),
              label: const Text('New Rule'),
            ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      key: const ValueKey('empty_state'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ghost Rule Card
            CustomPaint(
              painter: DashedBorderPainter(
                color: colorScheme.outlineVariant,
                borderRadius: 16,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 48,
                      color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active rules yet',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Prominent CTA
            FilledButton.icon(
              onPressed: _addMockRule,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Focus Rule'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleList(ColorScheme colorScheme) {
    return ListView.builder(
      key: const ValueKey('rule_list'),
      padding: const EdgeInsets.only(
        top: 8,
        bottom: 88,
      ), // Bottom padding prevents FAB overlap
      itemCount: _rules.length,
      itemBuilder: (context, index) {
        final rule = _rules[index];
        return Card(
          // Inherits elevation & shape from main.dart CardTheme
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(rule.icon, color: colorScheme.primary),
            ),
            title: Text(
              rule.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                rule.triggerSummary,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            trailing: Switch(
              value: rule.isActive,
              onChanged: (bool value) {
                setState(() {
                  rule.isActive = value;
                });
              },
            ),
          ),
        );
      },
    );
  }
}

/// A clean, zero-dependency custom painter for the dashed Ghost Card border.
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 2.0,
    this.dashWidth = 8.0,
    this.dashSpace = 6.0,
    this.borderRadius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    Path path = Path()..addRRect(rrect);
    Path dashedPath = Path();

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0;
      while (distance < measurePath.length) {
        dashedPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
