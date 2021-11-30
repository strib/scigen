import { strict as assert } from "assert";
import { scigen, scigenSave } from "../lib/index.js";
import fs from "fs";
import path from "path";

let lastPaper = "";

// scigen

for (let i = 0; i < 2; i++) {
  const files = scigen({
    authors: ["Jeremy Stribling", "Max Krohn", "Dan Aguayo"],
    useBibtex: true,
  });
  assert.ok(files["paper.tex"].length > 5000);
  assert.ok(files["scigenbibfile.bib"].length > 1000);
  assert.ok(
    files["paper.tex"].match(
      /\\author\{Jeremy Stribling, Max Krohn and Dan Aguayo\}/
    ) !== null
  );
  assert.ok(files["paper.tex"].match(/\\end{document}\n*$/) !== null);
  assert.ok(Object.keys(files).some((a) => a.match(/^figure.\.eps$/)));
  assert.ok(files["paper.tex"] !== lastPaper);
  lastPaper = files["paper.tex"];
}

// scigenSave

for (let i = 0; i < 1; i++) {
  const folder = "tmp";
  if (fs.existsSync(folder)) fs.rmSync(folder, { recursive: true });
  scigenSave({
    directory: folder,
    authors: undefined,
    useBibtex: false,
    silent: true,
  });
  const files = Object.assign(
    ...fs.readdirSync(folder).map((file) => ({
      [file]: fs.readFileSync(path.join(folder, file), { encoding: "utf8" }),
    }))
  );
  assert.ok(files["paper.tex"].length > 5000);
  assert.ok(!("scigenbibfile.bib" in files));
  assert.ok(
    files["paper.tex"].match(
      /\\author\{Jeremy Stribling, Max Krohn and Dan Aguayo\}/
    ) === null
  );
  assert.ok(files["paper.tex"].match(/\\author\{[^}]{5,}\}/) !== null);
  assert.ok(files["paper.tex"].match(/\\end{document}\n*$/) !== null);
  assert.ok(Object.keys(files).some((a) => a.match(/^figure.\.eps$/)));
  assert.ok(files["paper.tex"] !== lastPaper);
  lastPaper = files["paper.tex"];
}
