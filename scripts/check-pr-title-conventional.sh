#!/usr/bin/env bash
set -euo pipefail

title="$1"

regex='^(build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(\([a-zA-Z0-9_-]+\))?!?: .+'

if [[ ! "$title" =~ $regex ]]; then
  echo "✖ PR title does not follow Conventional Commits."
  echo "  Title: $title"
  echo "  Expected: type(scope?): description"
  echo "  Example:  feat(api): add login endpoint"
  exit 1
fi

echo "✔ PR title is a valid Conventional Commit."
