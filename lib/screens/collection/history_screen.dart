import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:team_25_app/screens/collection/widgets/history_list.dart';
import 'package:team_25_app/screens/collection/widgets/history_tab_bar.dart';
import 'package:team_25_app/screens/services/history_store.dart';

import '../../models/detection_result.dart';
import '../../services/api_service.dart';
import '../result/result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);

    // モックデータを初期化（デバッグ用）
    HistoryStore.initMockData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;

    final filter = _tabController.index == 0
        ? HistoryFilter.favorites
        : HistoryFilter.all;
    HistoryStore.setFilter(filter);
  }

  Future<void> _pickFromGallery() async {
    if (_isLoading) return;

    debugPrint('Starting web image picker');

    // Web用のファイル選択
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.click();

    await uploadInput.onChange.first;
    if (uploadInput.files?.isEmpty ?? true) {
      debugPrint('No file selected');
      return;
    }

    final file = uploadInput.files!.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoadEnd.first;

    final bytes = reader.result as Uint8List;
    await _processWebImage(bytes, file.type ?? 'image/jpeg', file.name);
  }

  Future<void> _pickFromCamera() async {
    if (_isLoading) return;

    debugPrint('Starting web camera capture');

    // Web用のカメラキャプチャ（MediaDevices API）
    try {
      // カメラアクセスのUIを表示
      await showDialog(
        context: context,
        builder: (context) => _WebCameraDialog(
          onImageCaptured: (Uint8List bytes) {
            Navigator.of(context).pop();
            _processWebImage(bytes, 'image/png', 'camera_capture.png');
          },
        ),
      );
    } catch (e) {
      debugPrint('Camera error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カメラアクセスエラー: $e')),
      );
    }
  }

  Future<void> _processWebImage(Uint8List imageBytes, String mimeType, String fileName) async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Calling API with web image...');
      final DetectionResult result = await ApiService.analyzeImage(
        imageBytes,
        mimeType,
      );
      debugPrint('API response received: ${result.objectName}');

      HistoryStore.add(
        HistoryItem(
          objectName: result.objectName,
          viewedAt: DateTime.now(),
          molecules: result.molecules,
          imageBytes: imageBytes,
          fileName: fileName,
          topMolecule: result.molecules.isNotEmpty
              ? result.molecules.first
              : null,
        ),
      );

      if (!mounted) return;

      // 結果画面へ（mainブランチと同じUIを使用）
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              ResultScreen(imageBytes: imageBytes, detection: result),
        ),
      );
    } catch (e) {
      debugPrint('API error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('解析に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/images/app_bar_icon.svg',
              height: 32,
              width: 32,
            ),
          ],
        ),
        elevation: 0,
      ),
      floatingActionButton: _isLoading
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // アルバム選択用FAB
                FloatingActionButton(
                  heroTag: "album",
                  onPressed: _pickFromGallery,
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 12),
                // カメラ撮影用FAB
                FloatingActionButton(
                  heroTag: "camera",
                  onPressed: _pickFromCamera,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // タブバー
            HistoryTabBar(tabController: _tabController),

            // 履歴リスト本体
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  // お気に入りタブ
                  HistoryList(targetFilter: HistoryFilter.favorites),
                  // すべてタブ
                  HistoryList(targetFilter: HistoryFilter.all),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Web用カメラダイアログ
class _WebCameraDialog extends StatefulWidget {
  final Function(Uint8List) onImageCaptured;

  const _WebCameraDialog({required this.onImageCaptured});

  @override
  State<_WebCameraDialog> createState() => _WebCameraDialogState();
}

class _WebCameraDialogState extends State<_WebCameraDialog> {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final mediaStream = await html.window.navigator.mediaDevices!
          .getUserMedia({'video': true});

      _videoElement = html.VideoElement()
        ..srcObject = mediaStream
        ..autoplay = true
        ..style.width = '100%'
        ..style.height = '100%';

      _stream = mediaStream;

      // ビデオ要素をDOMに追加
      html.document.body!.append(_videoElement!);

      setState(() {});
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _captureImage() async {
    if (_videoElement == null) return;

    final canvas = html.CanvasElement(
      width: _videoElement!.videoWidth,
      height: _videoElement!.videoHeight,
    );

    final context = canvas.context2D;
    context.drawImageScaled(_videoElement!, 0, 0,
        canvas.width!, canvas.height!);

    final blob = await canvas.toBlob('image/png');
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;

    final bytes = reader.result as Uint8List;
    widget.onImageCaptured(bytes);

    _dispose();
  }

  void _dispose() {
    _stream?.getTracks().forEach((track) => track.stop());
    _videoElement?.remove();
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('カメラ撮影'),
      content: Container(
        width: 400,
        height: 300,
        color: Colors.black,
        child: const Center(
          child: Text(
            'カメラプレビュー',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _dispose();
            Navigator.of(context).pop();
          },
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _captureImage,
          child: const Text('撮影'),
        ),
      ],
    );
  }
}
