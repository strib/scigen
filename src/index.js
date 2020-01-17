import { titleCase } from 'title-case'
import scirules from '../rules/rules-compiled/scirules.json'
import systemNames from '../rules/rules-compiled/system_names.json'

export const scigen = (authors, bibInLatex) => {
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

  const bibtex = (rules, bibInLatex) =>
    [...Array(rules.CITATIONLABEL).keys()]
      .map(label =>
        prettyPrint(
          generate(
            {
              ...scirules,
              ...metadata,
              CITE_LABEL_GIVEN: [label.toString()]
            },
            bibInLatex
              ? 'BIB_IN_LATEX_ENTRY'
              : 'BIBTEX_ENTRY')
            .text))
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

  const prettyPrint = text => {
    text = text
      .split('\n')
      .map(line => {
        line = line.trim()
        line = line.replace(/ +/g, ' ')
        line = line.replace(/\s+([.,?;:])/g, '$1')
        line = line.replace(/\ba\s+([aeiou])/gi, '$1')
        line = line.replace(/^\s*[a-z]/, l => l.toUpperCase())
        line = line.replace(/((([.:]\s+)|(=\s*\{\s*))[a-z])/g, l => l.toUpperCase())
        line = line.replace(
          /((jan)|(feb)|(mar)|(apr)|(jun)|(jul)|(aug)|(sep)|(oct)|(nov)|(dec))\s/gi,
          l => l[0].toUpperCase() + l.substring(1, l.length) + '. ')
        line = line.replace(/\\Em /g, '\\em')
        const title = line.match(/(\\(((sub)?section)|(slideheading)|(title))\*?)\{(.*)\}/)
        if (title) {
          line = title[1] + '{' + titleCase(title[7]) + '}'
        }
        if (line.match(/\n$/)) {
          line += '\n'
        }
        return line
      })
      .join('\n')
    return text
  }

  authors = authors || [
    generate(scirules, 'SCI_SOURCE').text,
    ...Math.random() > 0.5 ? [generate(scirules, 'SCI_SOURCE').text] : [],
    ...Math.random() > 0.5 ? [generate(scirules, 'SCI_SOURCE').text] : [],
    ...Math.random() > 0.5 ? [generate(scirules, 'SCI_SOURCE').text] : []
  ]

  const metadata = {
    SYSNAME: [systemName()],
    AUTHOR_NAME: authors,
    SCIAUTHORS: [
      authors
        .slice(0, -1)
        .join(', ') +
      (authors.length > 1
        ? ' and '
        : '') +
      authors[authors.length - 1]
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
      'paper.tex': bibInLatex
        ? text
          .replace( // replace citations by plain Latex
            /\\cite\{((cite:\d+(, )?)+)\}/g,
            (...args) =>
              '[' +
              args[1]
                .split(', ')
                .map(c =>
                  parseInt(
                    c.replace(/cite:/, '')) +
                  1)
                .join(', ') +
              ']')
          .replace( // replace references to figures / diagrams by plain Latex
            /\\ref\{([a-z0-9:,]+)\}/g,
            (...args) =>
              parseInt(
                args[1]
                  .replace(/((fig)|(dia)):label/, '')) +
              1)
          .replace( // create bibliography in plain Latex
            /\\bibliography\{scigenbibfile\}\n\\bibliographystyle\{((acm)|(IEEE))\}/,
            '\\section*{References}\n' +
            '\\renewcommand\\labelenumi{[\\theenumi]}\n' +
            '\\begin{enumerate}\n' +
            bibtex(rules, true)
              .replace(
                /\\textsc\{([^{}]*)\}\. /g,
                (match, authors) => {
                  authors = authors
                    .split(' and ')
                    .map(author => {
                      author = author.split(' ')
                      return author[author.length - 1] + ', ' +
                        author
                          .slice(0, -1)
                          .map(fName => fName[0] + '.')
                          .join(' ')
                    })
                  return '\\textsc{' +
                    authors
                      .slice(0, -1)
                      .join(', ') +
                    (authors.length >= 3
                      ? ','
                      : '') +
                    (authors.length >= 2
                      ? ' and '
                      : '') +
                    authors[authors.length - 1] + '} '
                }) +
            '\\end{enumerate}')
        : text,
      'scigenbibfile.bib': bibtex(rules, false),
      ...makeFigures(rules)
    }
  }
}
