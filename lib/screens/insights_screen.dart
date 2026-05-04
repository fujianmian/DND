import 'package:flutter/material.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Insights")),
      body: const Center(
        child: Text(
          "You avoided 120 notifications this week.\n\n// TODO: Backend havent implement stats tracking",
        ),
      ),
    );
  }
}
