#!/usr/bin/env node
"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.scigenSave = void 0;

var _minimist = _interopRequireDefault(require("minimist"));

var _fs = _interopRequireDefault(require("fs"));

var _path = _interopRequireDefault(require("path"));

var _scigen = require("./scigen");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { "default": obj }; }

function ownKeys(object, enumerableOnly) { var keys = Object.keys(object); if (Object.getOwnPropertySymbols) { var symbols = Object.getOwnPropertySymbols(object); if (enumerableOnly) { symbols = symbols.filter(function (sym) { return Object.getOwnPropertyDescriptor(object, sym).enumerable; }); } keys.push.apply(keys, symbols); } return keys; }

function _objectSpread(target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i] != null ? arguments[i] : {}; if (i % 2) { ownKeys(Object(source), true).forEach(function (key) { _defineProperty(target, key, source[key]); }); } else if (Object.getOwnPropertyDescriptors) { Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)); } else { ownKeys(Object(source)).forEach(function (key) { Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key)); }); } } return target; }

function _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }

function _toConsumableArray(arr) { return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _unsupportedIterableToArray(arr) || _nonIterableSpread(); }

function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); }

function _unsupportedIterableToArray(o, minLen) { if (!o) return; if (typeof o === "string") return _arrayLikeToArray(o, minLen); var n = Object.prototype.toString.call(o).slice(8, -1); if (n === "Object" && o.constructor) n = o.constructor.name; if (n === "Map" || n === "Set") return Array.from(o); if (n === "Arguments" || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(n)) return _arrayLikeToArray(o, minLen); }

function _iterableToArray(iter) { if (typeof Symbol !== "undefined" && iter[Symbol.iterator] != null || iter["@@iterator"] != null) return Array.from(iter); }

function _arrayWithoutHoles(arr) { if (Array.isArray(arr)) return _arrayLikeToArray(arr); }

function _arrayLikeToArray(arr, len) { if (len == null || len > arr.length) len = arr.length; for (var i = 0, arr2 = new Array(len); i < len; i++) { arr2[i] = arr[i]; } return arr2; }

var scigenSave = function scigenSave() {
  var _ref = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {
    directory: "scigen",
    authors: undefined,
    useBibtex: false,
    silent: false
  },
      directory = _ref.directory,
      authors = _ref.authors,
      useBibtex = _ref.useBibtex,
      silent = _ref.silent;

  directory = _path["default"].resolve.apply(_path["default"], _toConsumableArray(directory.split(/\\|\//g)));

  if (!_fs["default"].existsSync(directory)) {
    _fs["default"].mkdirSync(directory);
  }

  var files = _objectSpread(_objectSpread({}, (0, _scigen.scigen)({
    authors: authors,
    useBibtex: useBibtex
  })), {}, {
    "IEEEtran.cls": _fs["default"].readFileSync(_path["default"].resolve(__dirname, "IEEEtran.cls")),
    "IEEE.bst": _fs["default"].readFileSync(_path["default"].resolve(__dirname, "IEEE.bst"))
  });

  Object.keys(files).forEach(function (key) {
    return _fs["default"].writeFileSync(_path["default"].resolve(directory, key), files[key]);
  });

  if (!silent) {
    console.log("Saved in ".concat(_path["default"].resolve(directory), ".\n") + "Run\n\n" + "\tcd ".concat(_path["default"].resolve(directory), "\n") + "\tpdflatex paper.tex\n" + (useBibtex ? "\tbibtex paper.aux\n\tpdflatex paper.tex\n\tpdflatex paper.tex\n" : "") + "\nto compile to PDF.");
  }
};

exports.scigenSave = scigenSave;

if (require.main === module) {
  var argv = (0, _minimist["default"])(process.argv.slice(2));

  if ("save" in argv && argv.save) {
    scigenSave((argv.authors ? argv.authors.split(",").map(function (l) {
      return l.trim();
    }) : undefined) || (argv.author ? argv.author.split(",").map(function (l) {
      return l.trim();
    }) : undefined), argv.useBibtex, argv.save || argv.dir, argv.quiet || argv.silent);
  } else {
    console.log('Usage: node cli.js --save [<directory>] [--authors "<author1>, <author2>, ..."] [--useBibtex] [--silent]\n' + "\tdirectory \tall files (.tex, .eps, .cls, .bib, ...) will be saved here\n" + "\tauthors \tlist of the authors in the paper\n" + "\tuseBibtex \tuse Bibtex for formatting the bibliography (disable this for use with texlive.js)\n" + "\tsilent \t\tskip info logging");
  }
}