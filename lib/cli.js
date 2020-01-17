#!/usr/bin/env node
"use strict";

var _minimist = _interopRequireDefault(require("minimist"));

var _fs = _interopRequireDefault(require("fs"));

var _index = require("./index.js");

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { "default": obj }; }

var argv = (0, _minimist["default"])(process.argv.slice(2));

if ('save' in argv && argv.save) {
  var dir = '';

  if (typeof argv.save === 'string') {
    dir = argv.save.replace(/\/$/, '') + '/';

    if (!_fs["default"].existsSync('tmp')) {
      _fs["default"].mkdirSync(dir);
    }
  }

  var files = (0, _index.scigen)(undefined, 'bibinlatex' in argv && argv.bibinlatex).files;
  Object.keys(files).forEach(function (key) {
    return _fs["default"].writeFileSync(dir + key, files[key]);
  });
}