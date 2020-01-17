#!/usr/bin/env node
import minimist from 'minimist'
import fs from 'fs'
import { scigen } from './index.js'

const argv = minimist(process.argv.slice(2))

if ('save' in argv && argv.save) {
  let dir = ''
  if (typeof argv.save === 'string') {
    dir = argv.save.replace(/\/$/, '') + '/'
    if (!fs.existsSync('tmp')) {
      fs.mkdirSync(dir)
    }
  }
  const files = scigen(undefined, 'bibinlatex' in argv && argv.bibinlatex).files
  Object.keys(files)
    .forEach(key =>
      fs.writeFileSync(dir + key, files[key]))
}
