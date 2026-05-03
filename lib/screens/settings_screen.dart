class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text("Privacy & Data"),
            subtitle: Text("All automation data is stored locally."),
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text("App Permissions"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: backend havent implement - Launch permission request checklist UI
            },
          ),
        ],
      ),
    );
  }
}
