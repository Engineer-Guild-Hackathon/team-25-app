export interface Result {
    objectName: string;
    molecules: {
        name: string;
        description: string;
        confidence: number;
        formula?: string;
    }[];
}
export interface MoleculeInfo {
    cid: number;
    sdf: string;
}
//# sourceMappingURL=types.d.ts.map