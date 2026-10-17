import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keylol_api/keylol_api.dart';
import 'package:keylol_flutter/bloc/authentication/authentication_bloc.dart';
import 'package:keylol_flutter/repository/authentication_repository.dart';
import 'package:keylol_flutter/repository/web_login_repository.dart';

class StartupAdapter implements HttpClientAdapter {
  bool offline = false;
  bool rejected = false;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (offline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final header = options.headers[HttpHeaders.cookieHeader] as String? ?? '';
    final authenticated =
        !rejected &&
        header.contains('test_auth=session') &&
        header.contains('test_saltkey=salt');
    return ResponseBody.fromString(
      jsonEncode({
        'Variables': {'member_uid': authenticated ? '42' : '0'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late StartupAdapter adapter;
  late CookieJar jar;
  late Keylol client;
  late AuthenticationRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('keylol-cold-start-');
    final previousProcess = PersistCookieJar(
      storage: FileStorage(directory.path),
    );
    await previousProcess.saveFromResponse(keylolOrigin, [
      Cookie('test_auth', 'session')
        ..path = '/'
        ..httpOnly = true
        ..secure = true,
      Cookie('test_saltkey', 'salt')
        ..path = '/'
        ..secure = true,
    ]);
    // New jar, repository and BLoC: no identity survives in memory.
    jar = PersistCookieJar(storage: FileStorage(directory.path));
    adapter = StartupAdapter();
    repository = AuthenticationRepository();
    final dio = Dio(
      BaseOptions(
        baseUrl: keylolOrigin.toString(),
        queryParameters: {'version': 4},
      ),
    )..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      CookieManager(jar),
      AuthenticationInterceptor(repository),
    ]);
    client = Keylol(dio, jar);
  });

  tearDown(() async {
    repository.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'cold start restores identity from disk without opening a login page',
    () async {
      final bloc = AuthenticationBloc(client, repository);
      addTearDown(bloc.close);
      expect(bloc.state.status, AuthenticationStatus.restoring);
      final states = <AuthenticationState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);
      final restored = await bloc.stream
          .firstWhere(
            (state) => state.status == AuthenticationStatus.authenticated,
          )
          .timeout(const Duration(seconds: 2));
      expect(restored.profile.memberUid, '42');
      expect(adapter.requests, 1);
      expect(
        states.any(
          (state) => state.status == AuthenticationStatus.unauthenticated,
        ),
        isFalse,
      );
    },
  );

  test(
    'offline startup keeps disk cookies and restores the account on retry',
    () async {
      adapter.offline = true;
      final bloc = AuthenticationBloc(client, repository);
      addTearDown(bloc.close);
      await bloc.stream
          .firstWhere((state) => state is AuthenticationRestoreFailed)
          .timeout(const Duration(seconds: 2));
      final saved = await PersistCookieJar(storage: FileStorage(directory.path))
          .loadForRequest(keylolOrigin);
      expect(
        saved.any(
          (cookie) => cookie.name == 'test_auth' && cookie.value == 'session',
        ),
        isTrue,
      );
      adapter.offline = false;
      final restored = bloc.stream.firstWhere(
        (state) => state.status == AuthenticationStatus.authenticated,
      );
      bloc.add(AuthenticationStatusFetched());
      expect(
        (await restored.timeout(const Duration(seconds: 2))).profile.memberUid,
        '42',
      );
    },
  );

  test('a rejected saved session becomes unauthenticated', () async {
    adapter.rejected = true;
    final bloc = AuthenticationBloc(client, repository);
    addTearDown(bloc.close);
    await bloc.stream
        .firstWhere(
          (state) => state.status == AuthenticationStatus.unauthenticated,
        )
        .timeout(const Duration(seconds: 2));
    expect(adapter.requests, 1);
  });

  test(
    'first launch without auth cookies does not request a profile',
    () async {
      await jar.deleteAll();
      final bloc = AuthenticationBloc(client, repository);
      addTearDown(bloc.close);
      await bloc.stream
          .firstWhere(
            (state) => state.status == AuthenticationStatus.unauthenticated,
          )
          .timeout(const Duration(seconds: 2));
      expect(adapter.requests, 0);
    },
  );
}
