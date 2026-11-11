# Puts the Lantern and Arch strings into the two catalogs.
#
# The strings live in brief/tools/lantern_i18n/*.json, one file per area, so
# two people can add strings at the same time without editing the same file.
# Each file is {"en": {...}, "ar": {...}}; the trees are merged and written as
# the top-level "lantern" key of project/assets/i18n/en.json and ar.json. The
# rest of each catalog is kept byte for byte.
#
# Fails when the two languages do not have the same keys, when two files
# define the same key, or when a placeholder count differs between languages.
#
# Run from the repository root: python brief/tools/merge_lantern_i18n.py
import glob
import json
import re
import sys

PARTS = 'brief/tools/lantern_i18n/*.json'
CATALOG = 'project/assets/i18n/%s.json'
MARK = '\n  "lantern": {'


def merge(into, extra, path, source):
    for key, value in extra.items():
        here = f'{path}.{key}'
        if isinstance(value, dict):
            node = into.setdefault(key, {})
            if not isinstance(node, dict):
                sys.exit(f'{source}: {here} is text in another file')
            merge(node, value, here, source)
        elif key in into:
            sys.exit(f'{source}: {here} is defined twice')
        else:
            into[key] = value


def leaves(tree, path=''):
    for key, value in tree.items():
        here = f'{path}.{key}' if path else key
        if isinstance(value, dict):
            yield from leaves(value, here)
        else:
            yield here, value


trees = {'en': {}, 'ar': {}}
for name in sorted(glob.glob(PARTS)):
    part = json.load(open(name, encoding='utf-8'))
    for lang in trees:
        if lang not in part:
            sys.exit(f'{name}: no "{lang}" block')
        merge(trees[lang], part[lang], 'lantern', name)

en, ar = dict(leaves(trees['en'])), dict(leaves(trees['ar']))
problems = [f'only in en: lantern.{k}' for k in en.keys() - ar.keys()]
problems += [f'only in ar: lantern.{k}' for k in ar.keys() - en.keys()]
for key in en.keys() & ar.keys():
    if not isinstance(en[key], str) or not isinstance(ar[key], str):
        problems.append(f'not text: lantern.{key}')
    elif len(re.findall(r'\{\}', en[key])) != len(re.findall(r'\{\}', ar[key])):
        problems.append(f'placeholder count differs: lantern.{key}')
if problems:
    sys.exit('\n'.join(sorted(problems)))

for lang, tree in trees.items():
    path = CATALOG % lang
    raw = open(path, encoding='utf-8', newline='').read()
    nl = '\r\n' if '\r\n' in raw else '\n'
    text = raw.replace('\r\n', '\n').rstrip()
    if not text.endswith('}'):
        sys.exit(f'{path}: does not end with a closing brace')
    body = text[:-1].rstrip()
    at = body.find(MARK)
    if at >= 0:
        # "lantern" is always the last key, so it runs to the end.
        body = body[:at].rstrip().rstrip(',')
    block = json.dumps(tree, ensure_ascii=False, indent=2).replace('\n', '\n  ')
    out = f'{body},\n  "lantern": {block}\n}}\n'
    json.loads(out)
    open(path, 'w', encoding='utf-8', newline='').write(out.replace('\n', nl))

print(f'lantern strings: {len(en)} keys in each language')
