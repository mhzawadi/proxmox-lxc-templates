import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://mhzawadi.github.io",
  base: "/proxmox-lxc-templates",
  build: {
    assets: "assets",
  },
  vite: {
    build: {
      cssMinify: true,
    },
  },
});
