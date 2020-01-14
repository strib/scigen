import titleCase from 'title-case'
import scirules from '../rules/rules-compiled/scirules.json'
import systemNames from '../rules/rules-compiled/system_names.json'

export const scigen = authors => {
  const generate = (rules, start) => {
    const rx = new RegExp(
      '^(' +
      Object
        .keys(rules)
        .sort((a, b) => b.length - a.length)
        .join('|') +
      ')')

    const expand = (key) => {
      const pick = array =>
        array[Math.floor(Math.random() * array.length)]

      const plusRule = key.match(/(.*)[+]$/)
      const sharpRule = key.match(/(.*)[#]$/)
      if (plusRule) {
        if (plusRule[1] in rules) {
          rules[plusRule[1]] += 1
        } else {
          rules[plusRule[1]] = 1
        }
        return rules[plusRule[1]] - 1
      } else if (sharpRule) {
        if (sharpRule[1] in rules) {
          return Math.floor(
            Math.random() *
            (rules[sharpRule[1]] + 1))
        } else {
          return 0
        }
      } else {
        const process = rule => {
          let text = ''
          for (const i in rule) {
            const match = rule.substring(i).match(rx)
            if (match) {
              return text +
                expand(match[0]) +
                process(
                  rule.slice(
                    text.length +
                    match[0].length))
            } else {
              text += rule[i]
            }
          }
          return text
        }
        return process(pick(rules[key]))
      }
    }

    const prettyPrint = text => {
      text = text
        .split('\n')
        .map(line => {
          line = line.trim()
          line = line.replace(/ +/g, ' ')
          line = line.replace(/\s+([.,?;:])/g, '$1')
          line = line.replace(/\ba\s+([aeiou])/gi, '$1')
          const title = line.match(/(\\(((sub)?section)|(slideheading)|(title))\*?)\{(.*)\}/)
          if (title) {
            line = title[1] + '{' + titleCase.titleCase(title[7]) + '}'
          } else {
            line = line.replace(/^\s*[a-z]/, l => l.toUpperCase())
            line = line.replace(/(?=\.\s+)[a-z]/g, l => l.toUpperCase())
          }
          line = line.replace(/\\Em /g, '\\em')
          if (line.match(/\n$/)) {
            line += '\n'
          }
          return line
        })
        .join('\n')
      return text
    }

    return {
      text: prettyPrint(expand(start)),
      rules: rules
    }
  }

  const systemName = () => {
    const name = generate(systemNames, 'SYSTEM_NAME').text
    const r = Math.random()
    return r < 0.1
      ? `{\\em ${name}}`
      : name.length <= 6 && r < 0.4
        ? name.toUpperCase()
        : name
  }

  const bibtex = rules =>
    [...Array(rules.CITATIONLABEL).keys()]
      .map(label =>
        generate(
          {
            ...scirules,
            ...metadata,
            CITE_LABEL_GIVEN: ['cite:' + label.toString()]
          },
          'BIBTEX_ENTRY')
          .text)
      .join('')

  const makeFigures = rules => {
    let figures = {}
    for (const label of [...Array(rules.NEWFIGNUM).keys()]) {
      figures = {
        ...figures,
        ['figure' + label + '.eps']: '' // TODO
      }
    }
    for (const label of [...Array(rules.NEWDIANUM).keys()]) {
      figures = {
        ...figures,
        ['dia' + label + '.eps']: '' // TODO
      }
    }
    return figures
  }

  const metadata = {
    SYSNAME: [systemName()],
    AUTHOR_NAME: authors,
    SCI_SOURCE: authors,
    SCIAUTHORS: [
      authors
        .slice(0, -1)
        .join(', ') +
      (authors.length > 1
        ? (' and ' + authors[authors.length - 1])
        : '')
    ]
  }

  const { text, rules } = generate(
    {
      ...scirules,
      ...metadata
    },
    'SCIPAPER_LATEX'
  )

  return {
    files: {
      'paper.tex': text,
      'scigenbibfile.bib': bibtex(rules),
      ...makeFigures(rules)
    }
  }
}

// console.log(Object.keys(scigen(['Albert Einstein', 'Jürgen Habermas']).files))
