#!/usr/bin/env bash
# ============================================================================
# full-audit.sh — Project Security Audit Runner
# ============================================================================
# Usage: bash full-audit.sh /path/to/project
# Scans project dependencies, secrets, git config, and generates a report.
# ============================================================================
set -euo pipefail

TARGET="${1:-.}"
REPORT="security-audit-$(date +%Y%m%d-%H%M%S).md"

if [ ! -d "$TARGET" ]; then
  echo "Error: Directory '$TARGET' does not exist"
  exit 1
fi

cd "$TARGET"

echo "🔐 Chainproof Security Audit"
echo "Target: $(pwd)"
echo "Report: $REPORT"
echo ""

# ── Initialize report ────────────────────────────────────────────────────────
cat > "$REPORT" << EOF
# Security Audit Report

**Target:** $(pwd)
**Date:** $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

EOF

# ── Check 1: Git configuration ───────────────────────────────────────────────
echo "📋 [1/6] Checking git configuration..."
{
  echo "## Git Configuration"
  echo ""
  echo '```'
  git config --list 2>/dev/null || echo "Not a git repository"
  echo '```'
  echo ""

  # Check commit signing
  if git config --global commit.gpgsign 2>/dev/null | grep -q true; then
    echo "✅ Commit signing is enabled"
  else
    echo "❌ Commit signing is NOT enabled globally"
  fi

  if git config --global user.signingkey 2>/dev/null | grep -q .; then
    echo "✅ Signing key is configured"
  else
    echo "❌ No signing key found"
  fi
  echo ""
} >> "$REPORT"

# ── Check 2: Python dependencies ─────────────────────────────────────────────
echo "📋 [2/6] Python dependencies..."
{
  echo "## Python Dependencies"
  echo ""
} >> "$REPORT"

if [ -f "requirements.txt" ]; then
  if command -v pip-audit &>/dev/null; then
    echo "Running pip-audit..."
    pip-audit -r requirements.txt >> "$REPORT" 2>&1 || true
  else
    echo "pip-audit not installed. Install: pip install pip-audit" >> "$REPORT"
    echo "" >> "$REPORT"
    echo "Dependencies found in requirements.txt:" >> "$REPORT"
    echo '```' >> "$REPORT"
    cat requirements.txt >> "$REPORT"
    echo '```' >> "$REPORT"
  fi
fi

if [ -f "Pipfile" ]; then
  echo "Pipfile found — run 'pipenv check' manually" >> "$REPORT"
fi

echo "" >> "$REPORT"

# ── Check 3: Node.js dependencies ────────────────────────────────────────────
echo "📋 [3/6] Node.js dependencies..."
{
  echo "## Node.js Dependencies"
  echo ""
} >> "$REPORT"

if [ -f "package.json" ]; then
  if command -v npm &>/dev/null; then
    echo "Running npm audit..." >> "$REPORT"
    echo '```' >> "$REPORT"
    npm audit --audit-level=moderate 2>/dev/null >> "$REPORT" || echo "npm audit completed with warnings" >> "$REPORT"
    echo '```' >> "$REPORT"
  else
    echo "npm not installed" >> "$REPORT"
  fi
  echo "" >> "$REPORT"
fi

# ── Check 4: Rust dependencies ───────────────────────────────────────────────
echo "📋 [4/6] Rust dependencies..."
{
  echo "## Rust Dependencies"
  echo ""
} >> "$REPORT"

if [ -f "Cargo.toml" ] || [ -f "Cargo.lock" ]; then
  if command -v cargo-audit &>/dev/null; then
    echo "Running cargo audit..." >> "$REPORT"
    echo '```' >> "$REPORT"
    cargo audit 2>/dev/null >> "$REPORT" || true
    echo '```' >> "$REPORT"
  else
    echo "cargo-audit not installed. Install: cargo install cargo-audit" >> "$REPORT"
  fi
  echo "" >> "$REPORT"
fi

# ── Check 5: Go dependencies ─────────────────────────────────────────────────
echo "📋 [5/6] Go dependencies..."
{
  echo "## Go Dependencies"
  echo ""
} >> "$REPORT"

if [ -f "go.mod" ] || [ -f "go.sum" ]; then
  if command -v govulncheck &>/dev/null; then
    echo "Running govulncheck..." >> "$REPORT"
    echo '```' >> "$REPORT"
    govulncheck ./... 2>/dev/null >> "$REPORT" || true
    echo '```' >> "$REPORT"
  else
    echo "govulncheck not installed. Install: go install golang.org/x/vuln/cmd/govulncheck@latest" >> "$REPORT"
  fi
  echo "" >> "$REPORT"
fi

# ── Check 6: Secrets and sensitive files ──────────────────────────────────────
echo "📋 [6/6] Secrets and sensitive file scan..."
{
  echo "## Secrets & Sensitive Files"
  echo ""
} >> "$REPORT"

# Check for common secret files
SECRET_PATTERNS=("*.pem" "*.key" "id_rsa" "id_dsa" ".env" ".env.*" "credentials" "secrets.yml" "*.cred")
FOUND_SECRETS=0
for pattern in "${SECRET_PATTERNS[@]}"; do
  while IFS= read -r -d '' file; do
    # Skip .git directory
    if echo "$file" | grep -q "^\.git" || echo "$file" | grep -q "/\.git/"; then
      continue
    fi
    echo "⚠️  Possible secret file: $file" >> "$REPORT"
    FOUND_SECRETS=$((FOUND_SECRETS + 1))
  done < <(find . -name "$pattern" -not -path './.git/*' -print0 2>/dev/null || true)
done

if [ "$FOUND_SECRETS" -eq 0 ]; then
  echo "✅ No obvious secret files found" >> "$REPORT"
fi

# Check for potential secrets in staged/pre-committed files
if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
  echo "" >> "$REPORT"
  echo "### Git Staged Files" >> "$REPORT"
  echo '```' >> "$REPORT"
  git diff --cached --name-only 2>/dev/null >> "$REPORT" || echo "(no staged changes)" >> "$REPORT"
  echo '```' >> "$REPORT"
fi

echo "" >> "$REPORT"

# ── Summary ───────────────────────────────────────────────────────────────────
{
  echo "---"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Check | Status |"
  echo "|-------|--------|"
  git_ok="✅"
  git config --global commit.gpgsign 2>/dev/null | grep -q true || git_ok="❌"
  echo "| Git signing | $git_ok |"
  [ -f "requirements.txt" ] && dep_py="📦 Found" || dep_py="—"
  echo "| Python deps | $dep_py |"
  [ -f "package.json" ] && dep_js="📦 Found" || dep_js="—"
  echo "| Node.js deps | $dep_js |"
  [ -f "Cargo.toml" ] && dep_rs="📦 Found" || dep_rs="—"
  echo "| Rust deps | $dep_rs |"
  [ -f "go.mod" ] && dep_go="📦 Found" || dep_go="—"
  echo "| Go deps | $dep_go |"
  echo "| Secrets found | $FOUND_SECRETS |"
  echo ""
  echo "---"
  echo "_Generated by Chainproof — supply chain security toolkit_"
} >> "$REPORT"

echo ""
echo "✅ Audit complete! Report saved to: $REPORT"
echo ""
head -5 "$REPORT"
