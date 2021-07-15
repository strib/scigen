#!/usr/bin/env node
import minimist from 'minimist'
import fs from 'fs'
import path from 'path'
import { scigen } from './scigen.js'

export const saveScigen = (authors, bibinlatex, directory = 'scigen', silent) => {
  directory = path.resolve(...directory.split(/\\|\//g))
  if (!fs.existsSync(directory)) {
    fs.mkdirSync(directory)
  }
  const files = {
    ...scigen(authors, bibinlatex).files,
    'IEEEtran.cls': fs.readFileSync(path.resolve(__dirname, 'IEEEtran.cls')),
    'IEEE.bst': fs.readFileSync(path.resolve(__dirname, 'IEEE.bst'))
  }
  Object.keys(files)
    .forEach(key =>
      fs.writeFileSync(path.resolve(directory, key), files[key]))
  if (!silent) {
    console.log(
      `Saved in ${path.resolve(directory)}.\n` +
      'Run\n' +
      `\tcd ${path.resolve(directory)}\n` +
      '\tpdflatex paper.tex\n' +
      ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tbibtex paper.aux\n') +
      ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tpdflatex paper.tex\n') +
      ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tpdflatex paper.tex\n') +
      'to compile to PDF.')
  }
}

const argv = minimist(process.argv.slice(2))
if ('save' in argv && argv.save) {
  saveScigen(
    (argv.authors
      ? argv.authors
        .split(',')
        .map(l => l.trim())
      : undefined) ||
    (argv.author
      ? argv.author
        .split(',')
        .map(l => l.trim())
      : undefined),
    argv.bibinlatex,
    argv.save || argv.dir,
    argv.quiet || argv.silent)
} else {
  console.log(
    'Usage: node cli.js --save [<directory>] [--authors "<author1>, <author2>, ..."] [--bibinlatex] [--silent]\n' +
    '\tdirectory \tall files (.tex, .eps, .cls, .bib, ...) will be saved here\n' +
    '\tauthors \tlist of the authors in the paper\n' +
    '\tbibinlatex \tavoids dependency on BibTex (useful especially for texlive.js)\n' +
    '\tsilent \t\tskip info logging'
  )
}
