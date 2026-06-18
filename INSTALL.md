# 🤖 LLM Agent Setup Prompt

Copy-paste the prompt below into any AI agent (Claude, ChatGPT, Hermes, Gemini) to automatically set up Chainproof:

---

I want to set up the Chainproof supply chain security toolkit from https://github.com/onurege3467/chainproof

1. Clone: `git clone https://github.com/onurege3467/chainproof.git && cd chainproof`
2. Make scripts executable: `chmod +x scripts/*.sh`
3. Verify a repo: `bash scripts/verify-repo.sh owner/repo-name`
4. Run a full audit: `bash scripts/full-audit.sh /path/to/project`
5. Open README.md for the full handbook

---

## What this does

- Clones the Chainproof repository
- Makes the verification and audit scripts executable
- Lets you immediately verify any GitHub repo for suspicious patterns
- Gives you the complete supply chain security handbook as README.md

## Prerequisites

- `curl` — for fetching repo data via GitHub API
- `jq` — for parsing JSON (install: `apt install jq` / `brew install jq`)

## Files

| File | Description |
|------|-------------|
| `README.md` | Full supply chain security handbook |
| `scripts/verify-repo.sh` | Vets a GitHub repo for suspicious patterns |
| `scripts/full-audit.sh` | Runs all security checks on a project |
| `configs/.gitconfig.safe` | Recommended git configuration |
| `LICENSE` | MIT License |
