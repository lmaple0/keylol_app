import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keylol_api/keylol_api.dart';
import 'package:keylol_flutter/repository/web_login_repository.dart';

class ProfileAdapter implements HttpClientAdapter {
  final String uid;
  final int status;
  int requests = 0;
  RequestOptions? lastRequest;
  Completer<void>? gate;

  ProfileAdapter(this.uid, {this.status = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    lastRequest = options;
    await gate?.future;
    return ResponseBody.fromString(
      jsonEncode({
        'Variables': {'member_uid': uid},
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        'set-cookie': ['test_saltkey=renewed; Path=/; Secure; HttpOnly'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late CookieJar destination;
  late Keylol client;

  setUp(() async {
    destination = CookieJar();
    await destination.saveFromResponse(keylolOrigin, [
      Cookie('existing', 'preserved'),
    ]);
    final dio = Dio(BaseOptions(queryParameters: {'version': '4'}));
    dio.interceptors.add(CookieManager(destination));
    client = Keylol(dio, destination);
  });

  WebLoginRepository repository(ProfileAdapter adapter) {
    final probe = Dio(
      BaseOptions(baseUrl: keylolOrigin.toString(), followRedirects: false),
    )..httpClientAdapter = adapter;
    final result = WebLoginRepository(client, probe: probe);
    addTearDown(result.dispose);
    return result;
  }

  test('only the HTTPS forum origin is accepted', () {
    expect(isKeylolOrigin(keylolLoginUri), isTrue);
    for (final url in [
      'http://keylol.com/',
      'https://keylol.com.evil.invalid/',
      'https://evil.invalid/keylol.com',
      'https://keylol.com:8443/',
      'https://user@keylol.com/',
      'javascript:alert(1)',
    ]) {
      expect(isKeylolOrigin(Uri.parse(url)), isFalse, reason: url);
    }
    expect(isKeylolOrigin(null), isFalse);
  });

  test('anonymous browser does not trigger API requests', () async {
    final adapter = ProfileAdapter('0');
    expect(await repository(adapter).importSession([]), isNull);
    expect(adapter.requests, 0);
    expect((await destination.loadForRequest(keylolOrigin)).length, 1);
  });

  test('expired or rejected auth cannot overwrite the app session', () async {
    final adapter = ProfileAdapter('0');
    expect(
      await repository(adapter).importSession([Cookie('test_auth', 'invalid')]),
      isNull,
    );
    final cookies = await destination.loadForRequest(keylolOrigin);
    expect(cookies.map((cookie) => cookie.name), ['existing']);
  });

  test(
    'verified session persists HttpOnly auth and server-renewed cookies',
    () async {
      final adapter = ProfileAdapter('42');
      final expires = DateTime.utc(2030);
      final cookie = Cookie('test_auth', 'session')
        ..path = '/'
        ..secure = true
        ..httpOnly = true
        ..expires = expires;
      final profile = await repository(adapter).importSession([cookie]);
      expect(profile?.memberUid, '42');
      expect(adapter.lastRequest!.uri.host, 'keylol.com');
      expect(adapter.lastRequest!.queryParameters['module'], 'profile');
      expect(adapter.lastRequest!.queryParameters['version'], '4');
      expect(
        adapter.lastRequest!.headers[HttpHeaders.cookieHeader],
        contains('test_auth=session'),
      );
      final cookies = await destination.loadForRequest(keylolOrigin);
      final auth = cookies.singleWhere((value) => value.name == 'test_auth');
      expect(auth.value, 'session');
      expect(auth.httpOnly, isTrue);
      expect(auth.secure, isTrue);
      expect(auth.expires, expires);
      expect(cookies.any((value) => value.name == 'test_saltkey'), isTrue);
    },
  );

  test('network failure leaves app cookies intact and permits retry', () async {
    final adapter = ProfileAdapter('42', status: 503);
    final session = repository(adapter);
    await expectLater(
      session.importSession([Cookie('test_auth', 'session')]),
      throwsA(isA<DioException>()),
    );
    expect((await destination.loadForRequest(keylolOrigin)).length, 1);
    expect(session.probe.interceptors.whereType<CookieManager>(), isEmpty);
  });

  test(
    'closing login while verification is pending does not import cookies',
    () async {
      final adapter = ProfileAdapter('42')..gate = Completer<void>();
      final probe = Dio(BaseOptions(baseUrl: keylolOrigin.toString()))
        ..httpClientAdapter = adapter;
      final session = WebLoginRepository(client, probe: probe);
      final result = session.importSession([Cookie('test_auth', 'session')]);
      while (adapter.requests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      session.dispose();
      adapter.gate!.complete();
      expect(await result, isNull);
      expect((await destination.loadForRequest(keylolOrigin)).length, 1);
    },
  );
}
