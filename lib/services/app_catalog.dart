import 'dart:typed_data';

import 'dnd_service.dart';

class AppCatalogEntry {
  const AppCatalogEntry({
    required this.packageName,
    required this.name,
    this.iconBytes,
  });

  final String packageName;
  final String name;
  final Uint8List? iconBytes;

  factory AppCatalogEntry.fromInstalledApp(Map<String, dynamic> app) {
    final packageName = app['package'] as String;
    return AppCatalogEntry(
      packageName: packageName,
      name: app['name'] as String? ?? packageName,
      iconBytes: app['icon'] as Uint8List?,
    );
  }

  factory AppCatalogEntry.fromAppInfo(
    String packageName,
    Map<String, dynamic> appInfo,
  ) {
    return AppCatalogEntry(
      packageName: packageName,
      name: appInfo['name'] as String? ?? packageName,
      iconBytes: appInfo['icon'] as Uint8List?,
    );
  }
}

class AppCatalog {
  final Map<String, AppCatalogEntry> _byPackage = {};
  List<AppCatalogEntry>? _installedApps;

  Future<List<AppCatalogEntry>> loadInstalledApps({bool force = false}) async {
    if (!force && _installedApps != null) return _installedApps!;

    final apps = await DndService.getInstalledApps();
    final entries = apps.map(AppCatalogEntry.fromInstalledApp).toList();
    _installedApps = entries;
    for (final entry in entries) {
      _byPackage[entry.packageName] = entry;
    }
    return entries;
  }

  Future<AppCatalogEntry?> loadAppInfo(String packageName) async {
    final cached = _byPackage[packageName];
    if (cached != null) return cached;

    final appInfo = await DndService.getAppInfo(packageName);
    final entry = appInfo == null
        ? AppCatalogEntry(packageName: packageName, name: packageName)
        : AppCatalogEntry.fromAppInfo(packageName, appInfo);
    _byPackage[packageName] = entry;
    return entry;
  }

  AppCatalogEntry? cachedEntry(String packageName) {
    return _byPackage[packageName];
  }

  String labelFor(String? packageName) {
    if (packageName == null || packageName.isEmpty) return 'Not selected';
    return _byPackage[packageName]?.name ?? packageName;
  }
}

final appCatalog = AppCatalog();
