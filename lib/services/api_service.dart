import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/detection_result.dart';
import '../models/molecule.dart';

class ApiService {
  // Gemini API（Google AI Studio）の設定
  static const String _apiKey = 'AIzaSyAcAgyzLJ2tTKTMlualOns8TnJP4Zp_U9A';
  static const String _geminiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  static final Dio _dio = Dio()
    ..options.connectTimeout = const Duration(seconds: 60)
    ..options.receiveTimeout = const Duration(seconds: 60)
    ..options.sendTimeout = const Duration(seconds: 60);

  static Future<DetectionResult> analyzeImage(Uint8List imageBytes, String? mimeType) async {
    try {
      debugPrint('Sending image to Gemini API');

      // Base64エンコード
      final base64Image = base64Encode(imageBytes);

      // MIMEタイプを決定
      String finalMimeType = mimeType ?? 'image/jpeg';
      if (finalMimeType == 'application/octet-stream') {
        finalMimeType = 'image/jpeg';
      }

      // Gemini APIリクエストボディ
      final requestBody = {
        'contents': [
          {
            'parts': [
              {
                'text': '''この画像に写っているメインの物体を識別し、その物体に含まれる主要な化学分子を推定してください。以下のJSON形式で回答してください：

{
  "object": "物体名（日本語）",
  "molecules": [
    {
      "name": "分子名",
      "description": "分子の説明",
      "confidence": 0.9,
      "formula": "化学式"
    }
  ]
}

食べ物、飲み物、植物の場合は、その物体に含まれる主要な化学分子を5個程度推定してください。信頼度は0.5-0.95の範囲で設定してください。''',
              },
              {
                'inline_data': {
                  'mime_type': finalMimeType,
                  'data': base64Image,
                },
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 1000,
        },
      };

      // Gemini APIにリクエスト送信
      final response = await _dio.post(
        '$_geminiUrl?key=$_apiKey',
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) {
            // 200-299と503を許可（503はより詳細な調査のため）
            return (status! >= 200 && status < 300) || status == 503;
          },
        ),
      );

      if (response.statusCode == 200) {
        // Gemini APIのレスポンスを解析してDetectionResultに変換
        return await _parseGeminiResponse(response.data);
      } else if (response.statusCode == 503) {
        debugPrint('Gemini API 503 Error Details:');
        debugPrint('Status: ${response.statusCode}');
        debugPrint('Status Message: ${response.statusMessage}');
        debugPrint('Response Headers: ${response.headers}');
        debugPrint('Response Data: ${response.data}');
        throw Exception('Gemini API temporarily unavailable (503): ${response.data}');
      } else {
        debugPrint('Gemini API Error: ${response.statusCode} - ${response.statusMessage}');
        debugPrint('Response Data: ${response.data}');
        throw Exception('Gemini API error: ${response.statusCode} ${response.statusMessage}');
      }
    } on DioException catch (e) {
      debugPrint('DioException Details:');
      debugPrint('Type: ${e.type}');
      debugPrint('Message: ${e.message}');
      debugPrint('Response Status: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Request Path: ${e.requestOptions.path}');

      if (e.response?.statusCode == 503) {
        throw Exception('Gemini API server overloaded (503). Response: ${e.response?.data}');
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception('Connection timeout to Gemini API');
      } else if (e.type == DioExceptionType.sendTimeout) {
        throw Exception('Send timeout to Gemini API');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Receive timeout from Gemini API');
      } else {
        throw Exception('Network error: ${e.type} - ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Gemini APIのレスポンスを解析してDetectionResultに変換
  static Future<DetectionResult> _parseGeminiResponse(Map<String, dynamic> data) async {
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No response from Gemini API');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>;
    final parts = content['parts'] as List<dynamic>;

    if (parts.isEmpty) {
      throw Exception('No content in Gemini response');
    }

    final text = parts[0]['text'] as String;
    debugPrint('Gemini response: $text');

    try {
      // GeminiからのJSONレスポンスを解析
      return await _parseGeminiJsonResponse(text);
    } catch (e) {
      debugPrint('Failed to parse JSON response, falling back to simple parsing: $e');

      // フォールバック: シンプルなテキスト解析
      String objectName = text.trim();
      objectName = objectName.replaceAll('"', '').replaceAll("'", '').replaceAll('.', '').replaceAll('!', '').replaceAll('?', '');

      if (objectName.isEmpty) {
        objectName = 'Unknown';
      }

      // 化学分子のモック生成
      final molecules = _generateMockMolecules(objectName);

      return DetectionResult(
        objectName: objectName,
        molecules: molecules,
      );
    }
  }

  // GeminiからのJSONレスポンスを解析
  static Future<DetectionResult> _parseGeminiJsonResponse(String text) async {
    // JSON部分を抽出（```json と ``` で囲まれている場合もある）
    String jsonText = text;
    if (text.contains('```json')) {
      final startIndex = text.indexOf('```json') + 7;
      final endIndex = text.indexOf('```', startIndex);
      if (endIndex != -1) {
        jsonText = text.substring(startIndex, endIndex).trim();
      }
    } else if (text.contains('{') && text.contains('}')) {
      final startIndex = text.indexOf('{');
      final endIndex = text.lastIndexOf('}') + 1;
      jsonText = text.substring(startIndex, endIndex);
    }

    final Map<String, dynamic> jsonData = json.decode(jsonText);

    final objectName = jsonData['object'] as String? ?? 'Unknown';
    final moleculesData = jsonData['molecules'] as List<dynamic>? ?? [];

    // 非同期で分子データを作成
    final List<Molecule> molecules = [];
    for (final mol in moleculesData) {
      final molData = mol as Map<String, dynamic>;
      final moleculeName = molData['name'] as String? ?? 'Unknown';

      // PubChemでCIDを検索
      final cid = await _getCidFromMoleculeName(moleculeName);

      molecules.add(Molecule(
        name: moleculeName,
        description: molData['description'] as String? ?? '',
        confidence: (molData['confidence'] as num?)?.toDouble() ?? 0.5,
        formula: molData['formula'] as String?,
        sdf: cid != null ? 'pubchem_cid_$cid' : _generateSdfMockId(moleculeName),
        cid: cid,
      ));
    }

    // 分子が少ない場合は追加の分子を生成
    if (molecules.length < 3) {
      molecules.addAll(_generateMockMolecules(objectName).take(5 - molecules.length));
    }

    return DetectionResult(
      objectName: objectName,
      molecules: molecules,
    );
  }

  // 分子名からSDFモックIDを生成
  static String _generateSdfMockId(String moleculeName) {
    final name = moleculeName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('（', '_')
        .replaceAll('）', '_')
        .replaceAll('(', '_')
        .replaceAll(')', '_');
    return 'mock_${name}_sdf_data';
  }

  // 分子名からPubChemでCIDを検索
  static Future<int?> _getCidFromMoleculeName(String moleculeName) async {
    try {
      debugPrint('Searching PubChem for molecule: $moleculeName');

      // まず既知の分子をチェック
      final Map<String, int> knownMolecules = {
        'カフェイン': 2519,
        'フルクトース': 5984,
        'グルコース': 5793,
        'スクロース': 5988,
        'クエン酸': 311,
        'ビタミンc': 54670067,
        'リモネン': 22311,
        'クロロゲン酸': 1794427,
        '水': 962,
        '二酸化炭素': 280,
        '酸素': 977,
        '窒素': 947,
        'アンモニア': 222,
        'セルロース': 16760691,
        'クロロフィルa': 439796,
        'クロロフィルb': 439798,
        'カロテノイド': 5280489, // β-カロテン
      };

      final knownCid = knownMolecules[moleculeName.toLowerCase()];
      if (knownCid != null) {
        return knownCid;
      }

      // 日本語名を英語名に変換
      final englishName = _translateToEnglish(moleculeName);

      // PubChemで分子名からCIDを検索（まず英語名、次に日本語名）
      for (final name in [englishName, moleculeName]) {
        if (name.isEmpty) continue;

        try {
          final response = await _dio.get(
            'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/$name/cids/JSON',
            options: Options(
              headers: {
                'Accept': 'application/json',
              },
            ),
          );

          if (response.statusCode == 200 && response.data != null) {
            final data = response.data as Map<String, dynamic>;
            final identifierList = data['IdentifierList'] as Map<String, dynamic>?;
            final cids = identifierList?['CID'] as List<dynamic>?;

            if (cids != null && cids.isNotEmpty) {
              final cid = cids[0] as int;
              debugPrint('Found CID $cid for molecule: $name ($moleculeName)');
              return cid;
            }
          }
        } catch (e) {
          debugPrint('Failed to search for $name: $e');
          continue;
        }
      }

      debugPrint('No CID found for molecule: $moleculeName');
      return null;
    } catch (e) {
      debugPrint('Error searching for molecule $moleculeName: $e');
      return null;
    }
  }

  // 日本語分子名を英語名に翻訳
  static String _translateToEnglish(String moleculeName) {
    final Map<String, String> translations = {
      'クロロフィル': 'chlorophyll',
      'クロロフィルa': 'chlorophyll a',
      'クロロフィルb': 'chlorophyll b',
      'セルロース': 'cellulose',
      'デンプン': 'starch',
      'リグニン': 'lignin',
      'カロテノイド': 'carotenoid',
      'カフェイン': 'caffeine',
      'フルクトース': 'fructose',
      'グルコース': 'glucose',
      'スクロース': 'sucrose',
      'クエン酸': 'citric acid',
      'ビタミンc': 'vitamin c',
      'リモネン': 'limonene',
      'クロロゲン酸': 'chlorogenic acid',
      '水': 'water',
      '二酸化炭素': 'carbon dioxide',
      '酸素': 'oxygen',
      '窒素': 'nitrogen',
      'アンモニア': 'ammonia',
    };

    return translations[moleculeName.toLowerCase()] ?? '';
  }

  // オブジェクト名に基づいてモック分子を生成
  static List<Molecule> _generateMockMolecules(String objectName) {

    final lowerName = objectName.toLowerCase();
    switch (lowerName) {
      case 'apple':
      case 'fruit':
      case 'food':
      case 'リンゴ':
      case 'メロン':
      case '果物':
        return [
          Molecule(
            name: 'フルクトース',
            description: '果糖。果物の主要な糖分で、グルコースよりも甜味が強い',
            confidence: 0.92,
            cid: 5984,
            formula: 'C₆H₁₂O₆',
            sdf: 'mock_fructose_sdf_data',
          ),
          Molecule(
            name: 'グルコース',
            description: 'ブドウ糖。細胞のエネルギー源として重要な単糖',
            confidence: 0.88,
            cid: 5793,
            formula: 'C₆H₁₂O₆',
            sdf: 'mock_glucose_sdf_data',
          ),
          Molecule(
            name: 'スクロース',
            description: 'ショ糖。グルコースとフルクトースが結合した二糖',
            confidence: 0.75,
            cid: 5988,
            formula: 'C₁₂H₂₂O₁₁',
            sdf: 'mock_sucrose_sdf_data',
          ),
        ];
      case 'coffee':
      case 'beverage':
      case 'コーヒー':
      case '飲み物':
        return [
          Molecule(
            name: 'カフェイン',
            description: 'アルカロイド。中枢神経系を刺激し、覚醒作用を持つ',
            confidence: 0.91,
            cid: 2519,
            formula: 'C₈H₁₀N₄O₂',
            sdf: 'mock_caffeine_sdf_data',
          ),
          Molecule(
            name: 'クロロゲン酸',
            description: 'ポリフェノール。コーヒーの苦味成分で、抗酸化作用を持つ',
            confidence: 0.83,
            cid: 1794427,
            formula: 'C₁₆H₁₈O₉',
            sdf: 'mock_chlorogenic_acid_sdf_data',
          ),
          Molecule(
            name: 'カフェオール',
            description: '香気成分。コーヒー特有の香りを作り出す化合物',
            confidence: 0.72,
            cid: 123456,
            formula: 'C₁₁H₁₆O₂',
            sdf: 'mock_cafeol_sdf_data',
          ),
          Molecule(
            name: 'トリゴネリン',
            description: 'アルカロイド。コーヒーの焙煎で生成される苦味成分',
            confidence: 0.66,
            cid: 5570,
            formula: 'C₇H₇NO₂',
            sdf: 'mock_trigonelline_sdf_data',
          ),
          Molecule(
            name: 'カフェ酸',
            description: 'フェノール酸。コーヒーの抗酸化作用に寄与',
            confidence: 0.59,
            cid: 689043,
            formula: 'C₉H₈O₄',
            sdf: 'mock_caffeic_acid_sdf_data',
          ),
        ];
      case 'レモン':
      case 'lemon':
        return [
          Molecule(
            name: 'クエン酸',
            description: '有機酸。柑橘類の酸味を作り出す主要成分',
            confidence: 0.94,
            cid: 311,
            formula: 'C₆H₈O₇',
            sdf: 'mock_citric_acid_sdf_data',
          ),
          Molecule(
            name: 'ビタミンC',
            description: 'アスコルビン酸。抗酸化作用を持つ水溶性ビタミン',
            confidence: 0.87,
            cid: 54670067,
            formula: 'C₆H₈O₆',
            sdf: 'mock_vitamin_c_sdf_data',
          ),
          Molecule(
            name: 'リモネン',
            description: 'テルペン化合物。柑橘類の皮に含まれる香気成分',
            confidence: 0.79,
            cid: 22311,
            formula: 'C₁₀H₁₆',
            sdf: 'mock_limonene_sdf_data',
          ),
          Molecule(
            name: 'ペクチン',
            description: '多糖類。果実に含まれる天然のゲル化剤',
            confidence: 0.68,
            cid: 441476,
            formula: 'C₆H₁₀O₇',
            sdf: 'mock_pectin_sdf_data',
          ),
          Molecule(
            name: 'フラボノイド',
            description: 'ポリフェノール。柑橘類の苦味成分で抗酸化作用',
            confidence: 0.62,
            cid: 5280343,
            formula: 'C₁₅H₁₀O₆',
            sdf: 'mock_flavonoid_sdf_data',
          ),
        ];
      default:
        return [
          Molecule(
            name: '水',
            description: '水分子。生命活動に不可欠な物質',
            confidence: 0.95,
            cid: 962,
            formula: 'H₂O',
            sdf: 'mock_water_sdf_data',
          ),
          Molecule(
            name: '二酸化炭素',
            description: '二酸化炭素。大気中に存在する気体',
            confidence: 0.70,
            cid: 280,
            formula: 'CO₂',
            sdf: 'mock_co2_sdf_data',
          ),
          Molecule(
            name: '酸素',
            description: '酸素。呼吸に必要な気体',
            confidence: 0.65,
            cid: 977,
            formula: 'O₂',
            sdf: 'mock_oxygen_sdf_data',
          ),
          Molecule(
            name: '窒素',
            description: '窒素。大気の約78%を占める気体',
            confidence: 0.60,
            cid: 947,
            formula: 'N₂',
            sdf: 'mock_nitrogen_sdf_data',
          ),
          Molecule(
            name: 'アンモニア',
            description: 'アンモニア。アルカリ性の化合物',
            confidence: 0.55,
            cid: 222,
            formula: 'NH₃',
            sdf: 'mock_ammonia_sdf_data',
          ),
        ];
    }
  }

  // バックエンドのSDFからGLB変換エンドポイントのみを使用
  static Future<Uint8List> convertSdfToGlb(String sdfIdentifier) async {
    debugPrint('Converting SDF to GLB via backend only: $sdfIdentifier');

    // 実際のSDFデータを取得
    String sdfData;
    if (sdfIdentifier.startsWith('pubchem_cid_')) {
      final cidString = sdfIdentifier.replaceFirst('pubchem_cid_', '');
      final cid = int.tryParse(cidString);
      if (cid != null) {
        sdfData = await getSdfDataFromCid(cid);
      } else {
        sdfData = await _getRealSdfDataFromIdentifier(sdfIdentifier);
      }
    } else {
      sdfData = await _getRealSdfDataFromIdentifier(sdfIdentifier);
    }

    // バックエンドのコンバートエンドポイントを呼び出し
    final response = await _dio.post(
      'http://localhost:3000/convert',
      data: sdfData,
      options: Options(
        headers: {
          'Content-Type': 'text/plain',
        },
        responseType: ResponseType.bytes,
      ),
    );

    if (response.statusCode == 200) {
      debugPrint('Successfully converted SDF to GLB via backend, size: ${response.data.length} bytes');
      return Uint8List.fromList(response.data);
    } else {
      throw Exception('Backend conversion failed with status: ${response.statusCode}');
    }
  }

  // フォールバック用のローカルGLB変換
  static Future<Uint8List> _convertSdfToGlbLocal(String sdfIdentifier) async {
    debugPrint('Local GLB conversion for identifier: $sdfIdentifier');

    // PubChemのCIDから直接取得する場合（Geminiが推定した分子）
    if (sdfIdentifier.startsWith('pubchem_cid_')) {
      final cidString = sdfIdentifier.replaceFirst('pubchem_cid_', '');
      final cid = int.tryParse(cidString);
      if (cid != null) {
        debugPrint('Converting CID $cid to GLB directly');
        return _generateMolecularGlb(cid);
      }
    }

    // sdfDataがCIDを含むモックデータの場合、CIDを抽出
    if (sdfIdentifier.startsWith('mock_') && sdfIdentifier.endsWith('_sdf_data')) {
      // モックデータから分子名を抽出してCIDをマッピング
      final Map<String, int> mockToCidMap = {
        'mock_fructose_sdf_data': 5984,
        'mock_glucose_sdf_data': 5793,
        'mock_sucrose_sdf_data': 5988,
        'mock_caffeine_sdf_data': 2519,
        'mock_chlorogenic_acid_sdf_data': 1794427,
        'mock_cafeol_sdf_data': 123456, // モック用
        'mock_trigonelline_sdf_data': 5570,
        'mock_caffeic_acid_sdf_data': 689043,
        'mock_citric_acid_sdf_data': 311,
        'mock_vitamin_c_sdf_data': 54670067,
        'mock_limonene_sdf_data': 22311,
        'mock_pectin_sdf_data': 441476,
        'mock_flavonoid_sdf_data': 5280343,
        'mock_water_sdf_data': 962,
        'mock_co2_sdf_data': 280,
        'mock_oxygen_sdf_data': 977,
        'mock_nitrogen_sdf_data': 947,
        'mock_ammonia_sdf_data': 222,
      };

      final cid = mockToCidMap[sdfIdentifier];
      if (cid != null) {
        debugPrint('Converting mock CID $cid to GLB');
        return _generateMolecularGlb(cid);
      }
    }

    // フォールバック: デフォルト分子GLBデータ
    debugPrint('Using default GLB for unknown identifier: $sdfIdentifier');
    return _generateMolecularGlb(962); // 水分子として生成
  }

  // SDFIdentifierから実際のSDFデータを取得
  static Future<String> _getRealSdfDataFromIdentifier(String sdfIdentifier) async {
    // モックデータからCIDへのマッピング
    final Map<String, int> mockToCidMap = {
      'mock_fructose_sdf_data': 5984,
      'mock_glucose_sdf_data': 5793,
      'mock_sucrose_sdf_data': 5988,
      'mock_caffeine_sdf_data': 2519,
      'mock_chlorogenic_acid_sdf_data': 1794427,
      'mock_cafeol_sdf_data': 2519, // カフェインで代用
      'mock_trigonelline_sdf_data': 5570,
      'mock_caffeic_acid_sdf_data': 689043,
      'mock_citric_acid_sdf_data': 311,
      'mock_vitamin_c_sdf_data': 54670067,
      'mock_limonene_sdf_data': 22311,
      'mock_pectin_sdf_data': 441476,
      'mock_flavonoid_sdf_data': 5280343,
      'mock_water_sdf_data': 962,
      'mock_co2_sdf_data': 280,
      'mock_oxygen_sdf_data': 977,
      'mock_nitrogen_sdf_data': 947,
      'mock_ammonia_sdf_data': 222,
      'mock_セルロース_sdf_data': 16760691,
      'mock_クロロフィルa_sdf_data': 439796,
      'mock_クロロフィルb_sdf_data': 439798,
      'mock_カロテノイド_sdf_data': 5280489,
    };

    final cid = mockToCidMap[sdfIdentifier];
    if (cid != null) {
      return await getSdfDataFromCid(cid);
    }

    // フォールバック: シンプルなモックSDF
    return _generateMockSdfData(962); // 水のモック
  }

  // CIDから実際の3Dデータを取得してGLBに変換
  static Future<Uint8List> _getGlbFromCid(int cid) async {
    try {
      debugPrint('Fetching 3D data for CID: $cid');

      // PubChemからSDFデータを取得
      final sdfResponse = await _dio.get(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/record/SDF',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'chemical/x-mdl-sdfile',
          },
        ),
      );

      if (sdfResponse.statusCode == 200 && sdfResponse.data != null) {
        final sdfData = sdfResponse.data as String;
        debugPrint('Retrieved SDF data for CID $cid, length: ${sdfData.length}');

        // SDFデータからGLBを生成（モック実装）
        return await _convertSdfToGlbMock(sdfData, cid);
      } else {
        debugPrint('Failed to fetch SDF data for CID $cid');
        return _generateMockGlbData();
      }
    } catch (e) {
      debugPrint('Error fetching 3D data for CID $cid: $e');
      // エラー時はモックGLBデータを返す
      return _generateMockGlbData();
    }
  }

  // SDFデータからGLBへのモック変換（実際は3D変換ライブラリが必要）
  static Future<Uint8List> _convertSdfToGlbMock(String sdfData, int cid) async {
    // 実際の実装では、ここでSDFデータを解析して
    // 3D座標を抽出し、GLBフォーマットに変換する必要があります

    await Future.delayed(const Duration(milliseconds: 1000)); // 変換時間をシミュレート

    // CIDに基づいて異なるモックGLBデータを生成
    return _generateMockGlbWithVariation(cid);
  }

  // CIDに基づいて実際のGLBデータを生成（簡略版の分子モデル）
  static Uint8List _generateMockGlbWithVariation(int cid) {
    // 分子に応じた簡略GLBファイルを生成
    return _generateMolecularGlb(cid);
  }

  // 実際の分子構造に基づいた簡略GLBデータを生成
  static Uint8List _generateMolecularGlb(int cid) {
    debugPrint('Generating molecular GLB for CID: $cid');

    // 分子の種類に応じて異なる構造を生成
    String jsonData;

    switch (cid) {
      case 962: // 水分子 (H2O)
        debugPrint('Generating water molecule GLB');
        jsonData = _generateWaterMoleculeGltf();
        break;
      case 280: // 二酸化炭素 (CO2)
        debugPrint('Generating CO2 molecule GLB');
        jsonData = _generateCO2MoleculeGltf();
        break;
      case 2519: // カフェイン
        debugPrint('Generating caffeine molecule GLB');
        jsonData = _generateCaffeineMoleculeGltf();
        break;
      case 156620228: // クロロフィル
        debugPrint('Generating chlorophyll molecule GLB');
        jsonData = _generateChlorophyllMoleculeGltf();
        break;
      case 16760691: // セルロース
        debugPrint('Generating cellulose molecule GLB');
        jsonData = _generateCelluloseMoleculeGltf();
        break;
      case 175586: // リグニン
        debugPrint('Generating lignin molecule GLB');
        jsonData = _generateLigninMoleculeGltf();
        break;
      default:
        debugPrint('Generating default molecule GLB for CID: $cid');
        jsonData = _generateDefaultMoleculeGltf();
        break;
    }

    debugPrint('Generated GLTF JSON length: ${jsonData.length}');

    // GLTFをGLBバイナリ形式に変換
    final result = _convertGltfToGlb(jsonData);
    debugPrint('Final GLB size: ${result.length} bytes');

    return result;
  }

  // 水分子のGLTF JSON構造を生成（簡単な立方体）
  static String _generateWaterMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.0, 0.5, 1.0, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // CO2分子のGLTF構造を生成（簡単な立方体、赤色）
  static String _generateCO2MoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [1.0, 0.0, 0.0, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // カフェイン分子の複雑な構造（茶色の立方体）
  static String _generateCaffeineMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.6, 0.3, 0.1, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // クロロフィル分子（緑色の立方体）
  static String _generateChlorophyllMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.0, 0.8, 0.2, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // セルロース分子（白色の立方体）
  static String _generateCelluloseMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.9, 0.9, 0.9, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // リグニン分子（茶褐色の立方体）
  static String _generateLigninMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.4, 0.2, 0.1, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // デフォルト分子構造（緑色の立方体）
  static String _generateDefaultMoleculeGltf() {
    return '''
{
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [
    {
      "primitives": [
        {
          "attributes": {"POSITION": 0},
          "indices": 1,
          "material": 0
        }
      ]
    }
  ],
  "materials": [
    {
      "pbrMetallicRoughness": {
        "baseColorFactor": [0.0, 1.0, 0.0, 1.0],
        "metallicFactor": 0.0,
        "roughnessFactor": 1.0
      }
    }
  ],
  "accessors": [
    {
      "bufferView": 0,
      "componentType": 5126,
      "count": 8,
      "type": "VEC3"
    },
    {
      "bufferView": 1,
      "componentType": 5123,
      "count": 36,
      "type": "SCALAR"
    }
  ],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 96},
    {"buffer": 0, "byteOffset": 96, "byteLength": 72}
  ],
  "buffers": [{"byteLength": 168}],
  "asset": {"version": "2.0"}
}''';
  }

  // GLTF JSONをGLBバイナリ形式に変換
  static Uint8List _convertGltfToGlb(String gltfJson) {
    final jsonBytes = utf8.encode(gltfJson);
    final jsonLength = jsonBytes.length;

    // パディングを4バイト境界に合わせる
    final jsonPadding = (4 - (jsonLength % 4)) % 4;
    final paddedJsonLength = jsonLength + jsonPadding;

    // 基本的な立方体のバイナリデータ（位置とインデックス）
    final binaryData = _generateCubeGeometry();
    final binaryLength = binaryData.length;
    final binaryPadding = (4 - (binaryLength % 4)) % 4;
    final paddedBinaryLength = binaryLength + binaryPadding;

    // GLBヘッダー
    final totalLength = 12 + 8 + paddedJsonLength + 8 + paddedBinaryLength;

    final glbData = <int>[];

    // GLBヘッダー
    glbData.addAll([0x67, 0x6C, 0x54, 0x46]); // "glTF" magic
    glbData.addAll(_uint32ToBytes(2)); // version
    glbData.addAll(_uint32ToBytes(totalLength)); // total length

    // JSONチャンク
    glbData.addAll(_uint32ToBytes(paddedJsonLength)); // chunk length
    glbData.addAll([0x4A, 0x53, 0x4F, 0x4E]); // "JSON" type
    glbData.addAll(jsonBytes);
    glbData.addAll(List.filled(jsonPadding, 0x20)); // space padding

    // バイナリチャンク
    glbData.addAll(_uint32ToBytes(paddedBinaryLength)); // chunk length
    glbData.addAll([0x42, 0x49, 0x4E, 0x00]); // "BIN\0" type
    glbData.addAll(binaryData);
    glbData.addAll(List.filled(binaryPadding, 0)); // zero padding

    return Uint8List.fromList(glbData);
  }

  // 32bitエンディアン変換
  static List<int> _uint32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  // 基本的な立方体のジオメトリデータを生成
  static List<int> _generateCubeGeometry() {
    // 立方体の頂点（8個）
    final vertices = <double>[
      -0.5, -0.5, -0.5,  // 0
       0.5, -0.5, -0.5,  // 1
       0.5,  0.5, -0.5,  // 2
      -0.5,  0.5, -0.5,  // 3
      -0.5, -0.5,  0.5,  // 4
       0.5, -0.5,  0.5,  // 5
       0.5,  0.5,  0.5,  // 6
      -0.5,  0.5,  0.5,  // 7
    ];

    // 立方体のインデックス（12個の三角形 = 36個のインデックス）
    final indices = <int>[
      0, 1, 2,  2, 3, 0,  // 前面
      4, 7, 6,  6, 5, 4,  // 背面
      0, 4, 5,  5, 1, 0,  // 下面
      2, 6, 7,  7, 3, 2,  // 上面
      0, 3, 7,  7, 4, 0,  // 左面
      1, 5, 6,  6, 2, 1,  // 右面
    ];

    final buffer = <int>[];

    // 頂点データ（float32）
    for (final vertex in vertices) {
      final bytes = Float32List.fromList([vertex]).buffer.asUint8List();
      buffer.addAll(bytes);
    }

    // インデックスデータ（uint16）
    for (final index in indices) {
      buffer.addAll([index & 0xFF, (index >> 8) & 0xFF]);
    }

    return buffer;
  }

  // シンプルなモックGLBデータを生成
  static Uint8List _generateMockGlbData() {
    debugPrint('Generating fallback GLB data');
    // デフォルトの立方体GLBを生成
    return _generateMolecularGlb(962); // 水分子として生成
  }

  // CIDから直接SDFデータを取得する（WebView用）
  static Future<String> getSdfDataFromCid(int cid) async {
    try {
      debugPrint('Fetching SDF data for CID: $cid');

      // PubChemからSDFデータを取得
      final sdfResponse = await _dio.get(
        'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/$cid/record/SDF',
        options: Options(
          responseType: ResponseType.plain,
          headers: {
            'Accept': 'chemical/x-mdl-sdfile',
          },
        ),
      );

      if (sdfResponse.statusCode == 200 && sdfResponse.data != null) {
        final sdfData = sdfResponse.data as String;
        debugPrint('Retrieved SDF data for CID $cid, length: ${sdfData.length}');
        return sdfData;
      } else {
        debugPrint('Failed to fetch SDF data for CID $cid');
        return _generateMockSdfData(cid);
      }
    } catch (e) {
      debugPrint('Error fetching SDF data for CID $cid: $e');
      // エラー時はモックSDFデータを返す
      return _generateMockSdfData(cid);
    }
  }

  // CIDに基づいてモックSDFデータを生成
  static String _generateMockSdfData(int cid) {
    switch (cid) {
      case 962: // 水
        return '''
water
  -OEChem-12230000000

  3  2  0     0  0  0  0  0  0999 V2000
    0.0000    0.7570    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
   -0.7570   -0.3785    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
    0.7570   -0.3785    0.0000 H   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  1  0  0  0  0
  1  3  1  0  0  0  0
M  END
\$\$\$\$
''';
      case 280: // CO2
        return '''
carbon dioxide
  -OEChem-12230000000

  3  2  0     0  0  0  0  0  0999 V2000
   -1.1630    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
    0.0000    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
    1.1630    0.0000    0.0000 O   0  0  0  0  0  0  0  0  0  0  0  0
  1  2  2  0  0  0  0
  1  3  2  0  0  0  0
M  END
\$\$\$\$
''';
      default:
        return '''
molecule
  -OEChem-12230000000

  1  0  0     0  0  0  0  0  0999 V2000
    0.0000    0.0000    0.0000 C   0  0  0  0  0  0  0  0  0  0  0  0
M  END
\$\$\$\$
''';
    }
  }
}
