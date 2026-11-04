#!/bin/sh
# Print a Markdown "Concurrent work" section for /implement-issue: every other
# worktree of this repository, plus the main checkout's uncommitted changes,
# with the files each one changes and which of them overlap issue <N>.
#
#   Scripts/concurrent-work.sh <issue-number>
#
# Overlap is a file that issue <N>'s own tree also changes, or that <N>'s body
# names; each overlapping file says which. <N>'s tree is the worktree, or the
# main checkout on a --here run, whose branch config names <N>. Until that tree
# has changes, overlap is by named files only, and the output says so.
#
# A worktree's issue comes from `git config branch.<branch>.mothIssue`, then
# from the open issues carrying a label in Scripts/claim-labels
# whose body contains the branch name. Nothing is ever dropped: an entry that
# cannot be resolved is listed as such, with its files.
#
# It never fails the run: a git or gh error is reported inline and the script
# still exits 0. Overlap informs the run; it never blocks one.
set -u

issue="${1:-}"
case "$issue" in
    '' | *[!0-9]*)
        echo "usage: $0 <issue-number>" >&2
        exit 2
        ;;
esac

echo "## Concurrent work"
echo

here=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Survey failed: $(pwd) is not inside a checkout of the repository."
    exit 0
}
tmp=$(mktemp -d "${TMPDIR:-/tmp}/concurrent-work.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM

first_line() {
    head -1 "$1" | tr -d '\r'
}

if ! git -C "$here" fetch origin --quiet 2>"$tmp/err"; then
    echo "- Note: \`git fetch origin\` failed ($(first_line "$tmp/err")), so committed changes are measured against a possibly stale \`origin/main\`."
    echo
fi
base=origin/main
if ! git -C "$here" rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
    base=main
fi

git -C "$here" worktree list --porcelain >"$tmp/worktrees" 2>"$tmp/err" || {
    echo "Survey failed: \`git worktree list\` failed: $(first_line "$tmp/err")"
    exit 0
}
# Fields are split on \037, not a tab: `read` collapses runs of whitespace
# separators, so a detached entry's empty branch would shift the next field.
sep=$(printf '\037')
awk -v sep="$sep" '
    function emit() { if (path != "") print path sep head sep branch sep state }
    /^worktree / { emit(); path = substr($0, 10); head = ""; branch = ""; state = "" }
    /^HEAD / { head = $2 }
    /^branch / { branch = substr($0, 19) }
    /^detached/ { state = state "detached " }
    /^prunable/ { state = state "prunable " }
    /^bare/ { state = state "bare " }
    END { emit() }
' "$tmp/worktrees" >"$tmp/entries"
main_checkout=$(head -1 "$tmp/entries" | cut -d "$sep" -f1)

# Writes the files a worktree changes to $tmp/changed; errors to $tmp/errors.
collect_changes() {
    path=$1
    ref=$2
    : >"$tmp/changed"
    : >"$tmp/errors"
    if [ -n "$ref" ]; then
        if ! git -C "$here" diff --name-only "$base...$ref" >>"$tmp/changed" 2>"$tmp/err"; then
            echo "\`git diff $base...$ref\` failed: $(first_line "$tmp/err")" >>"$tmp/errors"
        fi
    fi
    if git -C "$path" status --porcelain --untracked-files=all >"$tmp/status" 2>"$tmp/err"; then
        sed -e 's/^...//' -e 's/.* -> //' -e 's/^"\(.*\)"$/\1/' "$tmp/status" >>"$tmp/changed"
    else
        echo "\`git status\` failed: $(first_line "$tmp/err")" >>"$tmp/errors"
    fi
    sort -u -o "$tmp/changed" "$tmp/changed"
}

labelled_loaded=""
load_labelled_issues() {
    [ -n "$labelled_loaded" ] && return 0
    labelled_loaded=1
    : >"$tmp/labelled"
    : >"$tmp/labelled-err"
    labels="$here/Scripts/claim-labels"
    [ -r "$labels" ] || echo "cannot read $labels" >>"$tmp/labelled-err"
    grep -v -e '^#' -e '^[[:space:]]*$' "$labels" 2>/dev/null | while IFS= read -r label || [ -n "$label" ]; do
        gh issue list --state open --label "$label" --limit 200 --json number,title,body \
            --jq '.[] | [.number, .title, .body] | @tsv' >>"$tmp/labelled" 2>>"$tmp/labelled-err" || true
    done
}

# Sets resolved_issue, resolved_title and resolution for a branch.
resolve_issue() {
    branch=$1
    resolved_issue=""
    resolved_title=""
    resolution=""
    key=$(git -C "$here" config --get "branch.$branch.mothIssue" 2>/dev/null || true)
    if [ -n "$key" ]; then
        resolved_issue=$key
        resolution="branch config"
        if ! resolved_title=$(gh issue view "$key" --json title -q .title 2>"$tmp/err"); then
            resolved_title="(title unavailable: $(first_line "$tmp/err"))"
        fi
        return
    fi
    case "$branch" in
        worktree-*)
            resolution="starting: issue not yet known"
            return
            ;;
    esac
    load_labelled_issues
    matches=$(awk -F '\t' -v branch="$branch" 'index($3, branch) { print $1 "\t" $2 }' "$tmp/labelled")
    if [ -n "$matches" ]; then
        resolved_issue=$(printf '%s\n' "$matches" | cut -f1 | paste -sd, - | sed 's/,/, #/g')
        resolved_title=$(printf '%s\n' "$matches" | cut -f2 | paste -sd'|' - | sed 's/|/ | /g')
        resolution="issue label, branch named in the issue body"
    elif [ -s "$tmp/labelled-err" ]; then
        resolution="unknown issue (label lookup failed: $(first_line "$tmp/labelled-err"))"
    else
        resolution="unknown issue"
    fi
}

own_tree=""
own_branch=""
while IFS="$sep" read -r path head branch state; do
    case "$state" in *prunable* | *detached* | *bare*) continue ;; esac
    [ -n "$branch" ] || continue
    if [ "$(git -C "$here" config --get "branch.$branch.mothIssue" 2>/dev/null)" = "$issue" ]; then
        own_tree=$path
        own_branch=$branch
        break
    fi
done <"$tmp/entries"
# Without the config key, fall back to the issue labels, as the survey of the
# other trees does; otherwise #N's own changes would read as "none yet".
if [ -z "$own_tree" ]; then
    while IFS="$sep" read -r path head branch state; do
        case "$state" in *prunable* | *detached* | *bare*) continue ;; esac
        [ -n "$branch" ] || continue
        resolve_issue "$branch"
        if [ "$resolved_issue" = "$issue" ]; then
            own_tree=$path
            own_branch=$branch
            break
        fi
    done <"$tmp/entries"
fi
: >"$tmp/own-changed"
own_unreadable=""
if [ -n "$own_tree" ]; then
    collect_changes "$own_tree" "$own_branch"
    cp "$tmp/changed" "$tmp/own-changed"
    while IFS= read -r error; do
        echo "- Error reading #$issue's own changes: $error"
        own_unreadable=1
    done <"$tmp/errors"
    [ -s "$tmp/errors" ] && echo
fi
if [ -n "$own_unreadable" ]; then
    own_state="its own changes could not all be read"
elif [ -z "$own_tree" ]; then
    own_state="it has no worktree here yet"
else
    own_state="it has no changes yet"
fi

# Paths issue <N> names: backticked tokens that, trailing `/` stripped, are a
# tracked file or a directory here. `feature/<name>`, `/create-issue` and shell
# expressions fail the check and are ignored.
: >"$tmp/named"
if gh issue view "$issue" --json body -q .body >"$tmp/body" 2>"$tmp/err"; then
    git -C "$here" ls-files >"$tmp/tracked" 2>/dev/null
    # shellcheck disable=SC2016 # Markdown backticks, not command substitution.
    grep -o '`[^`]*`' "$tmp/body" | tr -d '`' | sort -u >"$tmp/tokens"
    while IFS= read -r written; do
        token=$(printf '%s' "$written" | sed 's:/*$::')
        case "$token" in
            '' | . | .. | *..* | /* | *' '* | *'	'*) continue ;;
        esac
        if grep -qxF -- "$token" "$tmp/tracked"; then
            echo "$token"
        # A bare word such as `Moth` names the process far more often than
        # the top-level directory, so a directory must be written with a `/`.
        elif [ -d "$here/$token" ] && [ "$written" != "${written#*/}" ]; then
            echo "$token"
        fi
    done <"$tmp/tokens" | sort -u >"$tmp/named"
    if [ -n "$own_unreadable" ]; then
        echo "- Note: #$issue's own changes could not all be read, so overlap may miss files both branches change."
        echo
    elif [ ! -s "$tmp/own-changed" ]; then
        echo "- Note: #$issue ${own_state#it }, so overlap is by the files its body names only."
        echo
    fi
elif [ -s "$tmp/own-changed" ]; then
    echo "- Note: could not read issue #$issue ($(first_line "$tmp/err")), so overlap is by the files #$issue's branch changes only${own_unreadable:+, and those could not all be read}."
    echo
else
    echo "- Note: could not read issue #$issue ($(first_line "$tmp/err")), and $own_state, so no overlap can be computed."
    echo
fi

overlap() {
    awk -v namedfile="$tmp/named" -v ownfile="$tmp/own-changed" -v issue="$issue" '
        BEGIN {
            while ((getline line < namedfile) > 0) named[++n] = line
            while ((getline line < ownfile) > 0) own[line] = 1
        }
        {
            reasons = ($0 in own) ? "both change it" : ""
            for (i = 1; i <= n; i++) {
                if ($0 == named[i] || index($0, named[i] "/") == 1) {
                    reasons = reasons (reasons == "" ? "" : "; ") "#" issue " names it"
                    break
                }
            }
            if (reasons != "") print $0 "\t" reasons
        }' "$tmp/changed"
}

overlap_list() {
    if [ -s "$tmp/own-changed" ]; then
        # shellcheck disable=SC2016 # Markdown backticks, not command substitution.
        awk -F '\t' '{ printf "%s`%s` (%s)", (NR > 1 ? ", " : ""), $1, $2 } END { print "" }' "$1"
    else
        cut -f1 "$1" >"$1.paths"
        code_list "$1.paths"
    fi
}

code_list() {
    # shellcheck disable=SC2016 # Markdown backticks, not command substitution.
    sed 's/.*/`&`/' "$1" | paste -sd, - | sed 's/,/, /g'
}

entries=0
print_entry() {
    heading=$1
    shift
    entries=$((entries + 1))
    echo "### $heading"
    echo
    for line in "$@"; do
        echo "- $line"
    done
    while IFS= read -r error; do
        echo "- Error: $error"
    done <"$tmp/errors"
    count=$(wc -l <"$tmp/changed" | tr -d ' ')
    if [ "$count" -eq 0 ]; then
        echo "- Changes: none"
    else
        echo "- Changes ($count): $(code_list "$tmp/changed")"
    fi
    overlap >"$tmp/overlap"
    if [ -s "$tmp/overlap" ]; then
        echo "- **Overlap with #$issue:** $(overlap_list "$tmp/overlap")"
    else
        echo "- Overlap with #$issue: none"
    fi
    echo
}

if [ "$own_tree" != "$main_checkout" ]; then
    collect_changes "$main_checkout" ""
    if [ -s "$tmp/changed" ] || [ -s "$tmp/errors" ]; then
        print_entry "main checkout (uncommitted)" "Worktree: \`$main_checkout\`"
    fi
fi

tail -n +2 "$tmp/entries" >"$tmp/others"
# Read from fd 3: gh and git inside the loop would otherwise eat its stdin.
while IFS="$sep" read -r path head branch state <&3; do
    [ "$path" = "$here" ] && continue
    case "$state" in
        *prunable*)
            : >"$tmp/changed"
            : >"$tmp/errors"
            print_entry "prunable worktree" "Worktree: \`$path\` (its directory is gone; \`git worktree prune\` removes the entry)"
            continue
            ;;
        *detached*)
            collect_changes "$path" "$head"
            print_entry "detached worktree" "HEAD: \`$(printf '%s' "$head" | cut -c1-12)\` (detached)" "Worktree: \`$path\`"
            continue
            ;;
    esac
    resolve_issue "$branch"
    # Step 1 surveys from the main checkout, so issue <N>'s own
    # worktree is not skipped as $here and must be skipped by its issue.
    [ "$resolved_issue" = "$issue" ] && continue
    collect_changes "$path" "$branch"
    if [ -n "$resolved_issue" ]; then
        heading="#$resolved_issue $resolved_title"
    else
        heading="$resolution"
    fi
    print_entry "$heading" "Branch: \`$branch\`" "Worktree: \`$path\`" "Resolved by: $resolution"
done 3<"$tmp/others" >"$tmp/worktree-entries"
cat "$tmp/worktree-entries"

if [ "$entries" -eq 0 ] && [ ! -s "$tmp/worktree-entries" ]; then
    echo "No other runs are in flight, and the main checkout has no uncommitted changes."
fi
exit 0
