"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.scigen = void 0;

var _minimist = _interopRequireDefault(require("minimist"));

var _titleCase = require("title-case");

var _fs = _interopRequireDefault(require("fs"));

var _scirules = _interopRequireDefault(require("../rules/rules-compiled/scirules.json"));

var _system_names = _interopRequireDefault(require("../rules/rules-compiled/system_names.json"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { "default": obj }; }

function ownKeys(object, enumerableOnly) { var keys = Object.keys(object); if (Object.getOwnPropertySymbols) { var symbols = Object.getOwnPropertySymbols(object); if (enumerableOnly) symbols = symbols.filter(function (sym) { return Object.getOwnPropertyDescriptor(object, sym).enumerable; }); keys.push.apply(keys, symbols); } return keys; }

function _objectSpread(target) { for (var i = 1; i < arguments.length; i++) { var source = arguments[i] != null ? arguments[i] : {}; if (i % 2) { ownKeys(Object(source), true).forEach(function (key) { _defineProperty(target, key, source[key]); }); } else if (Object.getOwnPropertyDescriptors) { Object.defineProperties(target, Object.getOwnPropertyDescriptors(source)); } else { ownKeys(Object(source)).forEach(function (key) { Object.defineProperty(target, key, Object.getOwnPropertyDescriptor(source, key)); }); } } return target; }

function _defineProperty(obj, key, value) { if (key in obj) { Object.defineProperty(obj, key, { value: value, enumerable: true, configurable: true, writable: true }); } else { obj[key] = value; } return obj; }

function _toConsumableArray(arr) { return _arrayWithoutHoles(arr) || _iterableToArray(arr) || _nonIterableSpread(); }

function _nonIterableSpread() { throw new TypeError("Invalid attempt to spread non-iterable instance"); }

function _iterableToArray(iter) { if (Symbol.iterator in Object(iter) || Object.prototype.toString.call(iter) === "[object Arguments]") return Array.from(iter); }

function _arrayWithoutHoles(arr) { if (Array.isArray(arr)) { for (var i = 0, arr2 = new Array(arr.length); i < arr.length; i++) { arr2[i] = arr[i]; } return arr2; } }

var scigen = function scigen(authors) {
  var generate = function generate(rules, start) {
    var rx = new RegExp('^(' + Object.keys(rules).sort(function (a, b) {
      return b.length - a.length;
    }).join('|') + ')');

    var expand = function expand(key) {
      var pick = function pick(array) {
        return array[Math.floor(Math.random() * array.length)];
      };

      var plusRule = key.match(/(.*)[+]$/);
      var sharpRule = key.match(/(.*)[#]$/);

      if (plusRule) {
        if (plusRule[1] in rules) {
          rules[plusRule[1]] += 1;
        } else {
          rules[plusRule[1]] = 1;
        }

        return rules[plusRule[1]] - 1;
      } else if (sharpRule) {
        if (sharpRule[1] in rules) {
          return Math.floor(Math.random() * (rules[sharpRule[1]] + 1));
        } else {
          return 0;
        }
      } else {
        var _process = function _process(rule) {
          var text = '';

          for (var i in rule) {
            var match = rule.substring(i).match(rx);

            if (match) {
              return text + expand(match[0]) + _process(rule.slice(text.length + match[0].length));
            } else {
              text += rule[i];
            }
          }

          return text;
        };

        return _process(pick(rules[key]));
      }
    };

    return {
      text: prettyPrint(expand(start)),
      rules: rules
    };
  };

  var systemName = function systemName() {
    var name = generate(_system_names["default"], 'SYSTEM_NAME').text;
    var r = Math.random();
    return r < 0.1 ? "{\\em ".concat(name, "}") : name.length <= 6 && r < 0.4 ? name.toUpperCase() : name;
  };

  var bibtex = function bibtex(rules) {
    return _toConsumableArray(Array(rules.CITATIONLABEL).keys()).map(function (label) {
      return prettyPrint(generate(_objectSpread({}, _scirules["default"], {}, metadata, {
        CITE_LABEL_GIVEN: ['cite:' + label.toString()]
      }), 'BIBTEX_ENTRY').text);
    }).join('');
  };

  var makeFigures = function makeFigures(rules) {
    var figures = {};

    for (var _i = 0, _arr = _toConsumableArray(Array(rules.NEWFIGNUM).keys()); _i < _arr.length; _i++) {
      var label = _arr[_i];
      figures = _objectSpread({}, figures, _defineProperty({}, 'figure' + label + '.eps', ''));
    }

    for (var _i2 = 0, _arr2 = _toConsumableArray(Array(rules.NEWDIANUM).keys()); _i2 < _arr2.length; _i2++) {
      var _label = _arr2[_i2];
      figures = _objectSpread({}, figures, _defineProperty({}, 'dia' + _label + '.eps', ''));
    }

    return figures;
  };

  var prettyPrint = function prettyPrint(text) {
    text = text.split('\n').map(function (line) {
      line = line.trim();
      line = line.replace(/ +/g, ' ');
      line = line.replace(/\s+([.,?;:])/g, '$1');
      line = line.replace(/\ba\s+([aeiou])/gi, '$1');
      var title = line.match(/(\\(((sub)?section)|(slideheading)|(title))\*?)\{(.*)\}/);

      if (title) {
        line = title[1] + '{' + (0, _titleCase.titleCase)(title[7]) + '}';
      } else {
        line = line.replace(/^\s*[a-z]/, function (l) {
          return l.toUpperCase();
        });
        line = line.replace(/(\.\s+)|(=\s*\{\s*)[a-z]/g, function (l) {
          return l.toUpperCase();
        });
      }

      line = line.replace(/\\Em /g, '\\em');

      if (line.match(/\n$/)) {
        line += '\n';
      }

      return line;
    }).join('\n');
    return text;
  };

  authors = authors || [generate(_scirules["default"], 'SCI_SOURCE').text].concat(_toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], 'SCI_SOURCE').text] : []), _toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], 'SCI_SOURCE').text] : []), _toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], 'SCI_SOURCE').text] : []));
  var metadata = {
    SYSNAME: [systemName()],
    AUTHOR_NAME: authors,
    SCIAUTHORS: [authors.slice(0, -1).join(', ') + (authors.length > 1 ? ' and ' : '') + authors[authors.length - 1]]
  };

  var _generate = generate(_objectSpread({}, _scirules["default"], {}, metadata), 'SCIPAPER_LATEX'),
      text = _generate.text,
      rules = _generate.rules;

  return {
    files: _objectSpread({
      'paper.tex': text,
      'scigenbibfile.bib': bibtex(rules)
    }, makeFigures(rules))
  };
};

exports.scigen = scigen;
{
  var argv = (0, _minimist["default"])(process.argv.slice(2));

  if ('save' in argv && argv.save) {
    var dir = '';

    if (typeof argv.save === 'string') {
      dir = argv.save.replace(/\/$/, '') + '/';

      if (!_fs["default"].existsSync('tmp')) {
        _fs["default"].mkdirSync(dir);
      }
    }

    var files = scigen().files;
    Object.keys(files).forEach(function (key) {
      return _fs["default"].writeFileSync(dir + key, files[key]);
    });
  }
}