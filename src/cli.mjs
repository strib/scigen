#!/usr/bin/env node
import minimist from "minimist";
import fs from "fs";
import path from "path";
import { scigen } from "./scigen";

export const scigenSave = (
  { directory, authors, useBibtex, silent } = {
    directory: "scigen",
    authors: undefined,
    useBibtex: false,
    silent: false,
  }
) => {
  directory = path.resolve(...directory.split(/\\|\//g));
  if (!fs.existsSync(directory)) {
    fs.mkdirSync(directory);
  }
  const files = {
    ...scigen({ authors: authors, useBibtex: useBibtex }),
    "IEEEtran.cls": fs.readFileSync(path.resolve(__dirname, "IEEEtran.cls")),
    "IEEE.bst": fs.readFileSync(path.resolve(__dirname, "IEEE.bst")),
  };
  Object.keys(files).forEach((key) =>
    fs.writeFileSync(path.resolve(directory, key), files[key])
  );
  if (!silent) {
    console.log(
      `Saved in ${path.resolve(directory)}.\n` +
        "Run\n\n" +
        `\tcd ${path.resolve(directory)}\n` +
        "\tpdflatex paper.tex\n" +
        (useBibtex
          ? "\tbibtex paper.aux\n\tpdflatex paper.tex\n\tpdflatex paper.tex\n"
          : "") +
        "\nto compile to PDF."
    );
  }
};

if (require.main === module) {
  const argv = minimist(process.argv.slice(2));
  if ("save" in argv && argv.save) {
    scigenSave(
      (argv.authors
        ? argv.authors.split(",").map((l) => l.trim())
        : undefined) ||
        (argv.author ? argv.author.split(",").map((l) => l.trim()) : undefined),
      argv.useBibtex,
      argv.save || argv.dir,
      argv.quiet || argv.silent
    );
  } else {
    console.log(
      'Usage: node cli.js --save [<directory>] [--authors "<author1>, <author2>, ..."] [--useBibtex] [--silent]\n' +
        "\tdirectory \tall files (.tex, .eps, .cls, .bib, ...) will be saved here\n" +
        "\tauthors \tlist of the authors in the paper\n" +
        "\tuseBibtex \tuse Bibtex for formatting the bibliography (disable this for use with texlive.js)\n" +
        "\tsilent \t\tskip info logging"
    );
  }
}
