# Model Advisor & Token Optimization
Experimental advisory module. Configure policy in config.json (BALANCED default; ECO, PERFORMANCE, DISABLED). The Python function advise accepts task {level, critical, capabilities}, current and candidate configurations {assistant, name, effort, available, capacity, cost, capabilities, fits}, plus reviewed ISO date. Capacity and cost are user/environment calibrated ordinal estimates, not official prices. Supply the same scale for all candidates; do not infer availability from the catalog. A pause decision means do not execute the main task until user confirmation. Use override for the same task only; reset on changed scope.

## Compatibility
Codex, Hermes and Antigravity: selectable portable skill via Setup -Components ModelAdvisor. For Claude Code, Copilot, Gemini CLI use the native persistent instructions to refer to SKILL.md and its adjacent files; for ChatGPT, Claude and Gemini chat, attach the relevant files or use project instructions. Ollama is a runtime, not an assistant; install instructions in the actual host. Automatic preflight cannot be guaranteed on any host by a skill alone. No automatic model switching. No live inventory detection yet.

## Catalog maintenance
Review the official source and actual picker; update only the corresponding JSON file and reviewed date after validation. Unknown costs remain null. Catalog entries are reference names, not guaranteed selectable IDs. Ollama source review is pending. Reuse existing efficiency and security gates. Test with python -m unittest discover -s skills/sabas-model-advisor/tests. No measured token savings yet.

## Example
A confirmed expensive model doing level-1 documentation may return pause with a cheaper compatible configuration; an unknown model returns uncertain. Critical work requires at least level 4 regardless of policy. An opt-out never bypasses security gates.
