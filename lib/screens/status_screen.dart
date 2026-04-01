import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart'; // Allows access to the global automationManager
import '../database/database.dart'; // Allows access to the Rule model

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late Timer _clockTimer;
  // TimeOfDay _currentTime = TimeOfDay.now();

  // Color Palette Constants
  final Color bgColor = const Color(0xFF14110F);
  final Color cardColor = const Color(0xFF34312D);
  final Color primaryTextColor = const Color(0xFFD9C5B2);
  final Color secondaryTextColor = const Color(0xFF7E7F83);

  @override
  void initState() {
    super.initState();
    // Update the clock every minute
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        TimeOfDay.now(); // = TimeOfDay.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'System Status',
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Live Clock Section
            Center(
              child: Text(
                TimeOfDay.now().format(context),
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  color: primaryTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Current Time",
                style: TextStyle(fontSize: 16, color: secondaryTextColor),
              ),
            ),
            const SizedBox(height: 40),

            // 2. DND Status Card (Reactive)
            ValueListenableBuilder<bool>(
              valueListenable: automationManager.isDndEnabled,
              builder: (context, isDndOn, _) {
                return ValueListenableBuilder<Rule?>(
                  valueListenable: automationManager.activeRule,
                  builder: (context, rule, _) {
                    return Card(
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              isDndOn
                                  ? Icons.notifications_off
                                  : Icons.notifications,
                              color: isDndOn
                                  ? primaryTextColor
                                  : secondaryTextColor,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isDndOn ? "DND is ON" : "DND is OFF",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              rule != null
                                  ? "Triggered by: ${rule.name} (${rule.startTime} - ${rule.endTime})"
                                  : "No active rule",
                              style: TextStyle(
                                fontSize: 14,
                                color: secondaryTextColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 20),

            // 3. Next Event Card (Reactive)
            ValueListenableBuilder<String>(
              valueListenable: automationManager.nextChangeText,
              builder: (context, nextText, _) {
                return Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.schedule,
                          color: secondaryTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          nextText,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
