# The ranking behind Scripts/next-issue.sh, over `gh api graphql --paginate
# --slurp` pages. Takes $showSkipped and $claimLabels (Scripts/claim-labels).
# Tested by Scripts/tests/test_next_issue.py.

# The heading every /create-issue spec carries; create-issue's template must
# keep it, and the test checks that it does.
def specHeading: "## Acceptance criteria";
# The repository is public and /implement-issue starts on its pick without
# asking, so eligibility rests on what GitHub computes, never on the issue's
# text. An unknown or absent association is not trusted. Step 1 of the
# implement-issue skill applies the same rule: change both or neither.
def trustedAssociations: ["OWNER"];

[ .[].data.repository.issues.nodes[]
  | {
      number, title,
      created: .createdAt[0:10],
      skip: (
        if (.authorAssociation as $association | trustedAssociations | index($association) | not) then "not written by the owner"
        elif ([.labels.nodes[].name] | any(. as $label | $claimLabels | index($label))) then "claimed by Claude"
        elif ([.blockedBy.nodes[] | select(.state == "OPEN")] | length) > 0 then
          "blocked by " + ([.blockedBy.nodes[] | select(.state == "OPEN") | "#\(.number)"] | join(", "))
        elif ([.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN")] | length) > 0 then
          "open PR " + ([.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN") | "#\(.number)"] | join(", "))
        elif (.body | contains(specHeading) | not) then "not a /create-issue spec"
        else null end
      )
    }
]
| sort_by([.created, .number])
| (.[] | select(.skip == null) | [.number, .created, .title] | @tsv),
  (if $showSkipped then (.[] | select(.skip != null) | ["skip", .number, .skip, .title] | @tsv) else empty end)
