"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.scigen = void 0;

var _titleCase = require("title-case");

var _scirules = _interopRequireDefault(require("../rules/rules-compiled/scirules.json"));

var _system_names = _interopRequireDefault(require("../rules/rules-compiled/system_names.json"));

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

var scigen = function scigen() {
  var _ref = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {
    authors: undefined,
    useBibtex: true
  },
      authors = _ref.authors,
      useBibtex = _ref.useBibtex;

  var generate = function generate(rules, start) {
    var rx = new RegExp("^(" + Object.keys(rules).sort(function (a, b) {
      return b.length - a.length;
    }).join("|") + ")");

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
        var process = function process(rule) {
          var text = "";

          for (var i in rule) {
            var match = rule.substring(i).match(rx);

            if (match) {
              return text + expand(match[0]) + process(rule.slice(text.length + match[0].length));
            } else {
              text += rule[i];
            }
          }

          return text;
        };

        return process(pick(rules[key]));
      }
    };

    return {
      text: prettyPrint(expand(start)),
      rules: rules
    };
  };

  var systemName = function systemName() {
    var name = generate(_system_names["default"], "SYSTEM_NAME").text;
    var r = Math.random();
    return r < 0.1 ? "{\\em ".concat(name, "}") : name.length <= 6 && r < 0.4 ? name.toUpperCase() : name;
  };

  var bibtex = function bibtex(rules, useBibtex) {
    return _toConsumableArray(Array(rules.CITATIONLABEL).keys()).map(function (label) {
      return prettyPrint(generate(_objectSpread(_objectSpread(_objectSpread({}, _scirules["default"]), metadata), {}, {
        CITE_LABEL_GIVEN: [label.toString()]
      }), useBibtex ? "BIB_IN_LATEX_ENTRY" : "BIBTEX_ENTRY").text);
    }).join("");
  };

  var latexifyBibtex = function latexifyBibtex(text) {
    return text.replace( // replace citations by plain Latex
    /\\cite\{((cite:\d+(, )?)+)\}/g, function () {
      for (var _len = arguments.length, args = new Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }

      return "[" + args[1].split(", ").map(function (c) {
        return parseInt(c.replace(/cite:/, "")) + 1;
      }).join(", ") + "]";
    }).replace( // replace references to figures / diagrams by plain Latex
    /\\ref\{([a-z0-9:,]+)\}/g, function () {
      for (var _len2 = arguments.length, args = new Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
        args[_key2] = arguments[_key2];
      }

      return parseInt(args[1].replace(/((fig)|(dia)):label/, "")) + 1;
    }).replace( // create bibliography in plain Latex
    /\\bibliography\{scigenbibfile\}\n\\bibliographystyle\{((acm)|(IEEE))\}/, "\\section*{References}\n" + "\\renewcommand\\labelenumi{[\\theenumi]}\n" + "\\begin{enumerate}\n" + bibtex(rules, true).replace(/\\textsc\{([^{}]*)\}\. /g, function (match, authors) {
      authors = authors.split(" and ").map(function (author) {
        author = author.split(" ");
        return author[author.length - 1] + ", " + author.slice(0, -1).map(function (fName) {
          return fName[0] + ".";
        }).join(" ");
      });
      return "\\textsc{" + authors.slice(0, -1).join(", ") + (authors.length >= 3 ? "," : "") + (authors.length >= 2 ? " and " : "") + authors[authors.length - 1] + "} ";
    }) + "\\end{enumerate}");
  };

  var makeFigures = function makeFigures(rules) {
    var figures = {};

    for (var _i = 0, _arr = _toConsumableArray(Array(rules.NEWFIGNUM).keys()); _i < _arr.length; _i++) {
      var label = _arr[_i];
      figures = _objectSpread(_objectSpread({}, figures), {}, _defineProperty({}, "figure" + label + ".eps", ""));
    }

    for (var _i2 = 0, _arr2 = _toConsumableArray(Array(rules.NEWDIANUM).keys()); _i2 < _arr2.length; _i2++) {
      var _label = _arr2[_i2];
      figures = _objectSpread(_objectSpread({}, figures), {}, _defineProperty({}, "dia" + _label + ".eps", ""));
    }

    return figures;
  };

  var prettyPrint = function prettyPrint(text) {
    text = text.split("\n").map(function (line) {
      line = line.trim();
      line = line.replace(/ +/g, " ");
      line = line.replace(/\s+([.,?;:])/g, "$1");
      line = line.replace(/\ba\s+([aeiou])/gi, "$1");
      line = line.replace(/^\s*[a-z]/, function (l) {
        return l.toUpperCase();
      });
      line = line.replace(/((([.:?!]\s+)|(=\s*\{\s*))[a-z])/g, function (l) {
        return l.toUpperCase();
      });
      line = line.replace(/\W((jan)|(feb)|(mar)|(apr)|(jun)|(jul)|(aug)|(sep)|(oct)|(nov)|(dec))\s/gi, function (l) {
        return l[0].toUpperCase() + l.substring(1, l.length) + ". ";
      });
      line = line.replace(/\\Em /g, "\\em");
      var titleMatch = line.match(/(\\(((sub)?section)|(slideheading)|(title))\*?)\{(.*)\}/);

      if (titleMatch) {
        line = titleMatch[1] + "{" + titleMatch[7][0].toUpperCase() + (0, _titleCase.titleCase)(titleMatch[7]).slice(1) + "}";
      }

      if (line.match(/\n$/)) {
        line += "\n";
      }

      return line;
    }).join("\n");
    return text;
  };

  authors = authors || [generate(_scirules["default"], "SCI_SOURCE").text].concat(_toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], "SCI_SOURCE").text] : []), _toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], "SCI_SOURCE").text] : []), _toConsumableArray(Math.random() > 0.5 ? [generate(_scirules["default"], "SCI_SOURCE").text] : []));
  var metadata = {
    SYSNAME: [systemName()],
    AUTHOR_NAME: authors,
    SCIAUTHORS: [authors.slice(0, -1).join(", ") + (authors.length > 1 ? " and " : "") + authors[authors.length - 1]],
    SCI_SOURCE: [].concat(_toConsumableArray(_scirules["default"].SCI_SOURCE), _toConsumableArray(authors.flatMap(function (l, i, a) {
      return Array(15).fill(l);
    })))
  };

  var _generate = generate(_objectSpread(_objectSpread({}, _scirules["default"]), metadata), "SCIPAPER_LATEX"),
      text = _generate.text,
      rules = _generate.rules;

  return _objectSpread(_objectSpread({
    "paper.tex": useBibtex ? text : latexifyBibtex(text)
  }, useBibtex ? {
    "scigenbibfile.bib": bibtex(rules, false)
  } : {}), makeFigures(rules));
};

exports.scigen = scigen;