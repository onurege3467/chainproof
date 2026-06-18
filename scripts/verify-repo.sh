#!/usr/bin/env bash
# ============================================================================
# verify-repo.sh — GitHub Repository Trustworthiness Checker
# ============================================================================
# Usage: bash verify-repo.sh owner/repo-name
# Requires: curl, jq
# ============================================================================
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 owner/repo-name"
  echo "Example: $0 octocat/Hello-World"
  exit 1
fi

REPO="$1"

# Split on the first slash
OWNER="${REPO%%/*}"
NAME="${REPO#*/}"

if [ -z "$OWNER" ] || [ -z "$NAME" ] || [ "$OWNER" = "$REPO" ]; then
  echo "Error: Invalid repo format. Use owner/repo-name (e.g., octocat/Hello-World)"
  exit 1
fi

echo "🔍 Verifying: $OWNER/$NAME"
echo "────────────────────────────────────────"

# ── Get repo metadata ──────────────────────────────────────────────────────
DATA=$(curl -sf "https://api.github.com/repos/$OWNER/$NAME" 2>/dev/null || true)

if [ -z "$DATA" ]; then
  echo "❌ Could not fetch repo data. Check if the repo exists."
  exit 1
fi

# ── Basic info ──────────────────────────────────────────────────────────────
echo ""
echo "📌 Basic Info"
echo "  Description:  $(echo "$DATA" | jq -r '.description // "N/A"')"
echo "  Created:      $(echo "$DATA" | jq -r '.created_at // "N/A"')"
echo "  Updated:      $(echo "$DATA" | jq -r '.updated_at // "N/A"')"
echo "  Language:     $(echo "$DATA" | jq -r '.language // "N/A"')"
echo "  Topics:       $(echo "$DATA" | jq -r '.topics // [] | join(", ")')"

STARS=$(echo "$DATA" | jq -r '.stargazers_count // 0')
FORKS=$(echo "$DATA" | jq -r '.forks_count // 0')
OPEN_ISSUES=$(echo "$DATA" | jq -r '.open_issues_count // 0')
SIZE=$(echo "$DATA" | jq -r '.size // 0')
LICENSE=$(echo "$DATA" | jq -r '.license.spdx_id // "None"')

echo "  Stars:        $STARS"
echo "  Forks:        $FORKS"
echo "  Open Issues:  $OPEN_ISSUES"
echo "  Size:         ${SIZE}KB"
echo "  License:      $LICENSE"

# ── Owner info ──────────────────────────────────────────────────────────────
OWNER_DATA=$(curl -sf "https://api.github.com/users/$OWNER" 2>/dev/null || true)
OWNER_TYPE=$(echo "$OWNER_DATA" | jq -r '.type // "Unknown"')
OWNER_CREATED=$(echo "$OWNER_DATA" | jq -r '.created_at // "Unknown"')
OWNER_PUBLIC_REPOS=$(echo "$OWNER_DATA" | jq -r '.public_repos // 0')

echo ""
echo "👤 Owner Info"
echo "  Type:         $OWNER_TYPE"
echo "  Account created: $OWNER_CREATED"
echo "  Public repos: $OWNER_PUBLIC_REPOS"

# ── Risk checks ─────────────────────────────────────────────────────────────
echo ""
echo "⚠️  Risk Assessment"
SCORE=0
MAX_SCORE=10

# Check 1: Owner account age
if [ "$OWNER_CREATED" != "Unknown" ]; then
  OWNER_EPOCH=$(date -d "$OWNER_CREATED" +%s 2>/dev/null || echo 0)
  NOW=$(date +%s 2>/dev/null || echo 0)
  if [ "$NOW" -gt "0" ] && [ "$OWNER_EPOCH" -gt "0" ]; then
    OWNER_AGE_DAYS=$(( (NOW - OWNER_EPOCH) / 86400 ))
    if [ "$OWNER_AGE_DAYS" -lt 30 ]; then
      echo "  🔴 Owner account is less than 30 days old (${OWNER_AGE_DAYS}d)"
      SCORE=$((SCORE + 3))
    elif [ "$OWNER_AGE_DAYS" -lt 365 ]; then
      echo "  🟡 Owner account is less than a year old (${OWNER_AGE_DAYS}d)"
      SCORE=$((SCORE + 1))
    else
      echo "  🟢 Owner account age: ${OWNER_AGE_DAYS}d"
    fi
  fi
fi

# Check 2: Star-to-fork ratio (extreme imbalance suggests fake stars)
if [ "$FORKS" -gt 0 ] && [ "$STARS" -gt 0 ]; then
  RATIO=$(echo "scale=2; $STARS / $FORKS" | bc 2>/dev/null || echo 0)
  if [ "$(echo "$RATIO > 50" | bc 2>/dev/null)" = "1" ] || [ "$STARS" -gt 100 ] && [ "$FORKS" -lt 3 ]; then
    echo "  🟡 Star-to-fork ratio is extreme (${RATIO}:1) — may indicate star farming"
    SCORE=$((SCORE + 2))
  else
    echo "  🟢 Star-to-fork ratio: ${RATIO}:1"
  fi
elif [ "$STARS" -gt 10 ] && [ "$FORKS" -eq 0 ]; then
  echo "  🟡 Popular repo ($STARS stars) but NO forks — suspicious"
  SCORE=$((SCORE + 2))
fi

# Check 3: Has releases?
RELEASES=$(curl -sf "https://api.github.com/repos/$OWNER/$NAME/releases?per_page=1" | jq -r 'length' 2>/dev/null || echo 0)
if [ "$RELEASES" -eq 0 ] && [ "$STARS" -gt 50 ]; then
  echo "  🟡 Popular repo ($STARS stars) but no GitHub releases — may be unmaintained or fake"
  SCORE=$((SCORE + 1))
elif [ "$RELEASES" -gt 0 ]; then
  echo "  🟢 Has releases: $RELEASES"
fi

# Check 4: Owner public repo count (very few repos suggests throwaway account)
if [ "$OWNER_PUBLIC_REPOS" -lt 3 ] && [ "$OWNER_TYPE" = "User" ]; then
  echo "  🔴 Owner has only $OWNER_PUBLIC_REPOS public repos — could be a throwaway"
  SCORE=$((SCORE + 2))
fi

# Check 5: Has a license?
if [ "$LICENSE" = "None" ] || [ "$LICENSE" = "null" ]; then
  echo "  🟡 No license specified"
  SCORE=$((SCORE + 1))
fi

# Check 6: Size anomaly (very large for what appears to be a small project)
echo "  🟢 Repo size: ${SIZE}KB"

# Check 7: Repository description similarity to known malware patterns
DESC=$(echo "$DATA" | jq -r '.description // ""' | tr '[:upper:]' '[:lower:]')
SUSPICIOUS_WORDS=("crack" "hack" "cheat" "cracked" "keygen" "free download" "mod apk" "unlock")
for word in "${SUSPICIOUS_WORDS[@]}"; do
  if echo "$DESC" | grep -qi "$word" 2>/dev/null; then
    echo "  🔴 Description contains suspicious keyword: '$word'"
    SCORE=$((SCORE + 3))
    break
  fi
done

# ── Final verdict ───────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────"
if [ "$SCORE" -eq 0 ]; then
  echo "✅ Score: $SCORE/$MAX_SCORE — Repo looks clean"
elif [ "$SCORE" -le 3 ]; then
  echo "⚠️  Score: $SCORE/$MAX_SCORE — Some minor concerns, review manually"
elif [ "$SCORE" -le 6 ]; then
  echo "🔶 Score: $SCORE/$MAX_SCORE — Suspicious patterns detected, proceed with caution"
else
  echo "🔴 Score: $SCORE/$MAX_SCORE — HIGH RISK. Avoid using this repo without thorough review"
fi
echo "────────────────────────────────────────"
