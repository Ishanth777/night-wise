export const clamp01 = (x: number): number => Math.min(1, Math.max(0, x));
export const clamp = (x: number, lo: number, hi: number): number => Math.min(hi, Math.max(lo, x));
export const round1 = (x: number): number => Math.round(x * 10) / 10;
