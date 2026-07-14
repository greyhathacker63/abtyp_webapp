import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'web_redirect_stub.dart'
    if (dart.library.html) 'web_redirect_web.dart';

const _initialUrl = 'https://parishad.abtyp.org/';
const _browserUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ParishadApp());
}

class ParishadApp extends StatelessWidget {
  const ParishadApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: WebRedirectPage(),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ABTYP Parishad',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A1538)),
        useMaterial3: true,
      ),
      home: const ParishadWebViewPage(),
    );
  }
}

class ParishadWebViewPage extends StatefulWidget {
  const ParishadWebViewPage({super.key});

  @override
  State<ParishadWebViewPage> createState() => _ParishadWebViewPageState();
}

class _ParishadWebViewPageState extends State<ParishadWebViewPage> {
  InAppWebViewController? _controller;
  PullToRefreshController? _pullToRefreshController;
  double _progress = 0;

  bool get _supportsPullToRefresh => !kIsWeb;

  @override
  void initState() {
    super.initState();
    if (_supportsPullToRefresh) {
      _pullToRefreshController = PullToRefreshController(
        settings: PullToRefreshSettings(color: const Color(0xFF8A1538)),
        onRefresh: () async {
          final controller = _controller;
          if (controller == null) {
            _pullToRefreshController?.endRefreshing();
            return;
          }

          final url = await controller.getUrl();
          if (url != null) {
            await controller.loadUrl(urlRequest: URLRequest(url: url));
          } else {
            await controller.reload();
          }
        },
      );
    }
  }

  Future<bool> _onWillPop() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }

        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(_initialUrl)),
                pullToRefreshController: _pullToRefreshController,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                  preferredContentMode: UserPreferredContentMode.MOBILE,
                  userAgent: _browserUserAgent,
                  thirdPartyCookiesEnabled: true,
                  supportZoom: false,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  builtInZoomControls: false,
                  displayZoomControls: false,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStop: (controller, url) {
                  _pullToRefreshController?.endRefreshing();
                },
                onReceivedError: (controller, request, error) {
                  _pullToRefreshController?.endRefreshing();
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                  if (progress == 100) {
                    _pullToRefreshController?.endRefreshing();
                  }
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onDownloadStartRequest: (controller, downloadStartRequest) async {
                  final url = downloadStartRequest.url.toString();
                  final name = downloadStartRequest.suggestedFilename;

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Starting download: ${name ?? "file"}...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  try {
                    bool hasPermission = true;
                    if (defaultTargetPlatform == TargetPlatform.android) {
                      final androidInfo = await DeviceInfoPlugin().androidInfo;
                      if (androidInfo.version.sdkInt < 29) {
                        final status = await Permission.storage.request();
                        hasPermission = status.isGranted;
                      }
                    }

                    if (!hasPermission) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Storage permission is required to download files.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      return;
                    }

                    FileDownloader.downloadFile(
                      url: url,
                      name: name,
                      onDownloadCompleted: (path) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Downloaded successfully: ${name ?? "file"}'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      onDownloadError: (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Download failed: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error initiating download: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              if (_progress < 1)
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 3,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class WebRedirectPage extends StatefulWidget {
  const WebRedirectPage({super.key});

  @override
  State<WebRedirectPage> createState() => _WebRedirectPageState();
}

class _WebRedirectPageState extends State<WebRedirectPage> {
  @override
  void initState() {
    super.initState();
    redirectToExternalSite(_initialUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Opening ABTYP Parishad in your browser...',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => redirectToExternalSite(_initialUrl),
                child: const Text('Open Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
