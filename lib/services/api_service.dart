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

  static final Dio _dio = Dio();

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
                'text': 'この画像に写っているメインの物体を識別してください。物体名だけを日本語で簡潔に答えてください。',
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
          'temperature': 0.1,
          'maxOutputTokens': 50,
        },
      };

      // Gemini APIにリクエスト送信
      final response = await _dio.post(
        '$_geminiUrl?key=$_apiKey',
        data: requestBody,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        // Gemini APIのレスポンスを解析してDetectionResultに変換
        return _parseGeminiResponse(response.data);
      } else {
        throw Exception('Gemini API error: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      // Dioのエラー（ネットワークエラーなど）
      throw Exception('Failed to connect to the server: $e');
    } catch (e) {
      // その他のエラー
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Gemini APIのレスポンスを解析してDetectionResultに変換
  static DetectionResult _parseGeminiResponse(Map<String, dynamic> data) {
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

    // テキストを整理してオブジェクト名を抽出
    String objectName = text.trim();
    // 不要な文字を削除
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
        ];
    }
  }

  // SDFデータをGLBに変換するメソッド
  static Future<Uint8List> convertSdfToGlb(String sdfData) async {
    try {
      // モックのGLBデータを返す（実際の変換は別サービスが必要）
      // シンプルなGLBファイルのモックデータ
      final mockGlbData = Uint8List.fromList([
        // GLBヘッダーのモックデータ
        0x67, 0x6C, 0x54, 0x46, // "glTF"
        0x02, 0x00, 0x00, 0x00, // version 2
        0x00, 0x01, 0x00, 0x00, // length
      ]);

      await Future.delayed(const Duration(milliseconds: 500)); // シミュレート用遅延
      return mockGlbData;

      /*
      final response = await _dio.post<List<int>>(
        'https://your-3d-conversion-service.com/convert',
        data: sdfData,
        options: Options(
          headers: {
            'Content-Type': 'text/plain',
          },
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      } else {
        throw Exception('Failed to convert SDF to GLB: ${response.statusMessage}');
      }
      */
    } on DioException catch (e) {
      throw Exception('Failed to connect to 3D conversion service: $e');
    } catch (e) {
      throw Exception('An unexpected error occurred during conversion: $e');
    }
  }
}
