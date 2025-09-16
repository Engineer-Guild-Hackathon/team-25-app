import 'package:flutter/material.dart';

import '../../models/molecule.dart';
import '../../theme/app_colors.dart';
import '../services/history_store.dart';

class DetailScreen extends StatelessWidget {
  final int historyIndex;

  const DetailScreen({super.key, required this.historyIndex});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<HistoryItem>>(
      valueListenable: HistoryStore.items,
      builder: (context, items, _) {
        if (historyIndex >= items.length) {
          return Scaffold(
            appBar: AppBar(title: const Text('エラー')),
            body: const Center(child: Text('指定された履歴アイテムが見つかりません')),
          );
        }

        final item = items[historyIndex];
        return _buildDetailContent(context, item);
      },
    );
  }

  Widget _buildDetailContent(BuildContext context, HistoryItem item) {
    return Scaffold(
      appBar: AppBar(title: Text(item.objectName)),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 撮影画像表示部分
            _buildImageSection(item),

            // オブジェクト情報セクション
            _buildObjectInfoSection(context, item),

            // 分子リストセクション
            _buildMoleculeListSection(context, item.molecules),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(HistoryItem item) {
    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: item.imageBytes != null
            ? Image.memory(
                item.imageBytes!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.background,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 64,
                        color: AppColors.primaryDark.withValues(alpha: 0.5),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: AppColors.background,
                child: Center(
                  child: Icon(
                    Icons.image,
                    size: 64,
                    color: AppColors.primaryDark.withValues(alpha: 0.5),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildObjectInfoSection(BuildContext context, HistoryItem item) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'オブジェクト情報',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('物体名', item.objectName),
          if (item.category.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('カテゴリ', item.category),
          ],
          const SizedBox(height: 8),
          _buildInfoRow('撮影日時', _formatDateTime(item.viewedAt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoleculeListSection(
    BuildContext context,
    List<Molecule> molecules,
  ) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '検出された化合物',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          ...molecules.map((molecule) => _buildMoleculeCard(context, molecule)),
        ],
      ),
    );
  }

  Widget _buildMoleculeCard(BuildContext context, Molecule molecule) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左側：分子情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    molecule.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    molecule.description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // 右側：ARボタン
            SizedBox(width: 80, child: _buildARButton(context, molecule)),
          ],
        ),
      ),
    );
  }

  Widget _buildARButton(BuildContext context, Molecule molecule) {
    return OutlinedButton(
      onPressed: () {
        // TODO: AR画面への遷移実装
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${molecule.name}のAR表示機能は準備中です'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      style: FilledButton.styleFrom(
        foregroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.primary),
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Text('ARで見る', style: TextStyle(fontSize: 10))],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
