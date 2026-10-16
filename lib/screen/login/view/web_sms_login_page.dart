import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:keylol_api/keylol_api.dart';
import 'package:keylol_flutter/repository/authentication_repository.dart';
import 'package:keylol_flutter/repository/web_login_repository.dart';
import 'package:keylol_flutter/screen/login/view/sms_login_script.dart';

class WebSmsLoginPage extends StatefulWidget {
  const WebSmsLoginPage({super.key});

  @override
  State<WebSmsLoginPage> createState() => _WebSmsLoginPageState();
}

class _WebSmsLoginPageState extends State<WebSmsLoginPage> {
  final _cookies = CookieManager.instance();
  late final WebLoginRepository _session;
  late final Future<void> _prepare;
  InAppWebViewController? _controller;
  Timer? _timer;
  bool _checking = false;
  bool _verifying = false;
  bool _loading = true;
  bool _finished = false;
  String? _error;
  String? _lastCheckedAuth;

  @override
  void initState() {
    super.initState();
    _session = WebLoginRepository(context.read<Keylol>());
    // Do not accidentally import an old account left in a shared WebView.
    _prepare = _cookies
        .deleteCookies(url: WebUri.uri(keylolOrigin))
        .then((_) {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.dispose();
    super.dispose();
  }

  Future<void> _checkSession({bool manual = false}) async {
    if (_checking || _finished || !mounted) return;
    _checking = true;
    try {
      final currentUrl = await _controller?.getUrl();
      if (!isKeylolOrigin(currentUrl)) return;
      final browserCookies = await _cookies.getCookies(
        url: WebUri.uri(keylolOrigin),
      );
      final auth = browserCookies
          .where((cookie) => cookie.name.endsWith('_auth'))
          .map((cookie) => cookie.value.toString())
          .join(';');
      if (!manual && auth == _lastCheckedAuth) return;
      _lastCheckedAuth = auth;
      if (auth.isNotEmpty && mounted) {
        setState(() => _verifying = true);
      }
      final cookies = browserCookies.map((cookie) {
        final result = io.Cookie(cookie.name, cookie.value.toString())
          ..path = cookie.path ?? '/'
          ..secure = cookie.isSecure ?? true
          ..httpOnly = cookie.isHttpOnly ?? false;
        if (cookie.domain != null) result.domain = cookie.domain!;
        if (cookie.expiresDate != null) {
          result.expires = DateTime.fromMillisecondsSinceEpoch(
            cookie.expiresDate!,
            isUtc: true,
          );
        }
        return result;
      }).toList();
      final profile = await _session.importSession(cookies);
      if (!mounted) return;
      if (profile != null) {
        _finished = true;
        _timer?.cancel();
        context.read<AuthenticationRepository>().profile = profile;
        Navigator.of(context).pop(true);
      } else if (manual) {
        _showMessage('尚未检测到登录，请在网页中完成短信验证并点击登录。');
      }
    } catch (_) {
      // Do not write cookie-bearing requests or responses to app logs.
      if (manual && mounted) _showMessage('登录状态确认失败，请检查网络后重试。');
    } finally {
      _checking = false;
      if (_verifying && mounted) setState(() => _verifying = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('其乐短信登录'),
        actions: [
          IconButton(
            tooltip: '重新加载',
            onPressed: () {
              setState(() => _error = null);
              _controller?.loadUrl(
                urlRequest: URLRequest(url: WebUri.uri(keylolLoginUri)),
              );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('请完成网页中的滑块验证、获取短信并登录，成功后将返回 APP。页面可双指缩放。'),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: FutureBuilder<void>(
              future: _prepare,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('无法初始化登录页面，请返回重试。'));
                }
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri.uri(keylolLoginUri),
                  ),
                  initialSettings: InAppWebViewSettings(
                    useShouldOverrideUrlLoading: true,
                    javaScriptEnabled: true,
                    supportZoom: true,
                    thirdPartyCookiesEnabled: false,
                  ),
                  onWebViewCreated: (controller) {
                    _controller = controller;
                    // Discuz can complete login through AJAX without navigation.
                    _timer = Timer.periodic(
                      const Duration(seconds: 2),
                      (_) => _checkSession(),
                    );
                  },
                  shouldOverrideUrlLoading: (controller, action) async {
                    return isKeylolOrigin(action.request.url)
                        ? NavigationActionPolicy.ALLOW
                        : NavigationActionPolicy.CANCEL;
                  },
                  onLoadStart: (_, url) {
                    if (mounted) setState(() => _loading = true);
                  },
                  onLoadStop: (controller, url) async {
                    if (!mounted) return;
                    setState(() => _loading = false);
                    if (!isKeylolOrigin(url)) return;
                    if (url!.path == '/member.php' &&
                        url.queryParameters['action'] == 'login') {
                      await controller.evaluateJavascript(
                        source: smsLoginScript,
                      );
                    }
                    await _checkSession();
                  },
                  onReceivedError: (_, request, error) {
                    if (request.isForMainFrame == true && mounted) {
                      setState(() {
                        _loading = false;
                        _error = '登录页面加载失败，请检查网络后点击右上角重试。';
                      });
                    }
                  },
                  onReceivedHttpError: (_, request, response) {
                    if (request.isForMainFrame == true && mounted) {
                      setState(() {
                        _loading = false;
                        _error = '登录页面暂时不可用（${response.statusCode}），请稍后重试。';
                      });
                    }
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: TextButton(
              onPressed: _verifying ? null : () => _checkSession(manual: true),
              child: Text(_verifying ? '正在确认登录…' : '已完成网页登录，返回 APP'),
            ),
          ),
        ],
      ),
    );
  }
}
