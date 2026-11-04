#!/usr/bin/env bash
#
# Ranks the open issues /implement-issue may pick up when it is given no
# number, best first, one tab-separated line each:
#   <number>  <created date>  <title>
# and, with --all, the skipped issues after them with the reason.
#
# Eligible: written by the repository owner; a spec written by /create-issue,
# carrying none of the labels in Scripts/claim-labels; not blocked by an open
# issue; and with no open PR.
# Order: oldest first, so an old issue is not starved by newer ones.

set -euo pipefail

show_skipped=false
[[ "${1:-}" == "--all" ]] && show_skipped=true

# shellcheck disable=SC2016 # $endCursor is a GraphQL variable, not a shell one.
query='
query($endCursor: String) {
  repository(owner: "adamayoung", name: "moth-app") {
    issues(states: OPEN, first: 50, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number title createdAt body authorAssociation
        labels(first: 30) { nodes { name } }
        blockedBy(first: 20) { nodes { number state } }
        closedByPullRequestsReferences(first: 10, includeClosedPrs: false) { nodes { number state } }
      }
    }
  }
}'

scripts=$(cd "$(dirname "$0")" && pwd)
claim_labels=$(grep -v -e '^#' -e '^[[:space:]]*$' "$scripts/claim-labels" | jq -R . | jq -s .)

gh api graphql --paginate --slurp -f query="$query" \
    | jq -r --argjson showSkipped "$show_skipped" --argjson claimLabels "$claim_labels" -f "$scripts/next-issue.jq"
