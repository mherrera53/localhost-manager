#!/bin/bash
# ============================================
# Import existing environments (macOS / Linux)
# Localhost Manager
# ============================================
# Reads Apache virtual hosts from already-configured local stacks
# (MAMP, MAMP PRO, XAMPP) and imports them into the manager's hosts.json.
# All of these use standard Apache <VirtualHost> blocks, so one parser
# handles them all -- only the file locations differ.
#
# Usage:
#   bash import-environments.sh            # import (writes hosts.json, backs up)
#   bash import-environments.sh --dry-run  # preview only, no changes

set -e

DRY_RUN=0
[ "$1" = "--dry-run" ] && DRY_RUN=1

MANAGER_DIR="$HOME/localhost-manager"
HOSTS_JSON="$MANAGER_DIR/conf/hosts.json"

# Candidate vhost sources: "Label|path"
CANDIDATES=(
  "MAMP|/Applications/MAMP/conf/apache/extra/httpd-vhosts.conf"
  "MAMP PRO|/Library/Application Support/appsolute/MAMP PRO/conf/httpd.conf"
  "XAMPP|/Applications/XAMPP/etc/extra/httpd-vhosts.conf"
  "XAMPP|/Applications/XAMPP/xamppfiles/etc/extra/httpd-vhosts.conf"
  "Apache|/etc/apache2/extra/httpd-vhosts.conf"
  "Apache|/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf"
)

SOURCES=""
for c in "${CANDIDATES[@]}"; do
  label="${c%%|*}"; path="${c#*|}"
  if [ -f "$path" ]; then
    echo "Found: $label -> $path"
    SOURCES="${SOURCES}${label}|${path}"$'\n'
  fi
done

# Laragon-style one-file-per-site dirs (rare on macOS but supported)
for dir in "$HOME"/laragon/etc/apache2/sites-enabled /opt/laragon/etc/apache2/sites-enabled; do
  if [ -d "$dir" ]; then
    for f in "$dir"/*.conf; do
      [ -f "$f" ] && SOURCES="${SOURCES}Laragon|${f}"$'\n'
    done
  fi
done

if [ -z "$SOURCES" ]; then
  echo "No MAMP / MAMP PRO / XAMPP / Laragon virtual host files found."
  echo "Nothing to import."
  exit 0
fi

DRY_RUN="$DRY_RUN" HOSTS_JSON="$HOSTS_JSON" SOURCES="$SOURCES" python3 <<'PYEOF'
import os, re, json, uuid, shutil

hosts_json = os.environ['HOSTS_JSON']
dry = os.environ.get('DRY_RUN') == '1'
sources = [l for l in os.environ['SOURCES'].splitlines() if l.strip()]

SKIP_NAMES = {'___default___', '_default_', 'default'}

def parse_vhosts(path):
    try:
        text = open(path, 'r', errors='ignore').read()
    except OSError:
        return {}
    out = {}
    for m in re.finditer(r'<VirtualHost\s+([^>]*)>(.*?)</VirtualHost>', text, re.S | re.I):
        addr, body = m.group(1), m.group(2)
        pm = re.search(r':(\d+)', addr)
        port = int(pm.group(1)) if pm else None
        sn = re.search(r'^\s*ServerName\s+(\S+)', body, re.M | re.I)
        if not sn:
            continue
        domain = sn.group(1).strip()
        if domain in SKIP_NAMES:
            continue
        aliases = []
        for am in re.finditer(r'^\s*ServerAlias\s+(.+)$', body, re.M | re.I):
            for a in am.group(1).split():
                a = a.strip()
                if a and a not in SKIP_NAMES:
                    aliases.append(a)
        dr = re.search(r'^\s*DocumentRoot\s+"?([^"\n]+?)"?\s*$', body, re.M | re.I)
        docroot = dr.group(1).strip() if dr else None
        ssl = (port == 443) or bool(re.search(r'^\s*SSLEngine\s+on', body, re.M | re.I))
        e = out.setdefault(domain, {'docroot': None, 'aliases': set(), 'ssl': False})
        if docroot:
            e['docroot'] = docroot
        e['aliases'].update(aliases)
        if ssl:
            e['ssl'] = True
    return out

merged = {}
for line in sources:
    label, path = line.split('|', 1)
    for domain, e in parse_vhosts(path).items():
        if domain not in merged:
            merged[domain] = {'docroot': e['docroot'], 'aliases': set(e['aliases']),
                              'ssl': e['ssl'], 'group': 'Imported (%s)' % label}
        else:
            merged[domain]['aliases'].update(e['aliases'])
            if e['docroot'] and not merged[domain]['docroot']:
                merged[domain]['docroot'] = e['docroot']
            merged[domain]['ssl'] = merged[domain]['ssl'] or e['ssl']

try:
    existing = json.load(open(hosts_json))
except Exception:
    existing = {}

added, skipped, nodoc = [], [], []
for domain, e in merged.items():
    if not e.get('docroot'):
        nodoc.append(domain)
        continue
    if domain in existing:
        skipped.append(domain)
        continue
    existing[domain] = {
        'domain': domain,
        'docroot': e['docroot'],
        'aliases': [{'id': 'alias_' + uuid.uuid4().hex[:9], 'value': a, 'active': True}
                    for a in sorted(e['aliases'])],
        'group': e['group'],
        'active': False,
        'ssl': bool(e['ssl']),
        'type': 'php',
        'stack': 'frontend',
        'php_version': None,
        'port': None,
        'mode': 'local',
    }
    added.append(domain)

print("")
print("Import summary: %d new, %d already present, %d skipped (no DocumentRoot)" %
      (len(added), len(skipped), len(nodoc)))
for d in added:
    print("  + %-40s -> %s" % (d, existing[d]['docroot']))
for d in skipped:
    print("  = %s (already in manager)" % d)

if dry:
    print("\n[dry-run] No changes written. Re-run without --dry-run to apply.")
elif added:
    os.makedirs(os.path.dirname(hosts_json), exist_ok=True)
    if os.path.exists(hosts_json):
        shutil.copy(hosts_json, hosts_json + '.bak')
    with open(hosts_json, 'w') as fh:
        json.dump(existing, fh, indent=2, ensure_ascii=False)
    print("\n[OK] Wrote %d new host(s) to %s (backup: hosts.json.bak)" % (len(added), hosts_json))
    print("     Imported hosts are INACTIVE. Activate them in the app, then 'Apply'.")
else:
    print("\nNothing new to import.")
PYEOF
