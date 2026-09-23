const privateKeyHeader = /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g;
// A PEM header in prose is not key material. Keep flagging incomplete keys
// when a base64 body follows, including strings with escaped newlines.
const bodyAfterHeader = /^(?:\r?\n|\\n)[ \t]*[A-Za-z0-9+/=]{32,}(?:\r?\n|\\n|$)/;

export function countPrivateKeyMaterial(source) {
  let count = 0;
  for (const match of source.matchAll(privateKeyHeader)) {
    if (bodyAfterHeader.test(source.slice(match.index + match[0].length))) count++;
  }
  return count;
}
