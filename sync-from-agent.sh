#!/usr/bin/env bash
# Sync provider configs from the local helios-agent settings.json
set -euo pipefail

AGENT_SETTINGS="$HOME/.pi/agent/settings.json"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$AGENT_SETTINGS" ]]; then
  echo "Error: $AGENT_SETTINGS not found"
  exit 1
fi

echo "Syncing packages and skills from helios-agent..."

for config in "$INSTALLER_DIR"/provider-configs/*.json; do
  python3 -c "
import json, sys
with open('$config') as f: cfg = json.load(f)
with open('$AGENT_SETTINGS') as f: agent = json.load(f)
cfg['packages'] = agent.get('packages', cfg.get('packages', []))
cfg['skills'] = agent.get('skills', cfg.get('skills', []))
# Also sync enabledModels if the provider matches
agent_provider = agent.get('defaultProvider', '')
cfg_provider = cfg.get('defaultProvider', '')
if agent_provider == cfg_provider and 'enabledModels' in agent:
    cfg['enabledModels'] = agent['enabledModels']
with open('$config', 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
print(f'  \u2713 Updated: $(basename $config)')
"
done

echo ""
echo "Done. Review changes with: cd $INSTALLER_DIR && git diff"
echo "Then commit: git add -A && git commit -m 'chore: sync from helios-agent' && git push"
