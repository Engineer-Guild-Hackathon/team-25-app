import fetch from "node-fetch";
// moleculeName 分子名 (例: "glucose")
// returns CIDとSDFデータを含むオブジェクト、またはnull
export async function getMoleculeInfo(moleculeName) {
    try {
        // 1. 分子名からCIDを取得
        const cidUrl = `https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name/${encodeURIComponent(moleculeName)}/cids/JSON`;
        const cidResponse = await fetch(cidUrl);
        if (!cidResponse.ok) {
            console.error(`Failed to get CID for ${moleculeName}:`, cidResponse.statusText);
            return null;
        }
        const cidJson = await cidResponse.json();
        const cid = cidJson.IdentifierList?.CID?.[0];
        if (!cid) {
            console.warn(`No CID found for ${moleculeName}`);
            return null;
        }
        // 2. CIDからSDFデータを取得
        const sdfUrl = `https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/cid/${cid}/SDF`;
        const sdfResponse = await fetch(sdfUrl);
        if (!sdfResponse.ok) {
            console.error(`Failed to get SDF for CID ${cid}:`, sdfResponse.statusText);
            return null;
        }
        const sdfData = await sdfResponse.text();
        return { cid, sdf: sdfData };
    }
    catch (err) {
        console.error(`Error fetching molecule info for ${moleculeName}:`, err);
        return null;
    }
}
//# sourceMappingURL=pubchem.js.map