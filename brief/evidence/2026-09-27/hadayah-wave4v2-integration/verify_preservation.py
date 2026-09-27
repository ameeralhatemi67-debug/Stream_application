"""Read-only comparison of protected owner/source files, refs and stashes."""
import hashlib, json, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path
root = Path(__file__).resolve().parent
baseline = json.loads((root / 'PRESERVATION_BASELINE.json').read_text(encoding='utf-8-sig'))
def git(repo, *args):
    return subprocess.check_output(['git', '-C', repo, *args]).decode('utf-8').splitlines()
concurrent = json.loads((root / 'CONCURRENT_OWNER_BASELINE.json').read_text(encoding='utf-8'))
checks = []
for repo in baseline['repositories']:
    changed = []
    for entry in repo['files']:
        if Path(entry['path']).name == 'dart_define.local.json':
            raise RuntimeError('Forbidden configuration must never enter preservation reads')
        file = Path(repo['root']) / entry['path']
        if not file.is_file(): changed.append({'path':entry['path'], 'state':'missing'}); continue
        digest = hashlib.file_digest(file.open('rb'), 'sha256').hexdigest().upper()
        if digest != entry['sha256'].upper(): changed.append({'path':entry['path'], 'state':'changed'})
    status = git(repo['root'], 'status', '--porcelain=v1', '--untracked-files=all')
    checks.append({'root':repo['root'], 'filesChecked':len(repo['files']), 'changed':changed,
        'headUnchanged':git(repo['root'], 'rev-parse', 'HEAD')[0] == repo['head'],
        'statusUnchanged':sorted(status) == sorted(repo['status'])})
main = baseline['repositories'][0]['root']
branches = git(main, 'for-each-ref', '--format=%(refname) %(objectname)', 'refs/heads')
protected = [b for b in baseline['branches'] if not b.startswith('refs/heads/codex/hadayah-wave4v2-integration ')]
stashes = git(main, 'stash', 'list', '--format=%gd %H %gs')
# Promotion cannot overwrite protected owner edits that overlap incoming docs.
incoming = set(git(str(root.parents[3]), 'diff', '--name-only', 'master..HEAD'))
incoming.update(git(str(root.parents[3]), 'diff', '--name-only', 'HEAD'))
dirty = {line[3:] for line in baseline['repositories'][0]['status'] if not line.startswith('??')}
out = {'checkedAt':datetime.now(timezone.utc).isoformat(), 'repositories':checks,
       'protectedBranchesUnchanged':all(b in branches for b in protected),
       'stashesUnchanged':stashes == baseline['stashes'], 'stashIdentities':stashes,
       'localMaster':git(main,'rev-parse','master')[0],
       'promotionOverlaps':sorted(incoming & dirty),
       'integrationCommit':git(str(root.parents[3]),'rev-parse','HEAD')[0]}
out['matchesOriginalBaseline'] = all(not r['changed'] and r['headUnchanged'] and r['statusUnchanged'] for r in checks) and out['protectedBranchesUnchanged'] and out['stashesUnchanged']
concurrentHashes = {f['path']:f['sha256'] for f in concurrent['files']}
currentMain = baseline['repositories'][0]['root']
concurrentUnchanged = all(hashlib.file_digest((Path(currentMain)/p).open('rb'),'sha256').hexdigest().upper()==h for p,h in concurrentHashes.items())
accounted = all(entry['path'] in concurrentHashes for entry in checks[0]['changed'])
currentStatusMatches = git(currentMain,'status','--porcelain=v1','--untracked-files=all') == concurrent['status']
out['concurrentOwnerWorkUnchangedSinceObserved'] = concurrentUnchanged and currentStatusMatches
out['originalDifferencesAccountedFor'] = accounted
out['pass'] = accounted and out['concurrentOwnerWorkUnchangedSinceObserved'] and checks[0]['headUnchanged'] and all(not r['changed'] and r['headUnchanged'] and r['statusUnchanged'] for r in checks[1:]) and out['protectedBranchesUnchanged'] and out['stashesUnchanged']
destination = Path(sys.argv[1]) if len(sys.argv) > 1 else root / 'PRESERVATION_CHECK.json'
destination.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'pass':out['pass'],'protectedFiles':sum(r['filesChecked'] for r in checks),'promotionOverlaps':out['promotionOverlaps']}))
raise SystemExit(0 if out['pass'] else 1)
