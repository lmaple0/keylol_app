import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:keylol_api/keylol_api.dart';

final keylolOrigin = Uri.parse('https://keylol.com/');
final keylolLoginUri = keylolOrigin.resolve(
  'member.php?mod=logging&action=login&mobile=no',
);

bool isKeylolOrigin(Uri? uri) =>
    uri != null &&
    uri.scheme == 'https' &&
    uri.host == keylolOrigin.host &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

/// Import the browser session and confirm it through the app's API client.
class WebLoginRepository {
  final Keylol client;
  final Dio probe;
  bool _disposed = false;

  WebLoginRepository(this.client, {Dio? probe})
    : probe =
          probe ??
          Dio(
            BaseOptions(
              baseUrl: keylolOrigin.toString(),
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              followRedirects: false,
            ),
          );

  Future<DefaultVariables?> importSession(List<Cookie> cookies) async {
    if (_disposed) return null;
    if (!cookies.any(
      (cookie) => cookie.name.endsWith('_auth') && cookie.value.isNotEmpty,
    )) {
      return null;
    }
    // Android reports a domain even for host-only WebView cookies. Keylol's
    // API sets host-only cookies; use that same scope so renewals replace them.
    for (final cookie in cookies) {
      cookie.domain = null;
    }
    final jar = CookieJar();
    await jar.saveFromResponse(keylolOrigin, cookies);
    final manager = CookieManager(jar);
    probe.interceptors.add(manager);
    try {
      final response = await probe.post<Map<String, dynamic>>(
        '/api/mobile/index.php',
        queryParameters: {
          ...client.dio().options.queryParameters,
          'module': 'profile',
        },
      );
      final data = response.data;
      if (data == null || _disposed) return null;
      final profile = ApiResponse.empty(data).variables;
      if ((int.tryParse(profile.memberUid) ?? 0) <= 0) return null;

      // Keylol.create installs the public dio_cookie_manager interceptor.
      final destination = client.dio().interceptors.whereType<CookieManager>();
      if (destination.length != 1) {
        throw StateError('API cookie storage is unavailable');
      }
      // Keep cookies renewed by the profile request as well.
      final verifiedCookies = await jar.loadForRequest(
        keylolOrigin.resolve('/api/mobile/index.php'),
      );
      if (_disposed) return null;
      // A merge leaves old guest cookies at other paths/domains in the request.
      await destination.single.cookieJar.delete(keylolOrigin, true);
      await destination.single.cookieJar.saveFromResponse(
        keylolOrigin,
        verifiedCookies,
      );
      final appResponse = await client.dio().post<Map<String, dynamic>>(
        '/api/mobile/index.php',
        queryParameters: {'module': 'profile'},
      );
      if (_disposed) return null;
      final appProfile = ApiResponse.empty(appResponse.data!).variables;
      return (int.tryParse(appProfile.memberUid) ?? 0) > 0 ? appProfile : null;
    } finally {
      probe.interceptors.remove(manager);
    }
  }

  void dispose() {
    _disposed = true;
    probe.close(force: true);
  }
}
