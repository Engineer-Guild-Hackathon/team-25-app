// エントリーポイント
import express from "express";
import { cleanupTempFiles, convertSdfToGlb } from "./converter/converter.js";
const app = express();
// CORS middleware
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    if (req.method === 'OPTIONS') {
        res.sendStatus(200);
    }
    else {
        next();
    }
});
// SDFデータ(text/plain)を受け取り、GLBファイルを返すエンドポイント
app.post("/convert", express.text({ type: 'text/plain', limit: '1mb' }), async (req, res) => {
    const sdfData = req.body;
    if (typeof sdfData !== 'string' || !sdfData) {
        return res.status(400).json({ error: "SDF data (string) is required" });
    }
    let glbPath;
    try {
        glbPath = await convertSdfToGlb(sdfData);
        res.download(glbPath, 'molecule.glb', async (err) => {
            // 送信後に一時ファイルを削除
            await cleanupTempFiles([glbPath]);
            if (err) {
                console.error('Error sending file:', err);
            }
        });
    }
    catch (error) {
        console.error('Request to /convert failed:', error);
        if (!res.headersSent) {
            res.status(500).json({ error: 'Failed to convert SDF to GLB' });
        }
        // エラー時にもクリーンアップを試みる
        if (glbPath) {
            await cleanupTempFiles([glbPath]);
        }
    }
});
app.listen(3000, () => {
    console.log("Server running on http://localhost:3000");
});
//# sourceMappingURL=server.js.map