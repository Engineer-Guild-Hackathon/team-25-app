// converter.ts
import { promises as fs } from 'fs';
import path from 'path';
import os from 'os';
import { exec } from 'child_process';
import util from 'util';
const execPromise = util.promisify(exec);
export async function cleanupTempFiles(filePaths) {
    for (const filePath of filePaths) {
        try {
            await fs.unlink(filePath);
        }
        catch (error) {
            if (error.code !== 'ENOENT')
                console.error(error);
        }
    }
}
// ----------------- SDF Parser -----------------
function parseSdf(sdfData) {
    const lines = sdfData.split('\n');
    const countsLine = lines[3];
    if (!countsLine) {
        throw new Error("SDFの counts line が見つかりません");
    }
    const atomCount = parseInt(countsLine.substr(0, 3));
    const bondCount = parseInt(countsLine.substr(3, 3));
    const atoms = [];
    const bonds = [];
    for (let i = 0; i < atomCount; i++) {
        const line = lines[4 + i];
        if (!line)
            continue;
        const x = parseFloat(line.substr(0, 10));
        const y = parseFloat(line.substr(10, 10));
        const z = parseFloat(line.substr(20, 10));
        const element = line.substr(31, 3).trim();
        atoms.push({ x, y, z, element });
    }
    for (let i = 0; i < bondCount; i++) {
        const line = lines[4 + atomCount + i];
        if (!line)
            continue;
        const a = parseInt(line.substr(0, 3));
        const b = parseInt(line.substr(3, 3));
        const order = parseInt(line.substr(6, 3));
        bonds.push({ a, b, order });
    }
    return { atoms, bonds };
}
// ----------------- Element Data (CPK Colors) -----------------
const atomData = {
    'H': { radius: 0.4, color: [1.0, 1.0, 1.0] }, // White
    'C': { radius: 0.7, color: [0.2, 0.2, 0.2] }, // Black
    'N': { radius: 0.65, color: [0.19, 0.31, 0.97] }, // Blue
    'O': { radius: 0.6, color: [1.0, 0.05, 0.05] }, // Red
    'F': { radius: 0.55, color: [0.56, 0.88, 0.31] }, // Green
    'Cl': { radius: 0.99, color: [0.12, 0.94, 0.12] }, // Green
    'Br': { radius: 1.14, color: [0.65, 0.16, 0.16] }, // Dark Red
    'I': { radius: 1.33, color: [0.58, 0.0, 0.58] }, // Purple
    'P': { radius: 1.1, color: [1.0, 0.65, 0.0] }, // Orange
    'S': { radius: 1.0, color: [1.0, 1.0, 0.19] }, // Yellow
    'B': { radius: 0.85, color: [1.0, 0.71, 0.71] }, // Pink
    'Si': { radius: 1.1, color: [0.78, 0.78, 0.86] }, // Light Grey
    'DEFAULT': { radius: 0.5, color: [0.86, 0.86, 0.86] }, // Grey
};
// ----------------- Manual OBJ + MTL Generation -----------------
function createObjAndMtlData(sdfData) {
    const { atoms, bonds } = parseSdf(sdfData);
    let vertices = [];
    let faces = [];
    let vertexOffset = 0;
    const mtlSet = new Set();
    // Atoms -> Spheres
    atoms.forEach((atom) => {
        const data = atomData[atom.element] ?? atomData['DEFAULT'];
        if (!data) {
            console.warn("processData was called with undefined data. Skipping.");
            return;
        }
        const radius = data.radius * 0.5;
        const segments = 16;
        const materialName = atom.element in atomData ? atom.element : 'DEFAULT';
        // register material
        mtlSet.add(materialName);
        // vertices
        for (let i = 0; i <= segments; i++) {
            const lat = Math.PI * i / segments;
            const sinLat = Math.sin(lat);
            const cosLat = Math.cos(lat);
            for (let j = 0; j <= segments; j++) {
                const lon = 2 * Math.PI * j / segments;
                const x = atom.x + radius * sinLat * Math.cos(lon);
                const y = atom.y + radius * sinLat * Math.sin(lon);
                const z = atom.z + radius * cosLat;
                vertices.push(`v ${x} ${y} ${z}`);
            }
        }
        // faces with material
        faces.push(`usemtl ${materialName}`);
        for (let i = 0; i < segments; i++) {
            for (let j = 0; j < segments; j++) {
                const p1 = vertexOffset + i * (segments + 1) + j;
                const p2 = vertexOffset + (i + 1) * (segments + 1) + j;
                const p3 = vertexOffset + (i + 1) * (segments + 1) + j + 1;
                const p4 = vertexOffset + i * (segments + 1) + j + 1;
                faces.push(`f ${p1 + 1} ${p2 + 1} ${p3 + 1}`);
                faces.push(`f ${p1 + 1} ${p3 + 1} ${p4 + 1}`);
            }
        }
        vertexOffset = vertices.length;
    });
    // Bonds -> Cylinders (簡略版、全部同じ色)
    if (bonds.length > 0) {
        mtlSet.add("Bond");
    }
    bonds.forEach(bond => {
        const atomA = atoms[bond.a - 1];
        const atomB = atoms[bond.b - 1];
        if (!atomA || !atomB)
            return;
        const start = { x: atomA.x, y: atomA.y, z: atomA.z };
        const end = { x: atomB.x, y: atomB.y, z: atomB.z };
        const bondRadius = 0.05;
        const segments = 8;
        const dx = end.x - start.x, dy = end.y - start.y, dz = end.z - start.z;
        const length = Math.sqrt(dx * dx + dy * dy + dz * dz);
        if (length === 0)
            return;
        // cylinder vertices
        for (let i = 0; i < segments; i++) {
            const angle = 2 * Math.PI * i / segments;
            const x = bondRadius * Math.cos(angle);
            const y = bondRadius * Math.sin(angle);
            vertices.push(`v ${start.x + x} ${start.y + y} ${start.z}`);
            vertices.push(`v ${end.x + x} ${end.y + y} ${end.z}`);
        }
        // faces with material
        faces.push(`usemtl Bond`);
        for (let i = 0; i < segments; i++) {
            const i1 = vertexOffset + i * 2;
            const i2 = vertexOffset + ((i + 1) % segments) * 2;
            faces.push(`f ${i1 + 1} ${i2 + 1} ${i1 + 2}`);
            faces.push(`f ${i2 + 1} ${i2 + 2} ${i1 + 2}`);
        }
        vertexOffset = vertices.length;
    });
    // MTLファイル生成
    let mtlData = "";
    mtlSet.forEach(name => {
        const data = atomData[name] ?? atomData['DEFAULT'];
        if (!data) {
            console.warn("processData was called with undefined data. Skipping.");
            return;
        }
        const [r, g, b] = data.color;
        mtlData += `newmtl ${name}\nKd ${r} ${g} ${b}\nKa 0.2 0.2 0.2\n\n`;
    });
    const objData = `mtllib molecules.mtl\n` + vertices.join("\n") + "\n" + faces.join("\n");
    return { obj: objData, mtl: mtlData };
}
// ----------------- Main API -----------------
export async function convertSdfToGlb(sdfData) {
    let objPath;
    let mtlPath;
    try {
        const { obj, mtl } = createObjAndMtlData(sdfData);
        const tempId = `mol_${Date.now()}`;
        objPath = path.join(os.tmpdir(), `${tempId}.obj`);
        mtlPath = path.join(os.tmpdir(), `molecules.mtl`);
        await fs.writeFile(objPath, obj);
        await fs.writeFile(mtlPath, mtl);
        const glbPath = objPath.replace('.obj', '.glb');
        const command = `npx obj2gltf -i ${objPath} -o ${glbPath}`;
        const { stderr } = await execPromise(command);
        if (stderr)
            console.warn('obj2gltf stderr:', stderr);
        await fs.access(glbPath);
        return glbPath;
    }
    catch (error) {
        console.error('Conversion failed:', error);
        throw new Error('SDF->GLB conversion failed.');
    }
    finally {
        if (objPath)
            await cleanupTempFiles([objPath]);
        if (mtlPath)
            await cleanupTempFiles([mtlPath]);
    }
}
