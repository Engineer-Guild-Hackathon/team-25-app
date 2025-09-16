import type { Result } from "../types/types.js";
/**
 * 画像を分析し、写っている物体とそれに含まれる分子を特定する
 * @param imageBuffer 画像のバッファデータ
 * @param mimeType 画像のMIMEタイプ (e.g., "image/jpeg")
 * @returns 分析結果のオブジェクト、またはnull
 */
export declare function analyzeImage(imageBuffer: Buffer, mimeType: string): Promise<Result | null>;
//# sourceMappingURL=gemini.d.ts.map