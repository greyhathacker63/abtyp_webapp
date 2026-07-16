import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Common function to reload an [InAppWebViewController].
/// It tries to get the current URL and load it, or falls back to reloading the webview.
Future<void> reloadWebView(InAppWebViewController? controller) async {
  if (controller == null) return;
  try {
    final url = await controller.getUrl();
    if (url != null) {
      await controller.loadUrl(urlRequest: URLRequest(url: url));
    } else {
      await controller.reload();
    }
  } catch (e) {
    // Fallback to basic reload if getting/loading URL throws an exception
    await controller.reload();
  }
}
