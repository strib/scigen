const path = require('path')

module.exports = {
  entry: './src/web.mjs',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'docs')
  }
}
