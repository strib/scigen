#!/usr/bin/env node
"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.saveScigen = void 0;

var _minimist = _interopRequireDefault(require("minimist"));

var _fs = _interopRequireDefault(require("fs"));

var _path = _interopRequireDefault(require("path"));

var _index = require("./index.js");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { "default": obj }; }

function ownKeys(object, enumerableOnly) { var keys = Object.keys(object); if (Object.getOwnPropertySymbols) { var symbols = Object.getOwnPropertySymbols(object); if (enumerableOnly) symbols = symbols.filter(function (sym) { return Object.getOwnPropertyDescriptor(object, sym).enumerable; }); keys.push.apply(keys, symbols); } return keys; }

function _objectSpread(target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i] != null ? arguments[i] : {}; if (i % 2) { ownKeys(Object(source), true).forEach(function (key) { _defineProperty(target, key, source[key]); }); } else if (Object.getOwnPropertyDescriptors) { Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)); } else { ownKeys(Object(source)).forEach(function (key) { Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key)); }); } } return target; }

function _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }

function _toConsumableArray(arr) { return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _nonIterableSpread(); }

function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance"); }

function _iterableToArray(iter) { if (Symbol.iterator in Object(iter) || Object.prototype.toString.call(iter) === "[object Arguments]") return Array.from(iter); }

function _arrayWithoutHoles(arr) { if (Array.isArray(arr)) { for (var i = 0, arr2 = new Array(arr.length); i < arr.length; i++) { arr2[i] = arr[i]; } return arr2; } }

var saveScigen = function saveScigen(authors, bibinlatex) {
  var directory = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 'scigen';
  var silent = arguments.length > 3 ? arguments[3] : undefined;
  directory = _path["default"].resolve.apply(_path["default"], _toConsumableArray(directory.split(/\\|\//g)));

  if (!_fs["default"].existsSync(directory)) {
    _fs["default"].mkdirSync(directory);
  }

  var files = _objectSpread({}, (0, _index.scigen)(authors, bibinlatex).files, {
    'IEEEtran.cls': _fs["default"].readFileSync(_path["default"].resolve(__dirname, 'IEEEtran.cls')),
    'IEEE.bst': _fs["default"].readFileSync(_path["default"].resolve(__dirname, 'IEEE.bst'))
  });

  Object.keys(files).forEach(function (key) {
    return _fs["default"].writeFileSync(_path["default"].resolve(directory, key), files[key]);
  });

  if (!silent) {
    console.log("Saved in ".concat(_path["default"].resolve(directory), ". Run\n") + "\tcd ".concat(_path["default"].resolve(directory), "\n") + '\tpdflatex paper.tex\n' + ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tbibtex paper.aux\n') + ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tpdflatex paper.tex\n') + ('bibinlatex' in argv && argv.bibinlatex ? '' : '\tpdflatex paper.tex\n') + 'to compile to PDF.');
  }
};

exports.saveScigen = saveScigen;
var argv = (0, _minimist["default"])(process.argv.slice(2));

if ('save' in argv && argv.save) {
  saveScigen((argv.authors ? argv.authors.split(',').map(function (l) {
    return l.trim();
  }) : undefined) || (argv.author ? argv.author.split(',').map(function (l) {
    return l.trim();
  }) : undefined), argv.bibinlatex, argv.save || argv.dir, argv.quiet || argv.silent);
} else {
  console.log('Usage: node cli.js --save [<directory>] [--authors "<author1>, <author2>, ..."] [--bibinlatex] [--silent]\n' + '\tdirectory \tall files (.tex, .eps, .cls, .bib, ...) will be saved here\n' + '\tauthors \tlist of the authors in the paper\n' + '\tbibinlatex \tavoids dependency on BibTex (useful especially for texlive.js)\n' + '\tsilent \t\tskip info logging');
}