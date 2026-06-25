import esbuild from "esbuild";
import path from "path";
import {fileURLToPath} from "url";

const dir = path.dirname(fileURLToPath(import.meta.url));
const watch = process.argv.includes("--watch");

const options = {
  entryPoints: [path.resolve(dir, "javascript/wulin_agent/index.jsx")],
  outfile: path.resolve(dir, "assets/builds/wulin_agent.js"),
  bundle: true,
  format: "iife",
  loader: {".jsx": "jsx", ".css": "css"},
  nodePaths: [path.resolve(dir, "node_modules")],
  alias: {
    react: path.resolve(dir, "node_modules/react"),
    "react-dom": path.resolve(dir, "node_modules/react-dom"),
  },
  jsx: "automatic",
  jsxImportSource: "react",
};

if (watch) {
  const ctx = await esbuild.context(options);
  await ctx.watch();
  console.log("watching wulin_agent.js…");
} else {
  esbuild.buildSync(options);
}
