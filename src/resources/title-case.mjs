/*
The MIT License (MIT)

Copyright (c) 2014 Blake Embrey (hello@blakeembrey.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

/*
The original code from https://github.com/blakeembrey/change-case/blob/master/packages/title-case/src/index.ts has been modified:
- Convert from TypeScript to JavaScript Standard Style.
*/

var SMALL_WORDS = /\b(?:an?d?|a[st]|because|but|by|en|for|i[fn]|neither|nor|o[fnr]|only|over|per|so|some|tha[tn]|the|to|up|upon|vs?\.?|versus|via|when|with|without|yet)\b/i
var TOKENS = /[^\s:–—-]+|./g

var WHITESPACE = /\s/
var IS_MANUAL_CASE = /.(?=[A-Z]|\..)/
var ALPHANUMERIC_PATTERN = /[A-Za-z0-9\u00C0-\u00FF]/
export function titleCase (input) {
  var result = ''
  var m
  // tslint:disable-next-line
  while ((m = TOKENS.exec(input)) !== null) {
    var token = m[0]
    var index = m.index
    if (
      // Ignore already capitalized words.
      !IS_MANUAL_CASE.test(token) &&
      // Ignore small words except at beginning or end.
      (!SMALL_WORDS.test(token) ||
        index === 0 ||
        index + token.length === input.length) &&
      // Ignore URLs.
      (input.charAt(index + token.length) !== ':' ||
        WHITESPACE.test(input.charAt(index + token.length + 1)))) {
      // Find and uppercase first word character, skips over *modifiers*.
      result += token.replace(ALPHANUMERIC_PATTERN, function (m) { return m.toUpperCase() })
      continue
    }
    result += token
  }
  return result
}
