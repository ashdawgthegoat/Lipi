import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:lipi_s4_prototype/infrastructure/web/local_asset_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('LocalAssetServer Tests', () {
    final server = LocalAssetServer.instance;

    tearDownAll(() async {
      await server.stop();
    });

    test('LocalAssetServer starts and binds to loopback IPv4', () async {
      final port = await server.ensureStarted();
      expect(port, greaterThan(0));
      expect(server.port, equals(port));
      expect(server.baseUrl, equals('http://127.0.0.1:$port'));
    });

    test('LocalAssetServer custom_template endpoint returns stored bytes with correct mime', () async {
      final port = await server.ensureStarted();
      final testBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // PNG header
      server.setCustomTemplate(testBytes, 'image/png');

      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:$port/custom_template'));
      final response = await request.close();

      expect(response.statusCode, equals(200));
      expect(response.headers.value('content-type'), equals('image/png'));
      expect(response.headers.value('access-control-allow-origin'), equals('*'));

      final receivedBytes = await response.fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
      expect(receivedBytes, equals(testBytes));
      client.close();
    });
  });
}
