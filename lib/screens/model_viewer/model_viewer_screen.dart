import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../../services/api_service.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      debugPrint('ModelViewerScreen: Starting to convert SDF to GLB');
      debugPrint('ModelViewerScreen: SDF Data length: ${widget.sdfData.length}');

      // SDFデータをGLBに変換
      final glbData = await ApiService.convertSdfToGlb(widget.sdfData);
      debugPrint('ModelViewerScreen: GLB Data received, size: ${glbData.length} bytes');

      // Web用: Blob URLを作成
      final blob = html.Blob([glbData]);
      final url = html.Url.createObjectUrlFromBlob(blob);

      if (mounted) {
        setState(() {
          _glbUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ModelViewerScreen: Error loading model: $e');
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
      appBar: AppBar(
        title: Text(widget.moleculeName),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
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
          : _glbUrl == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('3Dモデルの読み込みに失敗しました'),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ModelViewer(
                        src: _glbUrl!,
                        alt: '${widget.moleculeName}の3Dモデル',
                        ar: false, // ARは使用せず、通常の3D表示のみ
                        autoRotate: true,
                        cameraControls: true,
                        backgroundColor: const Color(0xFFE0E0E0),
                        loading: Loading.lazy,
                        touchAction: TouchAction.panY,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            widget.moleculeName,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (widget.formula != null && widget.formula!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                widget.formula!,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            '原子の色分け:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: const [
                              _AtomColorChip(element: 'H', color: Colors.white, name: '水素'),
                              _AtomColorChip(element: 'C', color: Colors.black, name: '炭素'),
                              _AtomColorChip(element: 'N', color: Colors.blue, name: '窒素'),
                              _AtomColorChip(element: 'O', color: Colors.red, name: '酸素'),
                              _AtomColorChip(element: 'P', color: Colors.orange, name: 'リン'),
                              _AtomColorChip(element: 'S', color: Colors.yellow, name: '硫黄'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '操作方法:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text('• ドラッグ: 回転'),
                          const Text('• ピンチ: 拡大・縮小'),
                          const Text('• 自動回転: ON'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close),
                            label: const Text('閉じる'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    // Web用: Blob URLをクリーンアップ
    if (_glbUrl != null) {
      html.Url.revokeObjectUrl(_glbUrl!);
    }
    super.dispose();
  }
}

class _AtomColorChip extends StatelessWidget {
  final String element;
  final Color color;
  final String name;

  const _AtomColorChip({
    required this.element,
    required this.color,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: color == Colors.white ? Colors.grey : Colors.transparent,
                width: color == Colors.white ? 1 : 0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$element ($name)',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}