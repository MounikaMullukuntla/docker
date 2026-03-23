import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import cssInjectedByJs from "vite-plugin-css-injected-by-js";
import { resolve } from "path";

export default defineConfig({
  plugins: [react(), tailwindcss(), cssInjectedByJs()],

  resolve: {
    alias: [
      // Override @/lib/utils to avoid pulling in chat's heavy dependencies
      // (chat's utils.ts imports drizzle-schema, errors, ai-sdk types, etc.)
      {
        find: /^@\/lib\/utils$/,
        replacement: resolve(__dirname, "src/utils.ts"),
      },
      // Map all other @/ imports to the chat project root so shadcn UI
      // components, types, and other shared code resolve correctly.
      // Rollup's node resolver then finds node_modules via chat/node_modules/.
      // NOTE: path.resolve() strips trailing slashes, so we re-add "/" to
      //       prevent "@/lib/foo" becoming "chatlib/foo" on Windows.
      {
        find: /^@\//,
        replacement: resolve(__dirname, "../../chat") + "/",
      },
    ],
  },

  build: {
    lib: {
      entry: resolve(__dirname, "src/index.tsx"),
      name: "GitHubComponents",
      // Output as an IIFE so it works via a plain <script> tag with no bundler
      formats: ["iife"],
      fileName: () => "github-components.js",
    },
    rollupOptions: {
      // Bundle everything — requests/engine has no React on the page
      external: [],
    },
    outDir: resolve(__dirname, "dist"),
    emptyOutDir: true,
    // Inline assets (fonts, small images) to keep the output a single file
    assetsInlineLimit: 100 * 1024,
  },
});
