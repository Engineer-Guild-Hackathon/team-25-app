import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/detection_result.dart';
import '../../models/molecule.dart';
import '../model_viewer/model_viewer_screen.dart';

class ResultScreen extends StatelessWidget {
  final Uint8List? imageBytes;
  final DetectionResult detection;

  const ResultScreen({
    super.key,
    this.imageBytes,
    required this.detection,
  });

  @override
  Widget build(BuildContext context) {
    final List<Molecule> mols = detection.molecules;

    return Scaffold(
      appBar: AppBar(title: const Text("認識結果")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageBytes != null)
            Image.memory(imageBytes!, height: 200, fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              "物体: ${detection.objectName}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: mols.length,
              itemBuilder: (context, i) {
                final m = mols[i];
                final hasSdf = m.sdf != null && m.sdf!.isNotEmpty;

                return ListTile(
                  title: Text(m.name),
                  subtitle: Text(m.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("${(m.confidence * 100).toStringAsFixed(0)}%"),
                      const SizedBox(width: 8),
                      // AR Viewer Button
                      ElevatedButton(
                        onPressed: !hasSdf
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModelViewerScreen(
                                      sdfData: m.sdf!,
                                      moleculeName: m.name,
                                      formula: m.formula,
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text('ARで見る'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
