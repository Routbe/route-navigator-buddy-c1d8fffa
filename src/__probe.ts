import { neonAuth } from "@/lib/neon";
const bad: number = neonAuth as unknown as typeof neonAuth extends never ? number : never;
export const x = bad;
