---
name: jpi-dev
description: How to develop and test J-PI. Load agent.ijs in jconsole from the src directory. Use /model to switch providers. Use /skills and /plugins to inspect loaded components.
---
# J-PI Development

## Loading jpi for testing
From the src directory:
```
load 'agent.ijs'
```

## Key commands
- /model - list or switch models
- /skills - list available Agent Skills
- /plugins - list loaded Agent Plugins
- /less - open output in pager
- /nvim - compose prompt in nvim

## Architecture
agent.ijs dispatches to action verbs. llm.ijs handles provider calls.
config.ijs manages providers and API keys.
