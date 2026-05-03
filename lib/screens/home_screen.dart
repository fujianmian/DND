import 'package:flutter/material.dart';
// import '../services/dnd_service.dart'; // Linking to your existing service

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isDndActive = false; // TODO: Link to DndService.isDndEnabled()

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          Text(
            "Good Morning,",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Let's find your focus.",
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 32),

          // Main Status Card
          Card(
            color: isDndActive
                ? theme.colorScheme.primaryContainer
                : theme.cardTheme.color,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        isDndActive
                            ? Icons.do_not_disturb_on
                            : Icons.do_not_disturb_off,
                        size: 32,
                        color: isDndActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.primary,
                      ),
                      Switch(
                        value: isDndActive,
                        onChanged: (val) {
                          setState(() => isDndActive = val);
                          // TODO: backend havent implement - Call DndService to toggle physical device DND
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isDndActive ? "DND is Active" : "DND is Inactive",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDndActive
                        ? "Triggered by: Deep Work Mode"
                        : "No rules currently active.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDndActive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Smart Suggestion
          Text("Smart Suggestion", style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.nightlight_round,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              title: const Text("Sleep Mode"),
              subtitle: const Text(
                "You often enable DND at 11 PM. Create a rule?",
              ),
              trailing: TextButton(
                onPressed: () {
                  // TODO: backend havent implement - Auto-fill rule wizard based on ML/History
                },
                child: const Text("Set Up"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
