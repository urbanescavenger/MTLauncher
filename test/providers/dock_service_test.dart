import 'package:flauncher/providers/dock_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("pin app appends and persists", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());

    await service.pinApp("com.example.a");

    expect(service.packageNames, ["com.example.a"]);
    expect(service.isPinned("com.example.a"), isTrue);

    final reloaded = DockService(await SharedPreferences.getInstance());
    expect(reloaded.packageNames, ["com.example.a"]);
  });

  test("pinning the same app twice keeps a single entry", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());

    await service.pinApp("com.example.a");
    await service.pinApp("com.example.a");

    expect(service.packageNames, ["com.example.a"]);
  });

  test("unpin app removes and persists", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());
    await service.pinApp("com.example.a");

    await service.unpinApp("com.example.a");

    expect(service.packageNames, isEmpty);
    expect(service.isPinned("com.example.a"), isFalse);

    final reloaded = DockService(await SharedPreferences.getInstance());
    expect(reloaded.packageNames, isEmpty);
  });

  test("unpin unknown app is a no-op", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());

    await service.unpinApp("com.example.unknown");

    expect(service.packageNames, isEmpty);
  });

  test("togglePin pins and unpins", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());

    await service.togglePin("com.example.a");
    expect(service.isPinned("com.example.a"), isTrue);

    await service.togglePin("com.example.a");
    expect(service.isPinned("com.example.a"), isFalse);
  });

  test("reorderApp swaps entries in memory", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());
    await service.pinApp("com.example.a");
    await service.pinApp("com.example.b");
    await service.pinApp("com.example.c");

    service.reorderApp(0, 2);

    expect(service.packageNames, ["com.example.b", "com.example.c", "com.example.a"]);
  });

  test("reorderApp ignores out-of-range indices", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());
    await service.pinApp("com.example.a");
    await service.pinApp("com.example.b");

    service.reorderApp(0, 5);
    service.reorderApp(-1, 1);
    service.reorderApp(0, 0);

    expect(service.packageNames, ["com.example.a", "com.example.b"]);
  });

  test("reorderApp is not persisted until saveOrder", () async {
    SharedPreferences.setMockInitialValues({});
    final service = DockService(await SharedPreferences.getInstance());
    await service.pinApp("com.example.a");
    await service.pinApp("com.example.b");

    service.reorderApp(0, 1);

    final notSaved = DockService(await SharedPreferences.getInstance());
    expect(notSaved.packageNames, ["com.example.a", "com.example.b"]);

    await service.saveOrder();
    final saved = DockService(await SharedPreferences.getInstance());
    expect(saved.packageNames, ["com.example.b", "com.example.a"]);
  });

  test("corrupt json loads as empty list", () async {
    SharedPreferences.setMockInitialValues({"dock_apps": "{invalid json"});
    final service = DockService(await SharedPreferences.getInstance());

    expect(service.packageNames, isEmpty);
  });

  test("non-list json loads as empty list", () async {
    SharedPreferences.setMockInitialValues({"dock_apps": "\"not-a-list\""});
    final service = DockService(await SharedPreferences.getInstance());

    expect(service.packageNames, isEmpty);
  });

  test("non-string entries are filtered out", () async {
    SharedPreferences.setMockInitialValues({"dock_apps": "[\"com.example.a\", 42, null]"});
    final service = DockService(await SharedPreferences.getInstance());

    expect(service.packageNames, ["com.example.a"]);
  });
}