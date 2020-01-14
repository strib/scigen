const path = require('path')

module.exports = {
  entry: './docs/webpack.js',
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'docs')
  }
}
