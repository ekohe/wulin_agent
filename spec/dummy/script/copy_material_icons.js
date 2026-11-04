// The compiled CSS refers to the material-icons webfonts by bare filename, so
// they are copied where Propshaft can serve them (wulin_master/template.rb).
const fs = require("fs");
const path = require("path");

const srcDir = path.join(__dirname, "..", "node_modules", "material-icons", "iconfont");
const dstDir = path.join(__dirname, "..", "app", "assets", "fonts");

fs.mkdirSync(dstDir, { recursive: true });

for (const name of ["material-icons.woff2", "material-icons.woff"]) {
  fs.copyFileSync(path.join(srcDir, name), path.join(dstDir, name));
}
