import 'package:cloodsy_s3_gui/app.dart';
import 'package:cloodsy_s3_gui/core/api/api_client.dart';
import 'package:cloodsy_s3_gui/core/storage/stores.dart';
import 'package:cloodsy_s3_gui/models/server_connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_server.dart';

void main() {
  late FakeServer server;

  Future<void> pumpApp(WidgetTester tester, {Size size = const Size(1400, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    server = FakeServer();
    final store = MemoryKeyValueStore({
      'servers_list': ServerConnection.encodeList([
        ServerConnection(
            id: 's1', name: 'Test server', url: 'http://fake', username: 'admin'),
      ]),
    });
    await tester.pumpWidget(CloodsyApp(
      store: store,
      secrets: MemorySecretStore({'pw_s1': 'secret-pass'}),
      api: ApiClient(client: server.client),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> connect(WidgetTester tester) async {
    await tester.tap(find.text('Test server'));
    await tester.pumpAndSettle();
  }

  /// Unmount so the session's expiry timer is cancelled.
  Future<void> tearDownApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('connects from the server list and shows the dashboard',
      (tester) async {
    await pumpApp(tester);
    expect(find.text('Choose a server to connect to.'), findsOneWidget);
    await connect(tester);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Largest buckets'), findsOneWidget);
    expect(find.text('photos'), findsWidgets);
    await tearDownApp(tester);
  });

  testWidgets('Admin users can be left again (v1 trapped the user there)',
      (tester) async {
    await pumpApp(tester);
    await connect(tester);

    await tester.tap(find.text('Admin users'));
    await tester.pumpAndSettle();
    expect(find.text('You'), findsOneWidget);

    await tester.tap(find.text('Dashboard').first);
    await tester.pumpAndSettle();
    expect(find.text('Largest buckets'), findsOneWidget);

    await tester.tap(find.text('Admin users'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buckets').first);
    await tester.pumpAndSettle();
    expect(find.text('New bucket'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('theme can be switched, including back to System',
      (tester) async {
    await pumpApp(tester);
    await connect(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.system);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.dark);

    // The first "System" segment is the theme; the second is the language.
    await tester.tap(find.text('System').first);
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.system);
    await tearDownApp(tester);
  });

  testWidgets('quick theme toggle works on the narrow layout', (tester) async {
    await pumpApp(tester, size: const Size(700, 900));
    await connect(tester);
    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    final before = app().themeMode;
    await tester.tap(find.byTooltip(RegExp(r'^Theme:')));
    await tester.pumpAndSettle();
    expect(app().themeMode, isNot(before));
    expect(app().themeMode, isNot(ThemeMode.system));
    await tearDownApp(tester);
  });

  testWidgets('switching to Turkish relabels the UI without losing state',
      (tester) async {
    await pumpApp(tester);
    await connect(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlar'), findsWidgets);
    expect(find.text('Pano'), findsOneWidget); // sidebar entry
    // Still on the settings page: navigation state survived the rebuild.
    expect(find.text('Görünüm'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard'), findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('Ctrl+K opens the command palette and jumps to a page',
      (tester) async {
    await pumpApp(tester);
    await connect(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Type a page, bucket or action…'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'admin');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('You'), findsOneWidget); // admin users page
    await tearDownApp(tester);
  });

  testWidgets('opening a bucket shows its tabs and files', (tester) async {
    await pumpApp(tester);
    server.objects['hello.txt'] = 5;
    await connect(tester);
    await tester.tap(find.text('Buckets').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('photos').first);
    await tester.pumpAndSettle();
    expect(find.text('Lifecycle'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('hello.txt'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    await tearDownApp(tester);
  });
}
