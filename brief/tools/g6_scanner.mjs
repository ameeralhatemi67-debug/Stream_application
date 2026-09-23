// Keep the original Text('...') candidate pattern so existing literal coverage
// remains intact. Only discard a candidate when that literal is translated.
const textLiteral = /Text\(\s*'[A-Za-z][^'$]{3,}'/g;
const translatedCall = /^\s*\.tr\s*\(/;

export function findHardCodedText(source) {
  const matches = [];
  for (const match of source.matchAll(textLiteral)) {
    if (!translatedCall.test(source.slice(match.index + match[0].length))) {
      matches.push({ index: match.index, text: match[0] });
    }
  }
  return matches;
}
