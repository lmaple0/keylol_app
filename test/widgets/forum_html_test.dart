import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('forum HTML renders styled content and dispatches links', (
    tester,
  ) async {
    String? tappedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Html(
            data:
                '<p class="quote">引用内容</p>'
                '<a href="https://keylol.com/t123">帖子链接</a>',
            style: {'.quote': Style(color: Colors.red)},
            onLinkTap: (url, attributes, element) => tappedUrl = url,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('引用内容', findRichText: true), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Html(
            data: '<a href="https://keylol.com/t123">帖子链接</a>',
            onLinkTap: (url, attributes, element) => tappedUrl = url,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final link = find.textContaining('帖子链接', findRichText: true);
    // RichText expands to the paragraph width; tap on the actual glyphs.
    await tester.tapAt(tester.getTopLeft(link) + const Offset(12, 8));
    expect(tappedUrl, 'https://keylol.com/t123');
    expect(tester.takeException(), isNull);
  });
}
