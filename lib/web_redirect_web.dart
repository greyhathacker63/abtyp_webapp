import 'dart:html' as html;

void redirectToExternalSite(String url) {
  html.window.location.href = url;
}
