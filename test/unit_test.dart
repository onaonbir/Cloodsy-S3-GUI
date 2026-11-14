import 'dart:async';
import 'dart:io';

import 'package:cloodsy_s3_gui/core/api/api_client.dart';
import 'package:cloodsy_s3_gui/core/format.dart';
import 'package:cloodsy_s3_gui/core/i18n.dart';
import 'package:cloodsy_s3_gui/core/i18n_tr.dart';
import 'package:cloodsy_s3_gui/state/transfers_controller.dart';
import 'package:cloodsy_s3_gui/core/presign.dart';
import 'package:cloodsy_s3_gui/core/storage/stores.dart';
import 'package:cloodsy_s3_gui/models/s3_object.dart';
import 'package:cloodsy_s3_gui/models/server_connection.dart';
import 'package:cloodsy_s3_gui/models/server_status.dart';
import 'package:cloodsy_s3_gui/state/navigation_controller.dart';
import 'package:cloodsy_s3_gui/state/objects_controller.dart';
import 'package:cloodsy_s3_gui/state/servers_controller.dart';
import 'package:cloodsy_s3_gui/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_server.dart';

void main() {
  group('format', () {
    test('formatBytes', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(1023), '1023 B');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
      expect(formatBytes(150 * 1024 * 1024), '150 MB');
    });

    test('compareVersions is numeric and ignores v/pre-release', () {
      expect(compareVersions('1.10.0', '1.9.9'), 1);
      expect(compareVersions('v1.3.0', '1.3.0'), 0);
      expect(compareVersions('1.3.0-rc1', '1.3.0'), 0);
      expect(compareVersions('1.2', '1.2.1'), -1);
    });

    test('parseSize', () {
      expect(parseSize('10'), 10 * 1024 * 1024 * 1024);
      expect(parseSize('1.5 gb'), (1.5 * 1024 * 1024 * 1024).round());
      expect(parseSize('512MB'), 512 * 1024 * 1024);
      expect(parseSize('abc'), isNull);
      expect(parseSize('5 PB'), isNull);
    });

    test('formatUptime / formatCount / guessContentType', () {
      expect(formatUptime(93784), '1d 2h 3m');
      expect(formatUptime(59), '0m');
      expect(formatCount(1234567), '1,234,567');
      expect(guessContentType('a/b/photo.JPG'), 'image/jpeg');
      expect(guessContentType('noext'), 'application/octet-stream');
    });
  });

  group('ApiClient', () {
    test('encodes keys segment by segment and builds queries', () {
      expect(ApiClient.keyPath('a b/c?d#e'), 'a%20b/c%3Fd%23e');
      final api = ApiClient(baseUrl: 'https://h:9001');
      final u = api.uri('/buckets/x/objects', {'prefix': 'a b/', 'marker': ''});
      expect(u.path, '/admin/buckets/x/objects');
      expect(u.queryParameters, {'prefix': 'a b/', 'marker': ''});
    });

    test('prefers server error text and reports 401 except for login', () async {
      var unauthorized = 0;
      final api = ApiClient(
        baseUrl: 'http://x',
        client: MockClient((req) async => http.Response(
            '{"error":"bucket is busy: move in progress"}',
            req.url.path.endsWith('/login') ? 401 : 409)),
      )..onUnauthorized = () => unauthorized++;

      await expectLater(
          api.get('/buckets/b'),
          throwsA(isA<ApiException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.message, 'message',
                  'bucket is busy: move in progress')));
      await expectLater(api.post('/login'), throwsA(isA<ApiException>()));
      expect(unauthorized, 0);
    });

    test('non-JSON errors get a readable fallback', () async {
      final api = ApiClient(
          baseUrl: 'http://x',
          client: MockClient((_) async => http.Response('<html>', 502)));
      await expectLater(
          api.get('/status'),
          throwsA(isA<ApiException>()
              .having((e) => e.message, 'message', 'Server unavailable (502)')));
    });

    test('maps transport failures', () {
      expect(ApiClient.connectionError(TimeoutException('x')).message,
          'Connection timed out');
      expect(
          ApiClient.connectionError(const SocketException('refused')).isConnectionError,
          isTrue);
      expect(
          ApiClient.connectionError(http.RequestAbortedException()).isCancelled,
          isTrue);
    });

    test('putBytes sends an empty body (folder markers)', () async {
      late http.Request seen;
      final api = ApiClient(
          baseUrl: 'http://x',
          client: MockClient((req) async {
            seen = req;
            return http.Response('{}', 200);
          }));
      await api.putBytes('/buckets/b/object', const [], query: {'key': 'f/'});
      expect(seen.bodyBytes, isEmpty);
      expect(seen.url.queryParameters['key'], 'f/');
    });
  });

  group('Presigner', () {
    test('matches the AWS SigV4 presigned GET example', () {
      // https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-query-string-auth.html
      final u = Presigner.presign(
        url: Uri.parse('https://examplebucket.s3.amazonaws.com/test.txt'),
        accessKey: 'AKIAIOSFODNN7EXAMPLE',
        secretKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
        expires: const Duration(seconds: 86400),
        now: DateTime.utc(2013, 5, 24),
      );
      expect(u.queryParameters['X-Amz-Signature'],
          'aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404');
    });

    test('path-style object URLs encode keys but keep slashes', () {
      expect(
          Presigner.objectUrl('http://h:9000/', 'b', 'a b/ü?.txt').toString(),
          'http://h:9000/b/a%20b/%C3%BC%3F.txt');
    });
  });

  group('models', () {
    test('ServerStatus tolerates old servers', () {
      final s = ServerStatus.fromJson({'status': 'ok', 'version': '1.2.0'});
      expect(s.isOk, isTrue);
      expect(s.features, isEmpty);
      expect(s.canUpload, isFalse);
      expect(s.storage, isNull);
    });

    test('ServerStatus reads v2 fields', () {
      final s = ServerStatus.fromJson({
        'status': 'ok',
        'features': ['object-upload', 'object-versions'],
        'uptime_seconds': 10,
        'tls': {'s3': true, 'acme': true, 'acme_domains': ['s3.example.com']},
        'storage': {'path': '/d', 'total_bytes': 100, 'free_bytes': 40},
      });
      expect(s.canUpload, isTrue);
      expect(s.canDownload, isFalse);
      expect(s.tls!.acmeDomains, ['s3.example.com']);
      expect(s.storage!.usedFraction, closeTo(0.6, 1e-9));
    });

    test('S3Object names and folder markers', () {
      const o = S3Object(key: 'a/b/c.TXT', size: 1, lastModified: '');
      expect(o.fileName, 'c.TXT');
      expect(o.extension, 'txt');
      const marker = S3Object(key: 'a/b/', size: 0, lastModified: '');
      expect(marker.isFolderMarker, isTrue);
      expect(marker.fileName, 'b');
    });
  });

  group('NavigationController', () {
    test('every destination is reachable and back works', () {
      final nav = NavigationController();
      nav.go(const AdminsDestination());
      nav.go(const DashboardDestination());
      expect(nav.current, const DashboardDestination());
      nav.back();
      expect(nav.current, const AdminsDestination());
    });

    test('tab switches inside a bucket do not add history', () {
      final nav = NavigationController()
        ..go(const BucketsDestination())
        ..go(const BucketDestination('b'))
        ..go(const BucketDestination('b', BucketTab.files))
        ..go(const BucketDestination('b', BucketTab.access));
      nav.back();
      expect(nav.current, const BucketsDestination());
    });

    test('forgetBucket leaves a deleted bucket', () {
      final nav = NavigationController()
        ..go(const BucketDestination('gone', BucketTab.settings));
      nav.forgetBucket('gone');
      expect(nav.current, const BucketsDestination());
      expect(nav.openBucket, isNull);
    });
  });

  group('SessionController', () {
    late FakeServer server;
    late ServersController servers;
    late SessionController session;
    final conn = ServerConnection(
        id: 's1', name: 'Test', url: 'http://fake', username: 'admin');

    setUp(() async {
      server = FakeServer();
      servers = ServersController(MemoryKeyValueStore(), MemorySecretStore());
      await servers.add(conn, 'secret-pass');
      session = SessionController(servers,
          api: ApiClient(client: server.client));
    });

    test('logs in with the saved password and stores the token', () async {
      expect(await session.connect(conn), isTrue);
      expect(session.isLoggedIn, isTrue);
      expect(session.username, 'admin');
      expect(await servers.token('s1'), isNotNull);
    });

    test('wrong password reports the server error', () async {
      await servers.setPassword('s1', 'nope');
      expect(await session.connect(conn), isFalse);
      expect(session.error, 'invalid credentials');
    });

    test('reuses a valid saved token without logging in again', () async {
      await session.connect(conn);
      final second = SessionController(servers,
          api: ApiClient(client: server.client));
      server.requests.clear();
      expect(await second.connect(conn), isTrue);
      expect(server.requests.any((r) => r.url.path.endsWith('/login')), isFalse);
    });

    test('changing the own password keeps the session alive', () async {
      await session.connect(conn);
      // The server revokes all sessions of the user on password change.
      await session.api.put('/admins/admin/password',
          body: {'password': 'new-password-1'});
      await session.ownPasswordChanged('new-password-1');
      expect(session.isLoggedIn, isTrue);
      expect(await servers.password('s1'), 'new-password-1');
      await session.api.get('/status'); // works with the new token
    });

    test('a revoked token is renewed silently with the stored password',
        () async {
      await session.connect(conn);
      server.tokens.clear();
      await expectLater(session.api.get('/status'), throwsA(isA<ApiException>()));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(session.isLoggedIn, isTrue);
      await session.api.get('/status');
    });
  });

  group('i18n', () {
    tearDown(() => I18n.setLocale('en'));

    test('falls back to English and fills placeholders', () {
      I18n.setLocale('en');
      expect(tr('{n} objects deleted', {'n': 3}), '3 objects deleted');
      I18n.setLocale('tr');
      expect(tr('Settings'), 'Ayarlar');
      expect(tr('{n} objects deleted', {'n': 3}), '3 nesne silindi');
      expect(tr('not in the table'), 'not in the table');
      I18n.setLocale('de'); // unsupported → English
      expect(I18n.code, 'en');
    });

    test('every Turkish template keeps the placeholders of its key', () {
      final ph = RegExp(r'\{(\w+)\}');
      for (final e in trTable.entries) {
        final want = ph.allMatches(e.key).map((m) => m[1]).toSet();
        final got = ph.allMatches(e.value).map((m) => m[1]).toSet();
        expect(got, want, reason: e.key);
      }
    });
  });

  group('TransfersController multipart', () {
    late FakeServer server;
    late SessionController session;
    late Directory tmp;

    setUp(() async {
      server = FakeServer();
      final servers =
          ServersController(MemoryKeyValueStore(), MemorySecretStore());
      final conn = ServerConnection(
          id: 's', name: 's', url: 'http://fake', username: 'admin');
      await servers.add(conn, 'secret-pass');
      session = SessionController(servers, api: ApiClient(client: server.client));
      await session.connect(conn);
      tmp = await Directory.systemTemp.createTemp('cloodsy-test');
    });

    tearDown(() => tmp.delete(recursive: true));

    Future<void> settle(TransfersController t) async {
      for (var i = 0; i < 200 && t.activeCount > 0; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    test('splits a large file into parts and reassembles it', () async {
      final data = List<int>.generate(2500, (i) => i % 251);
      final f = File('${tmp.path}/big.bin')..writeAsBytesSync(data);
      final t = TransfersController(session.api)
        ..multipart = true
        ..notifications = false
        ..multipartThreshold = 1000
        ..minPartSize = 1000;
      t.upload('photos', {f: 'big.bin'});
      await settle(t);
      expect(t.items.single.status, TransferStatus.done);
      expect(server.partPuts, 3);
      expect(server.completed['big.bin'], data);
      t.dispose();
    });

    test('a failed upload resumes with the parts already on the server',
        () async {
      final data = List<int>.generate(3000, (i) => (i * 7) % 256);
      final f = File('${tmp.path}/big.bin')..writeAsBytesSync(data);
      server.failPartOnce = 2;
      final t = TransfersController(session.api)
        ..multipart = true
        ..notifications = false
        ..multipartThreshold = 1000
        ..minPartSize = 1000;
      t.upload('photos', {f: 'big.bin'});
      await settle(t);
      final failed = t.items.single;
      expect(failed.status, TransferStatus.failed);
      expect(failed.isMultipart, isTrue);

      t.retry(failed);
      await settle(t);
      expect(t.items.single.status, TransferStatus.done);
      // Part 1 was not uploaded twice.
      expect(server.partPuts, 3);
      expect(server.completed['big.bin'], data);
      t.dispose();
    });
  });

  group('ObjectsController', () {
    late FakeServer server;
    late ObjectsController ctrl;

    setUp(() async {
      server = FakeServer();
      final servers =
          ServersController(MemoryKeyValueStore(), MemorySecretStore());
      final conn = ServerConnection(
          id: 's', name: 's', url: 'http://fake', username: 'admin');
      await servers.add(conn, 'secret-pass');
      final session =
          SessionController(servers, api: ApiClient(client: server.client));
      await session.connect(conn);
      ctrl = ObjectsController(session.api, 'photos');
    });

    test('paginates past the first page', () async {
      for (var i = 0; i < ObjectsController.pageSize + 20; i++) {
        server.objects['f${i.toString().padLeft(4, '0')}.txt'] = i;
      }
      await ctrl.open('');
      expect(ctrl.objects.length, ObjectsController.pageSize);
      expect(ctrl.hasMore, isTrue);
      await ctrl.loadMore();
      expect(ctrl.objects.length, ObjectsController.pageSize + 20);
      expect(ctrl.hasMore, isFalse);
    });

    test('lists folders, hides the folder marker and filters', () async {
      server.objects.addAll({
        'docs/': 0,
        'docs/a.txt': 1,
        'docs/sub/b.txt': 2,
        'docs/report.pdf': 3,
      });
      await ctrl.open('docs/');
      expect(ctrl.folders, ['docs/sub/']);
      expect(ctrl.objects.map((o) => o.key), ['docs/a.txt', 'docs/report.pdf']);
      ctrl.setFilter('rep');
      expect(ctrl.objects.map((o) => o.fileName), ['report.pdf']);
      ctrl.up();
      expect(ctrl.prefix, '');
    });

    test('createFolder writes an empty marker in the current folder',
        () async {
      await ctrl.open('a/');
      await ctrl.createFolder('new');
      expect(server.objects['a/new/'], 0);
    });
  });
}
