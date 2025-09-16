import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:team_25_app/models/molecule.dart';
import 'package:team_25_app/screens/services/history_store.dart';
import 'package:team_25_app/theme/app_colors.dart';

class HistoryItemWidget extends StatelessWidget {
  final HistoryItem item;
  final int originalIndex;

  const HistoryItemWidget({
    super.key,
    required this.item,
    required this.originalIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topThreeMolecules = item.molecules.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // タップ可能なメインエリア（画像とコンテンツ）
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // 詳細画面へ遷移
                      context.push('/detail/$originalIndex');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 撮影画像
                          _buildImage(),
                          const SizedBox(width: 12),
                          // コンテンツ部分
                          Expanded(child: _buildContent(theme, topThreeMolecules)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // お気に入りアイコン（独立してタップ可能）
              _buildFavoriteIcon(),
            ],
          ),

          // 境界線
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Divider(height: 1, color: Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return SizedBox(
      width: 80,
      height: 80,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: item.imageBytes != null
            ? Image.memory(item.imageBytes!, fit: BoxFit.cover)
            : Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image, size: 40, color: Colors.grey),
              ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, List<Molecule> topThreeMolecules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 物体名（太字タイトル）
        Text(
          item.objectName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),

        // カテゴリ
        if (item.category.isNotEmpty) ...[
          Text(
            item.category,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // 成分3つ
        if (topThreeMolecules.isNotEmpty) ...[
          ...topThreeMolecules.map(
            (molecule) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                molecule.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFavoriteIcon() {
    return GestureDetector(
      onTap: () => HistoryStore.toggleFavorite(originalIndex),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          item.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: item.isFavorite ? AppColors.textSecondary : Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
