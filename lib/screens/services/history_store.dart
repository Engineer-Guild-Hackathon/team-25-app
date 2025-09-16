import 'package:flutter/foundation.dart';
import 'package:team_25_app/models/molecule.dart';

class HistoryItem {
  final String objectName; // 物体名
  final DateTime viewedAt;
  final List<Molecule> molecules; // 推定分子一覧（3〜5）
  final Molecule? topMolecule; // ★ 最も信頼度の高い分子
  final Uint8List? imageBytes; // Web用画像データ
  final String? fileName; // Web用ファイル名
  final bool isFavorite; // ★ お気に入り状態
  final String category; // ★ 物体のカテゴリ

  HistoryItem({
    required this.objectName,
    required this.viewedAt,
    required this.molecules,
    this.imageBytes,
    this.fileName,
    required this.topMolecule, // ★ 追加
    this.isFavorite = false, // ★ デフォルトはfalse
    this.category = '', // ★ デフォルトは空文字
  });

  // ★ お気に入り状態を変更したコピーを作成
  HistoryItem copyWith({
    String? objectName,
    DateTime? viewedAt,
    List<Molecule>? molecules,
    Uint8List? imageBytes,
    String? fileName,
    Molecule? topMolecule,
    bool? isFavorite,
    String? category,
  }) {
    return HistoryItem(
      objectName: objectName ?? this.objectName,
      viewedAt: viewedAt ?? this.viewedAt,
      molecules: molecules ?? this.molecules,
      imageBytes: imageBytes ?? this.imageBytes,
      fileName: fileName ?? this.fileName,
      topMolecule: topMolecule ?? this.topMolecule,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
    );
  }
}

enum HistoryFilter { all, favorites }

class HistoryStore {
  static final ValueNotifier<List<HistoryItem>> items =
      ValueNotifier<List<HistoryItem>>([]);

  static final ValueNotifier<HistoryFilter> currentFilter =
      ValueNotifier<HistoryFilter>(HistoryFilter.all);

  // モックデータを初期化
  static void initMockData() {
    if (items.value.isNotEmpty) return; // 既にデータがある場合はスキップ

    final now = DateTime.now();
    final mockItems = [
      // 今日のデータ
      HistoryItem(
        objectName: 'りんご',
        viewedAt: now.subtract(const Duration(hours: 2)),
        molecules: [
          Molecule(
            name: 'フルクトース',
            description: '果糖',
            confidence: 0.92,
          ),
          Molecule(
            name: 'グルコース',
            description: 'ブドウ糖',
            confidence: 0.88,
          ),
          Molecule(
            name: 'スクロース',
            description: 'ショ糖',
            confidence: 0.75,
          ),
        ],
        topMolecule: Molecule(
          name: 'フルクトース',
          description: '果糖',
          confidence: 0.92,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: true,
        category: '食品・果物',
      ),

      HistoryItem(
        objectName: '水',
        viewedAt: now.subtract(const Duration(hours: 4)),
        molecules: [
          Molecule(
            name: '水',
            description: '水分子',
            confidence: 0.99,
          ),
          Molecule(
            name: '過酸化水素',
            description: 'オキシドール',
            confidence: 0.15,
          ),
          Molecule(
            name: '重水',
            description: '重水素水',
            confidence: 0.08,
          ),
        ],
        topMolecule: Molecule(
          name: '水',
          description: '水分子',
          confidence: 0.99,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: false,
        category: '飲料・液体',
      ),

      // 昨日のデータ
      HistoryItem(
        objectName: '塩',
        viewedAt: now.subtract(const Duration(days: 1, hours: 8)),
        molecules: [
          Molecule(
            name: '塩化ナトリウム',
            description: '食塩',
            confidence: 0.96,
          ),
          Molecule(
            name: '塩化カリウム',
            description: '塩化カリ',
            confidence: 0.12,
          ),
          Molecule(
            name: '塩化マグネシウム',
            description: '苦汁の成分',
            confidence: 0.08,
          ),
        ],
        topMolecule: Molecule(
          name: '塩化ナトリウム',
          description: '食塩',
          confidence: 0.96,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: true,
        category: '調味料・食品添加物',
      ),

      HistoryItem(
        objectName: 'レモン',
        viewedAt: now.subtract(const Duration(days: 1, hours: 12)),
        molecules: [
          Molecule(
            name: 'クエン酸',
            description: '有機酸',
            confidence: 0.94,
          ),
          Molecule(
            name: 'ビタミンC',
            description: 'アスコルビン酸',
            confidence: 0.87,
          ),
          Molecule(
            name: 'リモネン',
            description: 'テルペン化合物',
            confidence: 0.79,
          ),
        ],
        topMolecule: Molecule(
          name: 'クエン酸',
          description: '有機酸',
          confidence: 0.94,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: false,
        category: '食品・果物',
      ),

      // 2日前のデータ
      HistoryItem(
        objectName: 'コーヒー',
        viewedAt: now.subtract(const Duration(days: 2, hours: 6)),
        molecules: [
          Molecule(
            name: 'カフェイン',
            description: 'アルカロイド',
            confidence: 0.91,
          ),
          Molecule(
            name: 'クロロゲン酸',
            description: 'ポリフェノール',
            confidence: 0.83,
          ),
          Molecule(
            name: 'カフェオール',
            description: '香気成分',
            confidence: 0.72,
          ),
        ],
        topMolecule: Molecule(
          name: 'カフェイン',
          description: 'アルカロイド',
          confidence: 0.91,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: true,
        category: '飲料・嗜好品',
      ),

      HistoryItem(
        objectName: 'アスピリン',
        viewedAt: now.subtract(const Duration(days: 2, hours: 14)),
        molecules: [
          Molecule(
            name: 'アセチルサリチル酸',
            description: '解熱鎮痛剤',
            confidence: 0.98,
          ),
          Molecule(
            name: 'サリチル酸',
            description: '代謝産物',
            confidence: 0.76,
          ),
          Molecule(
            name: '酢酸',
            description: '加水分解産物',
            confidence: 0.45,
          ),
        ],
        topMolecule: Molecule(
          name: 'アセチルサリチル酸',
          description: '解熱鎮痛剤',
          confidence: 0.98,
        ),
        imageBytes: null,
        fileName: null,
        isFavorite: false,
        category: '医薬品・薬品',
      ),
    ];

    items.value = mockItems;
  }

  static void add(HistoryItem item) {
    final list = List<HistoryItem>.from(items.value);
    list.insert(0, item); // 新しいほど上に
    items.value = list;
  }

  // お気に入り状態を切り替える
  static void toggleFavorite(int index) {
    final list = List<HistoryItem>.from(items.value);
    if (index >= 0 && index < list.length) {
      list[index] = list[index].copyWith(isFavorite: !list[index].isFavorite);
      items.value = list;
    }
  }

  // フィルターを設定する
  static void setFilter(HistoryFilter filter) {
    currentFilter.value = filter;
  }

  // フィルターされたアイテムリストを取得する
  static List<HistoryItem> getFilteredItems() {
    switch (currentFilter.value) {
      case HistoryFilter.favorites:
        return items.value.where((item) => item.isFavorite).toList();
      case HistoryFilter.all:
        return items.value;
    }
  }

  // 日時でグループ化されたアイテムを取得する
  static Map<String, List<HistoryItem>> getGroupedItems() {
    final filtered = getFilteredItems();
    final grouped = <String, List<HistoryItem>>{};

    for (final item in filtered) {
      final dateKey = _formatDateKey(item.viewedAt);
      grouped.putIfAbsent(dateKey, () => []).add(item);
    }

    return grouped;
  }

  // 日付キーをフォーマット
  static String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return '今日';
    } else if (itemDate == today.subtract(const Duration(days: 1))) {
      return '昨日';
    } else {
      return '${date.year}.${date.month}.${date.day}';
    }
  }
}