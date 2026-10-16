import 'package:flutter/material.dart';
import 'package:keylol_flutter/screen/login/view/web_sms_login_page.dart';

class LoginWithSmsForm extends StatelessWidget {
  const LoginWithSmsForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('在其乐官方登录页面输入手机号，完成安全验证后获取短信验证码。'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () async {
            final loggedIn = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const WebSmsLoginPage()),
            );
            if (loggedIn == true && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: const Text('打开短信登录'),
        ),
      ],
    );
  }
}
