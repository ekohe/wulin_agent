// esbuild entry a wulin_master v3 host imports from app/javascript/application.js.
// The host bundles the source with its own esbuild flags: the automatic JSX
// runtime comes from this gem's jsconfig.json, and the stylesheet arrives
// through the host's application.sass rather than a CSS import here.
import "./wulin_agent/index.jsx"
