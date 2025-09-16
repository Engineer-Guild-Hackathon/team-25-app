import 'dart:io' show File;
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/api_service.dart';

// Web専用のimport
import 'dart:ui_web' as ui_web;

class ModelViewerScreen extends StatefulWidget {
  final String sdfData;
  final String moleculeName;
  final String? formula;

  const ModelViewerScreen({
    super.key,
    required this.sdfData,
    required this.moleculeName,
    this.formula,
  });

  @override
  State<ModelViewerScreen> createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  String? _glbUrl;
  Uint8List? _glbData;
  bool _isLoading = true;
  WebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _loadModel();
  }

  void _initializeWebView() {
    if (kIsWeb) {
      // Web版ではWebViewControllerは不要
      return;
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            debugPrint('WebView page started loading: $url');
          },
          onPageFinished: (String url) {
            debugPrint('WebView page finished loading: $url');
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );
  }

  Future<void> _loadModel() async {
    try {
      debugPrint('ModelViewerScreen: Loading GLB data for ${widget.moleculeName}');
      debugPrint('ModelViewerScreen: SDF Data identifier: ${widget.sdfData}');

      // SDFデータをGLBに変換
      final glbData = await ApiService.convertSdfToGlb(widget.sdfData);

      debugPrint('ModelViewerScreen: Generated GLB data size: ${glbData.length} bytes');
      debugPrint('ModelViewerScreen: GLB header: ${glbData.take(12).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      if (kIsWeb) {
        // Web版：Blob URLを作成
        final blob = html.Blob([glbData], 'model/gltf-binary');
        final url = html.Url.createObjectUrlFromBlob(blob);

        debugPrint('ModelViewerScreen: Created Blob URL: $url');

        if (mounted) {
          setState(() {
            _glbData = glbData;
            _glbUrl = url;
            _isLoading = false;
          });
        }
      } else {
        // モバイル版：ファイルシステムに保存
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/molecule_${DateTime.now().millisecondsSinceEpoch}.glb');
        await file.writeAsBytes(glbData);

        debugPrint('ModelViewerScreen: Saved GLB file to: ${file.path}');

        if (mounted) {
          setState(() {
            _glbData = glbData;
            _glbUrl = 'file://${file.path}';
            _isLoading = false;
          });
        }
      }

    } catch (e) {
      debugPrint('ModelViewerScreen: Error loading GLB data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('3Dモデルの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('3Dモデルを読み込み中...'),
                ],
              ),
            )
          : Column(
              children: [
                // Blue header with back arrow and title
                Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    color: Color(0xFF87CEEB), // Sky blue color
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.moleculeName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48), // Balance for back button
                        ],
                      ),
                    ),
                  ),
                ),
                // 3D Viewer area
                Expanded(
                  flex: 3,
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    child: _build3DViewer(),
                  ),
                ),
                // Bottom panel
                Expanded(
                  flex: 2,
                  child: Container(
                    color: const Color(0xFFF0F0F0),
                    child: _buildBottomPanel(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Molecule name and formula
          Text(
            widget.moleculeName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),

          // Formula display
          if (widget.formula != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F3FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB3D9FF), width: 1),
              ),
              child: Text(
                widget.formula!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0066CC),
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Atom color legend
          const Text(
            '原子の色分け:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildAtomLegendsForFormula(widget.formula),
          ),

          const SizedBox(height: 20),

          // Controls section
          const Text(
            '操作方法:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ドラッグ: 回転',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              SizedBox(height: 4),
              Text(
                '• ピンチ: 拡大・縮小',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
              SizedBox(height: 4),
              Text(
                '• 自動回転: ON',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF87CEEB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 2,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 18),
                  SizedBox(width: 8),
                  Text(
                    '閉じる',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 化学式に含まれている原子のみの色分けを生成
  List<Widget> _buildAtomLegendsForFormula(String? formula) {
    if (formula == null || formula.isEmpty) {
      return [];
    }

    // 原子記号と色のマップ（3Dモデルの色と統一）
    final Map<String, Map<String, dynamic>> atomColors = {
      'H': {'name': 'H (水素)', 'color': const Color(0xFFFFFFFF), 'textColor': Colors.grey}, // 白
      'C': {'name': 'C (炭素)', 'color': const Color(0xFF000000), 'textColor': Colors.white}, // 黒
      'N': {'name': 'N (窒素)', 'color': const Color(0xFF0066FF), 'textColor': Colors.white}, // 青
      'O': {'name': 'O (酸素)', 'color': const Color(0xFFFF0000), 'textColor': Colors.white}, // 赤
      'P': {'name': 'P (リン)', 'color': const Color(0xFFFF8000), 'textColor': Colors.white}, // オレンジ
      'S': {'name': 'S (硫黄)', 'color': const Color(0xFFFFFF00), 'textColor': Colors.black}, // 黄色
      'Mg': {'name': 'Mg (マグネシウム)', 'color': const Color(0xFF00FF00), 'textColor': Colors.black}, // 緑
      'Ca': {'name': 'Ca (カルシウム)', 'color': const Color(0xFFDDDDDD), 'textColor': Colors.black}, // 薄いグレー
      'Fe': {'name': 'Fe (鉄)', 'color': const Color(0xFFFF8000), 'textColor': Colors.white}, // オレンジ
      'K': {'name': 'K (カリウム)', 'color': const Color(0xFF8F00FF), 'textColor': Colors.white}, // 紫
      'Na': {'name': 'Na (ナトリウム)', 'color': const Color(0xFF0000FF), 'textColor': Colors.white}, // 青
      'Cl': {'name': 'Cl (塩素)', 'color': const Color(0xFF00FF00), 'textColor': Colors.black}, // 緑
    };

    // 化学式から原子記号を抽出
    final Set<String> foundAtoms = {};
    final RegExp atomRegex = RegExp(r'[A-Z][a-z]?');
    final matches = atomRegex.allMatches(formula);

    for (final match in matches) {
      final atom = match.group(0);
      if (atom != null && atomColors.containsKey(atom)) {
        foundAtoms.add(atom);
      }
    }

    // 見つかった原子の色分けウィジェットを作成
    final List<Widget> legends = [];
    for (final atom in foundAtoms) {
      final atomInfo = atomColors[atom]!;
      legends.add(_buildAtomLegend(
        atomInfo['name'] as String,
        atomInfo['color'] as Color,
        atomInfo['textColor'] as Color,
      ));
    }

    return legends;
  }

  Widget _buildAtomLegend(String label, Color atomColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: atomColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _build3DViewer() {
    if (_glbUrl == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('3Dモデルを準備中...'),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: kIsWeb ? _buildWebThreeJSViewer() : _buildMobileWebView(),
    );
  }

  Widget _buildWebThreeJSViewer() {
    // Web版：Three.jsビューアーを埋め込み
    final encodedMoleculeName = Uri.encodeComponent(widget.moleculeName);
    final encodedGlbUrl = Uri.encodeComponent(_glbUrl!);
    final threejsUrl = 'threejs_viewer.html?glbUrl=$encodedGlbUrl&moleculeName=$encodedMoleculeName';

    // ユニークなviewTypeを作成
    final viewType = 'threejs-viewer-${widget.moleculeName.hashCode}';

    // IFrameElementを作成
    final iframe = html.IFrameElement()
      ..src = threejsUrl
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = 'none'
      ..style.background = '#f5f5f5';

    // プラットフォームビューを登録
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) => iframe);

    return HtmlElementView(viewType: viewType);
  }

  Widget _buildMobileWebView() {
    if (_webViewController == null) {
      return const Center(
        child: Text('WebViewが利用できません'),
      );
    }

    // Mobile版：WebViewでThree.jsビューアーを表示
    final encodedMoleculeName = Uri.encodeComponent(widget.moleculeName);
    final encodedGlbUrl = Uri.encodeComponent(_glbUrl!);
    final threejsUrl = 'assets/threejs_viewer.html?glbUrl=$encodedGlbUrl&moleculeName=$encodedMoleculeName';

    _webViewController!.loadRequest(Uri.parse(threejsUrl));

    return WebViewWidget(controller: _webViewController!);
  }

  @override
  void dispose() {
    // クリーンアップ
    if (_glbUrl != null) {
      if (kIsWeb) {
        // Web版：Blob URLをrevoke
        html.Url.revokeObjectUrl(_glbUrl!);
        debugPrint('ModelViewerScreen: Revoked Blob URL: $_glbUrl');
      } else {
        // モバイル版：ファイル削除
        try {
          final filePath = _glbUrl!.replaceFirst('file://', '');
          final file = File(filePath);
          if (file.existsSync()) {
            file.deleteSync();
            debugPrint('ModelViewerScreen: Cleaned up GLB file: $filePath');
          }
        } catch (e) {
          debugPrint('ModelViewerScreen: Error cleaning up GLB file: $e');
        }
      }
    }
    super.dispose();
  }
}