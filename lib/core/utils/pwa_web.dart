// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist
import 'dart:html' as html;
import 'dart:js_util' as js_util;

bool isPwaInstalled() {
  try {
    final isStandalone = html.window.matchMedia('(display-mode: standalone)').matches;
    bool isSafariStandalone = false;
    try {
      if (js_util.hasProperty(html.window.navigator, 'standalone')) {
        isSafariStandalone = (html.window.navigator as dynamic).standalone == true;
      }
    } catch (_) {}
    return isStandalone || isSafariStandalone;
  } catch (e) {
    return false;
  }
}
