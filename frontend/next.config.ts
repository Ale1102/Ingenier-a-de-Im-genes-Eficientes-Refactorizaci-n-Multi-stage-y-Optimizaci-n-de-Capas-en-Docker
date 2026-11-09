import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Genera .next/standalone con solo lo necesario para ejecutar el servidor
  output: "standalone",
};

export default nextConfig;
