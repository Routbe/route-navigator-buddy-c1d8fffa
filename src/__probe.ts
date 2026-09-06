import { neonAuth } from "@/lib/neon";
type K = keyof typeof neonAuth;
const k: K = "" as never;
console.log(k);
