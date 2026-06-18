# 🛡️ Chainproof

> A practical developer's handbook for software supply chain security.

[![MIT License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell Script](https://img.shields.io/badge/Language-Shell-89e051.svg?logo=gnu-bash&logoColor=white)](scripts/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Chainproof** is a curated collection of scripts, configurations, and guides that help developers verify, harden, and audit their software supply chain — protecting against the kind of attacks where malware is hidden in seemingly legitimate GitHub repositories.

Built in response to [the HN story](https://news.ycombinator.com/item?id=41839567) about 10,000+ GitHub repositories distributing trojan malware. Chainproof gives you practical, copy-pasteable defenses.

---

## 🔥 Quick Start

```bash
# Check if a GitHub repo looks suspicious (fake stars, recent account, no releases)
bash <(curl -s https://raw.githubusercontent.com/onurege3467/chainproof/main/scripts/verify-repo.sh) owner/repo-name
```

---

## 📋 Contents

| Section | What You'll Get |
|---------|----------------|
| [📦 Dependency Auditing](#-dependency-auditing) | Audit npm, pip, cargo, go mod for known vulnerabilities and typosquatting |
| [🔑 Commit Signing](#-commit-signing) | Set up GPG/SSH commit signing in 5 minutes |
| [📄 SBOM Generation](#-sbom-generation) | Generate CycloneDX SPDX SBOMs for any project |
| [🏷️ SLSA Provenance](#-slsa-provenance) | Generate and verify build provenance |
| [🔁 CI/CD Security](#-cicd-security) | Harden GitHub Actions, GitLab CI |
| [🔍 Repo Verification](#-repo-verification) | Scripts to vet GitHub repos before trusting them |
| [⚙️ Configurations](#-configurations) | Ready-to-use secure configs for git, renovate |

---

## 📦 Dependency Auditing

### Python (pip/poetry)

```bash
# Audit installed packages
pip install pip-audit && pip-audit

# Check requirements.txt
pip-audit -r requirements.txt
```

### Node.js (npm/yarn/pnpm)

```bash
# npm built-in audit
npm audit

# Check for typosquatting
npx typo-scan ./package.json
```

### Rust (cargo)

```bash
cargo install cargo-audit && cargo audit
```

### Go

```bash
go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...
```

---

## 🔑 Commit Signing

### GPG signing

```bash
# Generate a GPG key (use your GitHub email)
gpg --full-generate-key

# List keys and get the ID
gpg --list-secret-keys --keyid-format LONG

# Configure git
git config --global user.signingkey KEY_ID
git config --global commit.gpgsign true
git config --global tag.gpgsign true

# Export public key — add to GitHub Settings → SSH and GPG keys
gpg --armor --export KEY_ID
```

### SSH signing (simpler)

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

---

## 📄 SBOM Generation

```bash
# Python
pip install cyclonedx-bom && cyclonedx-py -i requirements.txt -o bom.xml

# Node.js
npx @cyclonedx/bom . -o bom.json
```

---

## 🏷️ SLSA Provenance

Add to `.github/workflows/release.yml`:

```yaml
jobs:
  build:
    permissions:
      id-token: write
      contents: read
    uses: slsa-framework/slsa-github-generator/.github/workflows/builder_go_slsa3.yml@v2.0.0
```

Verify:

```bash
go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@v2.6.0
slsa-verifier verify-artifact \
  --provenance-path artifact.intoto.jsonl \
  --source-uri github.com/owner/repo \
  artifact.tar.gz
```

---

## 🔁 CI/CD Security

**Pin actions by commit SHA instead of tags:**

```yaml
- uses: actions/checkout@8937d34f8c3ebc58e8c2c2eb6a9eb7db0d24b939
```

**Limit workflow permissions:**

```yaml
permissions:
  contents: read
  issues: none
```

**Prevent dependency confusion — pin registries:**

```bash
# npm
echo "registry=https://registry.npmjs.org/" >> .npmrc

# pip
echo -e "[global]\nindex-url = https://pypi.org/simple/" >> pip.conf
```

---

## 🔍 Repo Verification

### Why this matters

Attackers create repos with fake stars and high activity, then inject malicious code in dependencies or build scripts. The HN story today showed 10,000+ repos doing exactly this.

### Use the verification script

```bash
bash <(curl -s https://raw.githubusercontent.com/onurege3467/chainproof/main/scripts/verify-repo.sh) owner/repo
```

### Manual checklist

Before using any GitHub repo:

- [ ] Check account creation date (is it < 30 days old?)
- [ ] Look at commit history — are commits rushed or automated?
- [ ] Verify releases have signed tags
- [ ] Check `package.json`/`requirements.txt` for typosquatted deps
- [ ] Scan the repo with `trivy` or `semgrep`
- [ ] Verify the author has a history of legitimate projects
- [ ] Check if the repo is a fork with unexplained changes
- [ ] Look for suspicious binaries or encoded scripts

---

## ⚙️ Configurations

### Secure git config

```ini
[commit]
  gpgsign = true
[tag]
  gpgsign = true
[core]
  fsyncObjectFiles = true
```

### Renovate config

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "vulnerabilityAlerts": { "enabled": true },
  "osvVulnerabilityAlerts": true
}
```

---

## 📚 Resources

- [OpenSSF Scorecard](https://scorecard.dev/)
- [SLSA Framework](https://slsa.dev/)
- [Socket.dev](https://socket.dev/)
- [Trivy](https://trivy.dev/)
- [CISA Supply Chain Security](https://www.cisa.gov/supply-chain-security)

---

## 🤝 Contributing

PRs welcome! See [CONTRIBUTING.md](CONTRIBUTING.md). If you know a useful command or tool for supply chain security — add it.

---

## ⚖️ License

MIT — see [LICENSE](LICENSE).

*Don't trust blindly — chainproof your workflow.*
