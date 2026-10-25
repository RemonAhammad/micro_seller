#!/usr/bin/env bash
# Makes a GitHub release of Micro Seller in one go:
#   1. brings in new commits from GitHub, keeping your uncommitted changes
#   2. pins GitHub's builds to this Mac's Flutter version and makes
#      pubspec.lock with it, so the two always match
#   3. picks the version: pubspec.yaml's if it isn't released yet, otherwise
#      the next patch, with a build number higher than any used before
#   4. shows what it will do and asks once
#   5. runs CI's checks here: packages, generated code, translations,
#      analyze, tests
#   6. commits everything, tags vX.Y.Z and pushes both in one atomic push
#   7. follows the GitHub build until the draft release is ready. You check
#      it and click Publish; this script never publishes.
#
# Usage: ./release.sh [VERSION] [OPTIONS]   (./release.sh --help)
# Works with macOS's bash 3.2. Needs git, flutter, curl and jq.
# RELEASE_GITHUB_REPO=owner/name overrides the repo read from origin's URL.
set -euo pipefail

ACTION_FILE=.github/actions/setup-flutter/action.yml
WORKFLOW=release.yml
FLUTTER_RELEASES=https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
SEMVER='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
# sed -nE scripts that print one value: the pubspec version, the Flutter pin.
VERSION_SED='s/^version:[[:space:]]*([^[:space:]#]+).*/\1/p'
PIN_SED='s/^[[:space:]]*flutter-version:[[:space:]]*([^[:space:]#]+).*/\1/p'
CHANNEL_SED='s/^[[:space:]]*channel:[[:space:]]*([^[:space:]#]+).*/\1/p'

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' OFF=$'\033[0m'
else
  BOLD='' DIM='' RED='' GREEN='' YELLOW='' OFF=''
fi

# One line per job for the build log: ✓ done, ● running (its current step),
# ⏸ waiting for approval, ✗ failed.
# shellcheck disable=SC2016 # $s is jq's, not the shell's
JOB_LINES='
def two: tostring | if length < 2 then "0" + . else . end;
def secs: sub("\\.[0-9]+"; "") | fromdateiso8601;
def took:
  try (
    if .started_at and .completed_at then
      ((.completed_at | secs) - (.started_at | secs)) as $s
      | " (\($s / 60 | floor)m \($s % 60 | floor | two)s)"
    else "" end
  ) catch "";
.jobs[]
| if .status == "completed" then
    if .conclusion == "success" then "✓ \(.name)\(took)"
    elif .conclusion == "skipped" then "– \(.name): skipped"
    else "✗ \(.name): \(.conclusion)" end
  elif .status == "waiting" then "⏸ \(.name) is waiting for your approval"
  elif .status == "in_progress" then
    "● \(.name): \([.steps[]? | select(.status == "in_progress") | .name][0] // "starting")"
  else empty end'

say() { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }
heading() { printf '\n%s▶ %s%s\n' "$BOLD" "$*" "$OFF"; }
warn() { printf '%s! %s%s\n' "$YELLOW" "$*" "$OFF" >&2; }
die() { # die TITLE [LINE...]
  printf '\n%s✗ %s%s\n' "$RED" "$1" "$OFF" >&2
  shift
  local line
  for line in "$@"; do printf '  %s\n' "$line" >&2; done
  exit 1
}
oneline() { printf '%s' "$1" | tr '\n' ' '; }

# File names as they are (Bengali ones too), not git's quoted escapes. Lists
# the script acts on are read NUL-separated (-z) as well.
git() { command git -c core.quotePath=false "$@"; }

usage() {
  cat << 'EOF'
Usage: ./release.sh [VERSION] [OPTIONS]

Makes a GitHub release: syncs with GitHub, picks the version, runs the
checks, commits, tags, pushes, then follows the build until the draft
release is ready for you to publish.

VERSION           1.2.3 or 1.2.3-rc.1, or patch / minor / major (a bump of
                  the newest release). Default: pubspec.yaml's version if
                  it isn't released yet, otherwise the next patch version.

Options:
  --dry-run         Show what it would do; change nothing.
  -y, --yes         Don't ask for confirmation.
  --skip-checks     Skip translations, analyze and tests here (GitHub still
                    runs them). Packages and generated code always run.
  --no-watch        Push, then exit without following the GitHub build.
  --watch [vX.Y.Z]  Only follow a release build (default: the newest tag),
                    e.g. after Ctrl-C or GitHub's "Re-run failed jobs".
  -h, --help        Show this help.

Environment:
  GH_TOKEN, GITHUB_TOKEN  A GitHub token for following the build (a signed-in
                          gh works too). Without one it checks once a minute,
                          within GitHub's 60 calls an hour.
  RELEASE_GITHUB_REPO     owner/name to use instead of origin's.
  NO_COLOR                Plain output.
EOF
}

parse_args() {
  DRY_RUN=false YES=false SKIP_CHECKS=false WATCH=true WATCH_ONLY=false WATCH_TAG='' VERSION_ARG=''
  while [ $# -gt 0 ]; do
    case $1 in
      --dry-run) DRY_RUN=true ;;
      -y | --yes) YES=true ;;
      --skip-checks) SKIP_CHECKS=true ;;
      --no-watch) WATCH=false ;;
      --watch)
        WATCH_ONLY=true
        case ${2:-} in
          v[0-9]* | [0-9]*)
            WATCH_TAG=v${2#v}
            shift
            ;;
        esac
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -*) die "Unknown option: $1" "See ./release.sh --help" ;;
      *)
        [ -z "$VERSION_ARG" ] || die "Give one version only (got $VERSION_ARG and $1)."
        VERSION_ARG=$1
        ;;
    esac
    shift
  done
}

# --- Preflight ---------------------------------------------------------------

preflight() {
  cd "$(dirname "$0")"
  cd "$(git rev-parse --show-toplevel 2> /dev/null || pwd)"
  if [ ! -f pubspec.yaml ] || [ ! -f "$ACTION_FILE" ]; then
    die "release.sh must sit in the micro_seller repo, next to pubspec.yaml."
  fi
  local tool
  for tool in git curl jq; do
    if ! command -v "$tool" > /dev/null; then
      case $tool in
        jq) die "jq isn't installed." "Install it with: brew install jq" ;;
        *) die "$tool isn't installed, or isn't on your PATH." ;;
      esac
    fi
  done

  local url
  url=$(git remote get-url origin 2> /dev/null) || die "This repo has no 'origin' remote."
  REPO=${RELEASE_GITHUB_REPO:-}
  if [ -z "$REPO" ]; then
    REPO=$(github_repo "$url") || die "origin ($url) isn't a GitHub repo." \
      "Set RELEASE_GITHUB_REPO=owner/name to use another one."
  fi
  if $WATCH_ONLY; then return; fi

  command -v flutter > /dev/null || die "flutter isn't installed, or isn't on your PATH."
  DART=$(command -v dart || true)
  [ -n "$DART" ] || DART="$(dirname "$(command -v flutter)")/dart"

  local branch state unmerged
  branch=$(git symbolic-ref --quiet --short HEAD) || die "You aren't on a branch." "Switch to main first: git switch main"
  [ "$branch" = main ] || die "Releases are made from main, but you're on $branch." "Switch first: git switch main"
  DOT_GIT=$(git rev-parse --absolute-git-dir)
  for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
    [ ! -e "$DOT_GIT/$state" ] || die "A git merge, rebase or cherry-pick is still in progress." "Finish it (or abort it) first."
  done
  unmerged=$(git diff --name-only --diff-filter=U)
  [ -z "$unmerged" ] || die "These files still have merge conflicts: $(oneline "$unmerged")" "Fix them and git add them first."
}

github_repo() { # github_repo URL: owner/name of a github.com remote URL
  local slug
  case $1 in
    *github.com[/:]*) slug=${1#*github.com[/:]} ;;
    *) return 1 ;;
  esac
  slug=${slug%/}
  slug=${slug%.git}
  case $slug in
    */*/* | */ | /*) return 1 ;;
    ?*/?*) printf '%s\n' "$slug" ;;
    *) return 1 ;;
  esac
}

# --- Sync with GitHub --------------------------------------------------------

sync_with_github() {
  heading "Syncing with GitHub ($REPO)"
  local counts ahead incoming clash conflicts out
  if ! out=$(git fetch --quiet --tags origin 2>&1); then
    printf '%s\n' "$out" | sed 's/^/    /' >&2
    die "Couldn't fetch from GitHub (git's message is above)." "Fix that (often the internet connection), then run ./release.sh again."
  fi
  git rev-parse --verify --quiet origin/main > /dev/null || die "GitHub's repo has no main branch."
  counts=$(git rev-list --left-right --count HEAD...origin/main)
  ahead=${counts%%[[:space:]]*}
  BEHIND=${counts##*[[:space:]]}
  if [ "$BEHIND" -eq 0 ]; then
    if [ "$ahead" -gt 0 ]; then
      info "Up to date. Your $ahead unpushed commit(s) go up with the release."
    else
      info "Up to date."
    fi
    return
  fi
  if [ "$ahead" -gt 0 ]; then
    die "This Mac and GitHub both have new commits on main ($ahead here, $BEHIND on GitHub)." \
      "Combine them first: git pull --rebase --autostash" \
      "If git stops on pubspec.lock, keep your copy (this script re-makes it anyway): git checkout --theirs pubspec.lock && git add pubspec.lock" \
      "then finish with git rebase --continue (or with git stash drop, if git said the autostash conflicted)." \
      "Then run ./release.sh again."
  fi
  incoming=$(git log --format='    %h %s' HEAD..origin/main)
  if $DRY_RUN; then
    HIST_REF=origin/main
    info "GitHub has $BEHIND new commit(s). A real run brings them in and keeps your changes:"
    say "$incoming"
    return
  fi

  if [ -z "$(git status --porcelain)" ]; then
    git merge --quiet --ff-only origin/main
  else
    # A new file of yours that GitHub now has too would stop the unstash
    # halfway, so check before stashing anything.
    clash=$(git ls-files --others --exclude-standard -z | while IFS= read -r -d '' f; do
      if git cat-file -e "origin/main:$f" 2> /dev/null; then printf '%s\n' "$f"; fi
    done)
    [ -z "$clash" ] || die "GitHub now has files with the same names as new files of yours: $(oneline "$clash")" \
      "Move yours out of the project (or delete them if they're the same), then run ./release.sh again."
    wait_for_git_lock
    git stash push --quiet --include-untracked -m "release.sh: your changes before syncing with GitHub"
    STASHED=true
    git merge --quiet --ff-only origin/main
    if ! unstash; then
      conflicts=$(git diff --name-only --diff-filter=U)
      if [ -z "$conflicts" ]; then
        STASHED=false # the message below says how to get them back
        printf '%s\n' "$POP_OUTPUT" | sed 's/^/    /' >&2
        restore_untracked_from_stash || true
        die "Couldn't put your changes back after syncing with GitHub. They're all safe in git's stash." \
          "Get them back with: git stash pop" \
          "If it says a file already exists, delete that file (git already put it back from the stash) and run git stash pop again." \
          "If it says your local changes to a file would be overwritten, run git checkout -- <that file> (a tool changed it; your version is in the stash) and run git stash pop again."
      fi
      restore_untracked_from_stash
      if [ "$conflicts" != pubspec.lock ]; then
        STASHED=false # applied with conflicts; the message says how to finish
        die "GitHub's new commits and your changes both changed: $(oneline "$conflicts")" \
          "Open each file, keep the lines you want, and delete the <<<<<<<, ======= and >>>>>>> lines." \
          "Then run git add on each file, then git stash drop, then ./release.sh again."
      fi
      # Keep this Mac's copy: the checks re-make pubspec.lock for this Flutter anyway.
      git checkout --quiet --theirs -- pubspec.lock
      git add pubspec.lock
      git stash drop --quiet
    fi
    STASHED=false
  fi
  info "Brought in $BEHIND new commit(s) from GitHub; your changes are kept:"
  say "$incoming"
}

# Unstash after the fast-forward, first keeping your staged/unstaged split
# (--index; that fails early when the index can't take it, e.g. when GitHub
# added a pubspec.lock you had staged too). Fails when git leaves conflicts,
# which the caller handles, or when it can't unstash at all. The stash is
# kept either way.
unstash() {
  local attempt
  for attempt in 1 2 3; do
    wait_for_git_lock
    if [ "$attempt" = 1 ]; then
      POP_OUTPUT=$(git stash pop --index 2>&1) && return 0
    else
      POP_OUTPUT=$(git stash pop 2>&1) && return 0
    fi
    [ -z "$(git diff --name-only --diff-filter=U)" ] || return 1
    # No conflicts, so the stash is intact. Undo what got in the way, then
    # try again: new files git already put back (the stash's own copies),
    # and tracked files something else changed meanwhile. Right after the
    # stash and the fast-forward every tracked file matched HEAD, so a change
    # now came from a tool or an editor (graft rewrites
    # graft/.cache/stats.json, for example). Where the stash has your own
    # version of such a file, HEAD's goes back so the unstash can bring yours.
    remove_restored_untracked || return 1
    git diff --name-only -z HEAD | while IFS= read -r -d '' f; do
      if ! git diff --quiet 'stash@{0}^1' 'stash@{0}' -- "$f"; then
        info "Something changed $f during the sync; your own version of it is in the stash."
        git checkout --quiet HEAD -- "$f"
      fi
    done
  done
  return 1
}

# New files a failed unstash already put back: remove them if they're the
# stash's own copies, so the next try can put them back again.
remove_restored_untracked() {
  git rev-parse --quiet --verify 'stash@{0}^3' > /dev/null || return 0
  git ls-tree -r -z --name-only 'stash@{0}^3' | while IFS= read -r -d '' f; do
    if [ -e "$f" ] || [ -L "$f" ]; then
      git cat-file blob "stash@{0}^3:$f" | cmp -s - "$f" || exit 1
      rm -f "$f"
    fi
  done
}

wait_for_git_lock() { # an editor's git may hold the index lock for a moment
  local i=0
  while [ -e "$DOT_GIT/index.lock" ] && [ "$i" -lt 40 ]; do
    sleep 0.25
    i=$((i + 1))
  done
}

# An unstash that stops on a conflict may leave untracked files only in the
# stash. Put back any that are missing before the stash is dropped.
restore_untracked_from_stash() {
  git rev-parse --quiet --verify 'stash@{0}^3' > /dev/null || return 0
  git ls-tree -r -z --name-only 'stash@{0}^3' | while IFS= read -r -d '' f; do
    if [ ! -e "$f" ]; then
      git checkout 'stash@{0}^3' -- "$f"
      git reset --quiet -- "$f"
    fi
  done
}

# synced FILE SED: the value SED prints from FILE, as it is after the sync. A
# dry run skips the sync, so it takes GitHub's value unless you changed it
# here, as git's merge would.
synced() {
  local here head
  here=$(sed -nE "$2" "$1" | sed -n 1p)
  if [ "$HIST_REF" != HEAD ]; then
    head=$(git show "HEAD:$1" 2> /dev/null | sed -nE "$2" | sed -n 1p)
    if [ "$here" = "$head" ]; then
      git show "$HIST_REF:$1" 2> /dev/null | sed -nE "$2" | sed -n 1p
      return
    fi
  fi
  printf '%s\n' "$here"
}

# --- Flutter -----------------------------------------------------------------

detect_flutter() {
  local json revision releases entry hash
  json=$(flutter --version --machine 2> /dev/null | sed -n '/^{/,/^}/p') || json=''
  FLUTTER_VERSION=$(printf '%s' "$json" | jq -r '.frameworkVersion // empty' 2> /dev/null) || FLUTTER_VERSION=''
  revision=$(printf '%s' "$json" | jq -r '.frameworkRevision // empty' 2> /dev/null) || revision=''
  [ -n "$FLUTTER_VERSION" ] || die "Couldn't read this Mac's Flutter version (flutter --version --machine)."

  # The list GitHub's flutter-action installs from.
  releases=$(curl -fsSL --retry 2 "$FLUTTER_RELEASES") || die "Couldn't download Flutter's list of releases." \
    "Check your internet connection, then run ./release.sh again."
  NEWEST_STABLE=$(printf '%s' "$releases" | jq -r '.current_release.stable as $h | [.releases[] | select(.hash == $h)][0].version // empty')
  entry=$(printf '%s' "$releases" | jq -c --arg v "$FLUTTER_VERSION" '[.releases[] | select(.version == $v)][0] // empty')
  [ -n "$entry" ] || die "This Mac's Flutter ($FLUTTER_VERSION) isn't a published Flutter release, so GitHub can't install it." \
    "Switch to a release first, e.g. the newest stable${NEWEST_STABLE:+ ($NEWEST_STABLE)}: flutter channel stable && flutter upgrade"
  FLUTTER_CHANNEL=$(printf '%s' "$entry" | jq -r .channel)
  hash=$(printf '%s' "$entry" | jq -r .hash)
  if [ "$hash" != "$revision" ]; then
    warn "Your Flutter $FLUTTER_VERSION is at revision ${revision:-?}, not the published ${hash:0:10}. GitHub builds the published one."
  fi

  PIN_VERSION=$(synced "$ACTION_FILE" "$PIN_SED")
  PIN_CHANNEL=$(synced "$ACTION_FILE" "$CHANNEL_SED")
  if [ -z "$PIN_VERSION" ] || [ -z "$PIN_CHANNEL" ]; then
    die "$ACTION_FILE has no flutter-version or channel line to update."
  fi
}

# --- Version -----------------------------------------------------------------

tag_exists() { git rev-parse --quiet --verify "refs/tags/$1" > /dev/null; }

# ver_gt A B: A is newer than B. X.Y.Z compare as numbers; a release is
# newer than its own pre-releases.
ver_gt() {
  local a=${1%%-*} b=${2%%-*}
  if [ "$a" != "$b" ]; then
    [ "$(printf '%s\n%s\n' "$a" "$b" | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)" = "$a" ]
    return
  fi
  case $1/$2 in
    *-*/*-*) pre_gt "${1#*-}" "${2#*-}" ;;
    */*-*) return 0 ;;
    *) return 1 ;;
  esac
}

# pre_gt A B: pre-release A (rc.10) is newer than B (rc.9), by semver's rules:
# fields compare one by one, numbers as numbers and below words, and more
# fields win.
pre_gt() {
  local a=$1 b=$2 x y
  while [ -n "$a" ] && [ -n "$b" ]; do
    x=${a%%.*}
    y=${b%%.*}
    if [ "$x" != "$y" ]; then
      if [[ $x =~ ^[0-9]+$ ]] && [[ $y =~ ^[0-9]+$ ]]; then
        [ "$((10#$x))" -gt "$((10#$y))" ]
      elif [[ $x =~ ^[0-9]+$ ]]; then
        return 1
      elif [[ $y =~ ^[0-9]+$ ]]; then
        return 0
      else
        [[ $x > $y ]]
      fi
      return
    fi
    case $a in *.*) a=${a#*.} ;; *) a='' ;; esac
    case $b in *.*) b=${b#*.} ;; *) b='' ;; esac
  done
  [ -n "$a" ]
}

# bump patch|minor|major VERSION. Like npm's semver, a pre-release bumps to
# its own release first: patch 1.2.0-rc.1 → 1.2.0, minor 1.3.0-rc.1 → 1.3.0.
bump() {
  local x y z pre=''
  case $2 in *-*) pre=${2#*-} ;; esac
  IFS=. read -r x y z <<< "${2%%-*}"
  x=$((10#$x))
  y=$((10#$y))
  z=$((10#$z))
  case $1 in
    major)
      if [ -n "$pre" ] && [ "$y" = 0 ] && [ "$z" = 0 ]; then printf '%s\n' "$x.0.0"; else printf '%s\n' "$((x + 1)).0.0"; fi
      ;;
    minor)
      if [ -n "$pre" ] && [ "$z" = 0 ]; then printf '%s\n' "$x.$y.0"; else printf '%s\n' "$x.$((y + 1)).0"; fi
      ;;
    patch)
      if [ -n "$pre" ]; then printf '%s\n' "$x.$y.$z"; else printf '%s\n' "$x.$y.$((z + 1))"; fi
      ;;
  esac
}

newest_release() { # the newest vX.Y.Z tag, without the v
  git tag -l 'v*' | sed 's/^v//' | {
    local n newest=''
    while IFS= read -r n; do
      [[ $n =~ $SEMVER ]] || continue
      if [ -z "$newest" ] || ver_gt "$n" "$newest"; then newest=$n; fi
    done
    printf '%s\n' "$newest"
  }
}

# The highest build number ever committed to pubspec.yaml or tagged: Play
# Store refuses a number it has seen, and any of them may have been uploaded.
max_used_code() {
  {
    git log -p --format= -G'^version:' "$HIST_REF" -- pubspec.yaml \
      | sed -nE 's/^[-+]version:[[:space:]]*[^+[:space:]]*\+([0-9]+).*/\1/p'
    git tag -l 'v*' | while IFS= read -r t; do
      git show "$t:pubspec.yaml" 2> /dev/null | sed -nE 's/^version:[[:space:]]*[^+[:space:]]*\+([0-9]+).*/\1/p'
    done
  } | sort -n | tail -n 1
}

choose_version() {
  local current used base
  current=$(synced pubspec.yaml "$VERSION_SED")
  CUR_NAME=${current%%+*}
  CUR_CODE=${current##*+}
  if [[ $current != *+* ]] || ! [[ $CUR_NAME =~ $SEMVER ]] || ! [[ $CUR_CODE =~ ^[0-9]+$ ]]; then
    die "pubspec.yaml's version (${current:-none}) must look like 1.2.3+45."
  fi
  NEWEST=$(newest_release)
  used=$(max_used_code)
  used=$((10#${used:-0}))

  case ${VERSION_ARG:-auto} in
    auto)
      if ! tag_exists "v$CUR_NAME" && { [ -z "$NEWEST" ] || ver_gt "$CUR_NAME" "$NEWEST"; }; then
        NEW_NAME=$CUR_NAME
        WHY="pubspec.yaml's version isn't released yet"
      else
        base=$CUR_NAME
        if [ -n "$NEWEST" ] && ver_gt "$NEWEST" "$CUR_NAME"; then base=$NEWEST; fi
        NEW_NAME=$(bump patch "$base")
        WHY="v$base is already tagged"
      fi
      ;;
    patch | minor | major)
      NEW_NAME=$(bump "$VERSION_ARG" "${NEWEST:-$CUR_NAME}")
      WHY="$VERSION_ARG bump of ${NEWEST:+v}${NEWEST:-$CUR_NAME}"
      ;;
    *)
      NEW_NAME=${VERSION_ARG#v}
      [[ $NEW_NAME =~ $SEMVER ]] || die "Not a version: $VERSION_ARG" "Use 1.2.3, 1.2.3-rc.1, patch, minor or major."
      WHY="as you asked"
      ;;
  esac
  if tag_exists "v$NEW_NAME"; then die "v$NEW_NAME is already used. Pick a newer version."; fi
  if [ -n "$NEWEST" ] && ! ver_gt "$NEW_NAME" "$NEWEST"; then
    die "v$NEW_NAME isn't newer than the newest release, v$NEWEST."
  fi
  if [ "$((10#$CUR_CODE))" -gt "$used" ]; then
    NEW_CODE=$((10#$CUR_CODE))
  else
    NEW_CODE=$((used + 1))
    if [ "$NEW_CODE" -gt "$((10#$CUR_CODE + 1))" ]; then WHY="$WHY; build numbers up to $used are taken"; fi
  fi
  TAG=v$NEW_NAME
  AGAIN="Fix it, then run ./release.sh again: nothing was committed or pushed, and it keeps $NEW_NAME+$NEW_CODE."
}

# --- Plan and confirmation ---------------------------------------------------

# Names that usually hold secrets: signing keys, .env files (but not the
# .env.example template), SSH and service-account keys, OAuth client secrets.
secret_like() {
  grep -iE '(^|/)(key\.properties|\.env(\.[^/]*)?|id_(rsa|dsa|ecdsa|ed25519)|client_secret[^/]*\.json|[^/]*service[-_]account[^/]*\.json|[^/]+\.(jks|keystore|p12|pfx|pem|p8|key))$' \
    | grep -viE '(^|/)\.env\.example$' || true
}

check_secrets() { # check_secrets "PATHS": stop if a file to commit looks like a secret
  local bad
  bad=$(printf '%s\n' "$1" | secret_like)
  [ -z "$bad" ] || die "These files look like secrets, and the repo is public: $(oneline "$bad")" \
    "Move them out of the project (or add them to .gitignore), then run ./release.sh again."
}

show_plan() {
  local changes count since=0
  heading "Release plan"
  printf '  %-9s %s → %s  %s(%s)%s\n' Version "$CUR_NAME+$CUR_CODE" "$NEW_NAME+$NEW_CODE" "$DIM" "$WHY" "$OFF"
  if [ "$PIN_VERSION" = "$FLUTTER_VERSION" ] && [ "$PIN_CHANNEL" = "$FLUTTER_CHANNEL" ]; then
    printf '  %-9s %s\n' Flutter "$FLUTTER_VERSION ($FLUTTER_CHANNEL) on this Mac; GitHub uses it too"
  else
    printf '  %-9s %s\n' Flutter "$FLUTTER_VERSION ($FLUTTER_CHANNEL) on this Mac; GitHub switches from $PIN_VERSION to it"
    if ver_gt "$PIN_VERSION" "$FLUTTER_VERSION"; then
      printf '  %-9s %s\n' '' "That's older than GitHub's. Packages get resolved for $FLUTTER_VERSION."
      if [ -n "$NEWEST_STABLE" ]; then
        printf '  %-9s %s\n' '' "To use the newest stable ($NEWEST_STABLE) instead, stop here and run: flutter upgrade"
      fi
    fi
  fi

  changes=$(git status --short)
  count=$(printf '%s\n' "$changes" | sed '/^$/d' | wc -l | tr -d ' ')
  if [ -n "$NEWEST" ]; then since=$(git rev-list --count "v$NEWEST..$HIST_REF"); fi
  if [ "$count" -eq 0 ]; then
    printf '  %-9s %s\n' Changes "no uncommitted files"
  else
    printf '  %-9s %s\n' Changes "$count uncommitted file(s) go into the release commit:"
    printf '%s\n' "$changes" | sed -n '1,25p' | sed 's/^/              /'
    if [ "$count" -gt 25 ]; then printf '              … and %s more\n' "$((count - 25))"; fi
  fi
  if [ "$since" -gt 0 ]; then printf '  %-9s %s\n' '' "plus $since commit(s) since v$NEWEST"; fi
  if [ -n "$NEWEST" ] && [ "$since" -eq 0 ] && [ "$count" -eq 0 ] \
    && [ "$PIN_VERSION" = "$FLUTTER_VERSION" ] && [ "$PIN_CHANNEL" = "$FLUTTER_CHANNEL" ]; then
    warn "Nothing changed since v$NEWEST: this rebuilds the same app under a new number."
  fi
  local steps="checks"
  if $SKIP_CHECKS; then steps="packages + generated code (other checks skipped)"; fi
  steps="$steps → commit → push main + tag $TAG"
  if $WATCH; then steps="$steps → follow the GitHub build"; fi
  printf '  %-9s %s\n' Then "$steps"
}

confirm() {
  local answer=''
  if $YES; then return; fi
  printf '\nContinue? [y/N] '
  read -r answer || true
  case $answer in
    [yY] | [yY][eE][sS]) ;;
    *)
      say "Stopped. Nothing was committed or pushed."
      exit 1
      ;;
  esac
}

# --- Prepare and check -------------------------------------------------------

write_version() {
  local tmp
  tmp=$(mktemp "$WORK/pubspec.XXXXXX")
  sed -E "s/^version:.*/version: $NEW_NAME+$NEW_CODE/" pubspec.yaml > "$tmp"
  cat "$tmp" > pubspec.yaml
  [ "$(sed -nE "$VERSION_SED" pubspec.yaml | sed -n 1p)" = "$NEW_NAME+$NEW_CODE" ] || die "Couldn't write the version into pubspec.yaml."
}

write_flutter_pin() {
  local tmp
  if [ "$PIN_VERSION" = "$FLUTTER_VERSION" ] && [ "$PIN_CHANNEL" = "$FLUTTER_CHANNEL" ]; then return; fi
  tmp=$(mktemp "$WORK/action.XXXXXX")
  sed -E -e "s/^([[:space:]]*flutter-version:[[:space:]]*)[^[:space:]#]+/\1$FLUTTER_VERSION/" \
    -e "s/^([[:space:]]*channel:[[:space:]]*)[^[:space:]#]+/\1$FLUTTER_CHANNEL/" "$ACTION_FILE" > "$tmp"
  cat "$tmp" > "$ACTION_FILE"
  info "GitHub now builds with Flutter $FLUTTER_VERSION ($FLUTTER_CHANNEL), set in $ACTION_FILE."
}

quietly() { # quietly NAME CMD...: run CMD, and show its output only if it fails
  local log="$WORK/$1.log"
  shift
  if "$@" > "$log" 2>&1; then return 0; fi
  tail -n 40 "$log" >&2
  return 1
}

run_checks() {
  heading "1/5 Packages"
  flutter pub get || die "flutter pub get failed (see above)." "$AGAIN"
  # Exactly what GitHub runs first: the lock must fit this Flutter.
  quietly enforce flutter pub get --enforce-lockfile || die "pubspec.lock doesn't pass GitHub's check." "$AGAIN"

  heading "2/5 Generated code"
  info "build_runner takes a minute or two…"
  quietly codegen "$DART" run build_runner build --delete-conflicting-outputs || die "Code generation failed (see above)." "$AGAIN"

  if $SKIP_CHECKS; then
    info "Skipping translations, analyze and tests (--skip-checks). GitHub still runs them."
    return
  fi

  heading "3/5 Translations"
  bash .claude/skills/l10n/scripts/l10n_parity.sh || die "Some translations are missing (see above)." "$AGAIN"

  heading "4/5 Analyze"
  if flutter analyze --no-fatal-infos > "$WORK/analyze.log" 2>&1; then
    info "No errors or warnings ($(grep -cE '^[[:space:]]*info •' "$WORK/analyze.log" || true) infos)."
  else
    grep -E '^[[:space:]]*(error|warning) •' "$WORK/analyze.log" >&2 || tail -n 30 "$WORK/analyze.log" >&2
    die "flutter analyze found errors or warnings (see above)." "$AGAIN"
  fi

  heading "5/5 Tests"
  flutter test --file-reporter "json:$WORK/tests.jsonl" || die "Some tests failed (see above)." "$AGAIN"
  # Like CI: the real-Isar tests skip themselves when the Isar core library
  # isn't found, and CI fails on any skipped test.
  local skipped
  skipped=$(jq -rs '
    (map(select(.type == "testStart") | {key: (.test.id | tostring), value: .test.name}) | from_entries) as $names
    | map(select(.type == "testDone" and .skipped == true and .hidden != true) | $names[.testID | tostring])
    | .[]' "$WORK/tests.jsonl") || die "Couldn't read the test results." "$AGAIN"
  if [ -n "$skipped" ]; then
    printf '%s\n' "$skipped" | sed 's/^/    /' >&2
    die "$(printf '%s\n' "$skipped" | wc -l | tr -d ' ') test(s) were skipped, and GitHub fails on that (Isar core library not loaded?)." "$AGAIN"
  fi
}

# --- Commit, tag, push -------------------------------------------------------

commit_tag_push() {
  local bad out hint
  heading "Commit, tag and push"
  wait_for_git_lock
  git add -A
  bad=$(git diff --cached --name-only -z --diff-filter=d | tr '\0' '\n' | secret_like)
  if [ -n "$bad" ]; then
    printf '%s\n' "$bad" | while IFS= read -r f; do git reset --quiet -- "$f"; done
    check_secrets "$bad"
  fi
  wait_for_git_lock
  git commit --quiet -m "chore: release $TAG+$NEW_CODE" || die "git commit failed (see above)." "$AGAIN"
  RELEASE_SHA=$(git rev-parse HEAD)
  PHASE=committed
  if ! git tag -a "$TAG" -m "Micro Seller $NEW_NAME"; then
    undo_release
    die "Couldn't create tag $TAG (see above)." "$AGAIN"
  fi
  info "Committed $(git rev-parse --short HEAD) \"chore: release $TAG+$NEW_CODE\" and tagged $TAG."

  # Both or neither. GitHub then runs CI for main and the Release workflow
  # for the tag.
  if out=$(git push --atomic origin HEAD:refs/heads/main "refs/tags/$TAG" 2>&1) || pushed_anyway; then
    PHASE=pushed
    info "Pushed main and $TAG to GitHub."
    return
  fi
  undo_release
  printf '%s\n' "$out" | sed 's/^/    /' >&2
  case $out in
    *workflow*scope*)
      hint="Your GitHub sign-in may not change workflow files (.github/workflows), which this release does. Sign in again with the 'workflow' permission, e.g.: brew install gh && gh auth login" ;;
    *GH013* | *"rule violation"*)
      hint="A rule under GitHub → Settings → Rules blocked main or the tag. Allow yourself to bypass it." ;;
    *"fetch first"* | *non-fast-forward*)
      hint="GitHub got new commits meanwhile. Run ./release.sh again; it brings them in first." ;;
    *[Aa]uthentication* | *"could not read Username"* | *403*)
      hint="GitHub didn't accept your sign-in. Sign in again (e.g. brew install gh && gh auth login), then run ./release.sh again." ;;
    *) hint="Check git's message above, then run ./release.sh again." ;;
  esac
  die "The push to GitHub failed, so nothing was released." \
    "The release commit and tag were undone here; your changes are still staged." "$hint"
}

pushed_anyway() { # GitHub has our tag although git reported a failure
  local want got
  want=$(git rev-parse "refs/tags/$TAG")
  got=$(git ls-remote "$(git remote get-url --push origin)" "refs/tags/$TAG" 2> /dev/null \
    | awk -v ref="refs/tags/$TAG" '$2 == ref {print $1}') || got=''
  [ -n "$got" ] && [ "$got" = "$want" ]
}

undo_release() {
  git tag -d "$TAG" > /dev/null 2>&1 || true
  if [ "$(git rev-parse HEAD)" = "$RELEASE_SHA" ]; then git reset --quiet --soft HEAD~1; fi
  PHASE=checks
}

# --- Follow the GitHub build -------------------------------------------------

init_api() {
  API_TOKEN=${GH_TOKEN:-${GITHUB_TOKEN:-}}
  if [ -z "$API_TOKEN" ] && command -v gh > /dev/null 2>&1; then
    API_TOKEN=$(gh auth token 2> /dev/null || true)
  fi
  # Without a token GitHub allows 60 calls an hour.
  if [ -n "$API_TOKEN" ]; then POLL=20 POLL_APPROVAL=30; else POLL=60 POLL_APPROVAL=120; fi
}

# api PATH: the body of GET https://api.github.com/PATH. Waits out rate
# limits and network blips; on failure $WORK/code holds the HTTP status
# (000: no connection).
api() {
  local code remaining reset tries=0
  local -a auth
  auth=()
  if [ -n "$API_TOKEN" ]; then auth=(-H "Authorization: Bearer $API_TOKEN"); fi
  # The last call used up the hourly limit: wait for the reset only now that
  # another call is due, so a final message is never held back.
  if [ -s "$WORK/reset_at" ]; then
    reset=$(cat "$WORK/reset_at")
    rm -f "$WORK/reset_at"
    if [ "$reset" -gt "$(date +%s)" ]; then wait_for_reset "$reset"; fi
  fi
  while :; do
    : > "$WORK/headers"
    code=$(curl -sS -o "$WORK/body" -D "$WORK/headers" -w '%{http_code}' \
      -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' \
      ${auth[@]+"${auth[@]}"} "https://api.github.com/$1" 2> /dev/null) || code=000
    printf '%s\n' "$code" > "$WORK/code"
    remaining=$(awk 'tolower($1) == "x-ratelimit-remaining:" {print $2 + 0}' "$WORK/headers" 2> /dev/null || true)
    reset=$(awk 'tolower($1) == "x-ratelimit-reset:" {print $2 + 0}' "$WORK/headers" 2> /dev/null || true)
    case $code in
      200)
        cat "$WORK/body"
        if [ "${remaining:-60}" -le 1 ] && [ -n "$reset" ]; then printf '%s\n' "$reset" > "$WORK/reset_at"; fi
        return 0
        ;;
      403 | 429)
        if [ "${remaining:-1}" = 0 ]; then
          wait_for_reset "$reset"
          continue
        fi
        ;;
      000 | 5??)
        tries=$((tries + 1))
        if [ "$tries" -le 5 ]; then
          sleep 15
          continue
        fi
        ;;
    esac
    return 1
  done
}

wait_for_reset() { # wait_for_reset EPOCH
  local reset=${1:-0} wait
  wait=$((reset - $(date +%s) + 5))
  if [ "$wait" -le 0 ] || [ "$wait" -gt 3700 ]; then wait=60; fi
  printf '  %s\n' "GitHub's hourly limit of API calls is used up; checking again at $(clock $(($(date +%s) + wait)))…" >&2
  sleep "$wait"
}

clock() { date -r "$1" +%H:%M 2> /dev/null || date -d "@$1" +%H:%M; }

api_code() { cat "$WORK/code" 2> /dev/null || echo 000; }

api_hint() { # api_hint CODE: what a failed GitHub API call means for you
  case $1 in
    000) echo "Check your internet connection." ;;
    401) echo "GitHub refused the token in GH_TOKEN, GITHUB_TOKEN or gh. Unset it, or make a new one." ;;
    403 | 429) echo "GitHub is limiting calls from this network for now." ;;
    404) echo "GitHub doesn't know that repo or build ($REPO). Is RELEASE_GITHUB_REPO right?" ;;
    *) echo "GitHub answered HTTP $1; it usually works again after a few minutes." ;;
  esac
}

open_url() { if [ "$(uname)" = Darwin ]; then open "$1" > /dev/null 2>&1 || true; fi; }

notify() { # bell + macOS notification
  printf '\a'
  if command -v osascript > /dev/null 2>&1; then
    osascript -e "display notification \"$1\" with title \"Micro Seller release\"" > /dev/null 2>&1 || true
  fi
}

find_run() { # find_run QUERY wait|nowait: the newest Release run matching QUERY, e.g. head_sha=…
  local tries=0 json code
  while :; do
    if json=$(api "repos/$REPO/actions/workflows/$WORKFLOW/runs?event=push&per_page=1&$1"); then
      RUN_ID=$(printf '%s' "$json" | jq -r '.workflow_runs[0].id // empty' 2> /dev/null || true)
      if [ -n "$RUN_ID" ]; then
        RUN_URL=$(printf '%s' "$json" | jq -r '.workflow_runs[0].html_url')
        return 0
      fi
    else
      code=$(api_code)
      if [ "$2" != wait ] || [ "$code" = 401 ]; then
        die "Couldn't read GitHub's builds (HTTP $code)." "$(api_hint "$code")"
      fi
    fi
    tries=$((tries + 1))
    if [ "$2" != wait ] || [ "$tries" -ge 30 ]; then return 1; fi
    sleep 10
  done
}

poll_failed() { # a read of the build failed: stop on a refused token, say so after 3 in a row
  local code
  code=$(api_code)
  if [ "$code" = 401 ]; then
    die "Couldn't read the build from GitHub (HTTP 401)." "$(api_hint 401)" "The build goes on at GitHub: $RUN_URL"
  fi
  FAILS=$((FAILS + 1))
  if [ "$FAILS" -eq 3 ]; then
    info "Can't read the build from GitHub (HTTP $code); still trying. $(api_hint "$code")"
    info "Ctrl-C stops watching; the build goes on at GitHub."
  fi
}

watch_build() {
  local jobs run state waiting=false all_done asked=false
  PHASE=watching
  FAILS=0
  say ""
  say "${BOLD}GitHub's release build of $TAG:${OFF} $RUN_URL"
  : > "$WORK/seen"
  while :; do
    if ! jobs=$(api "repos/$REPO/actions/runs/$RUN_ID/jobs?per_page=50"); then
      poll_failed
    else
      { printf '%s' "$jobs" | jq -r "$JOB_LINES" 2> /dev/null || true; } | while IFS= read -r line; do
        if ! grep -Fxq -- "$line" "$WORK/seen"; then
          printf '%s\n' "$line" >> "$WORK/seen"
          printf '  %s  %s\n' "$(date +%H:%M)" "$line"
        fi
      done
      waiting=$(printf '%s' "$jobs" | jq '[.jobs[] | select(.status == "waiting")] | length > 0' 2> /dev/null) || waiting=false
      all_done=$(printf '%s' "$jobs" | jq '[.jobs[] | select(.status != "completed")] | length == 0' 2> /dev/null) || all_done=false
      state=''
      if [ "$all_done" != true ]; then
        FAILS=0
      elif run=$(api "repos/$REPO/actions/runs/$RUN_ID"); then
        FAILS=0
        state=$(printf '%s' "$run" | jq -r '"\(.status) \(.conclusion // "")"' 2> /dev/null) || state=''
      else
        poll_failed
      fi
      if [ -n "$state" ]; then
        case $state in
          "completed success")
            report_success
            return 0
            ;;
          completed*)
            report_failure "$jobs"
            return 1
            ;;
          waiting*) waiting=true ;;
        esac
      fi
      if [ "$waiting" = true ] && ! $asked; then
        asked=true
        info "       Waiting for your approval: on the run page click \"Review deployments\", tick \"release\", then \"Approve and deploy\"."
        open_url "$RUN_URL"
      fi
    fi
    if [ "$waiting" = true ]; then sleep "$POLL_APPROVAL"; else sleep "$POLL"; fi
  done
}

report_success() {
  local published url releases="https://github.com/$REPO/releases"
  say ""
  # GitHub only shows published releases here, never drafts.
  if published=$(api "repos/$REPO/releases/tags/$TAG"); then
    url=$(printf '%s' "$published" | jq -r '.html_url // empty')
    say "${GREEN}✓ $TAG is built, and its release is already published:${OFF} ${url:-$releases}"
    notify "$TAG is built"
    return
  fi
  say "${GREEN}✓ $TAG is built. The draft release is waiting for you:${OFF} $releases"
  say "  1. Check that its Assets list the 4 APKs and SHA256SUMS.txt, then click \"Publish release\"."
  say "  2. Play Store: download \"play-bundle\" (the AAB) from $RUN_URL"
  say "     and upload it in Play Console."
  say "  3. Download \"symbols\" from the same page and keep it: you need it to read crash"
  say "     reports, and GitHub deletes it after 90 days."
  open_url "$releases"
  notify "$TAG is ready: check the draft and click Publish"
}

report_failure() { # report_failure JOBS_JSON
  say ""
  say "${RED}✗ The GitHub build of $TAG failed:${OFF} $RUN_URL"
  {
    printf '%s' "$1" | jq -r '.jobs[]
      | select(.conclusion == "failure" or .conclusion == "cancelled" or .conclusion == "timed_out"
          or .conclusion == "action_required" or .conclusion == "startup_failure")
      | [.id, .name, ([.steps[]? | select(.conclusion == "failure") | .name] | join(", "))] | @tsv' 2> /dev/null || true
  } | while IFS=$'\t' read -r id name steps; do
    say "  $name${steps:+, at step: $steps}"
    api "repos/$REPO/check-runs/$id/annotations" \
      | jq -r '.[] | select(.annotation_level == "failure" or .annotation_level == "warning") | "    \(.message)"' 2> /dev/null || true
  done
  say ""
  say "What now?"
  say "  • A GitHub setting (a secret, the environment, the approval): fix it on GitHub, click"
  say "    \"Re-run failed jobs\" on the run page, then follow it with: ./release.sh --watch $TAG"
  say "  • The code: fix it and run ./release.sh again. That releases the next version,"
  say "    because $TAG is used now."
  notify "The build of $TAG failed"
}

watch_only() {
  local newest
  init_api
  git fetch --quiet --tags origin 2> /dev/null || true
  TAG=$WATCH_TAG
  if [ -z "$TAG" ]; then
    newest=$(newest_release)
    [ -n "$newest" ] || die "There's no release tag to follow yet."
    TAG=v$newest
  fi
  find_run "branch=$TAG" nowait || die "GitHub has no Release build for $TAG." \
    "All builds: https://github.com/$REPO/actions/workflows/$WORKFLOW"
  watch_build
}

# --- Main --------------------------------------------------------------------

# shellcheck disable=SC2329 # the EXIT trap
on_exit() {
  local status=$?
  if $TEMP_ENV; then rm -f .env; fi
  if $STASHED; then
    printf '%s\n' "Your uncommitted changes are safe in git's stash. Get them back with: git stash pop" >&2
  fi
  rm -rf "$WORK"
  exit "$status"
}

# shellcheck disable=SC2329 # the INT trap
on_int() {
  trap - INT
  printf '\n'
  case $PHASE in
    watching)
      say "Stopped watching. The build goes on at GitHub: $RUN_URL"
      say "Follow it again with: ./release.sh --watch $TAG"
      ;;
    committed)
      if pushed_anyway; then
        say "Stopped after pushing. Follow the build with: ./release.sh --watch $TAG"
      else
        undo_release
        say "Stopped. The release commit and tag were undone; nothing was pushed."
      fi
      ;;
    pushed) say "Stopped. Follow the build with: ./release.sh --watch $TAG" ;;
    *) say "Stopped. Nothing was committed or pushed." ;;
  esac
  exit 130
}

main() {
  parse_args "$@"
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/release.XXXXXX")
  STASHED=false TEMP_ENV=false PHASE=checks HIST_REF=HEAD BEHIND=0 RELEASE_SHA='' RUN_URL='' TAG='' API_TOKEN='' POP_OUTPUT='' FAILS=0
  trap on_exit EXIT
  trap on_int INT
  preflight
  if $WATCH_ONLY; then
    watch_only
    return
  fi

  sync_with_github
  detect_flutter
  choose_version
  check_secrets "$({ git diff --name-only -z --diff-filter=d HEAD; git ls-files --others --exclude-standard -z; } | tr '\0' '\n')"
  show_plan
  if $DRY_RUN; then
    say ""
    say "Dry run: nothing was changed."
    return
  fi
  confirm

  write_version
  write_flutter_pin
  if [ ! -f .env ]; then
    cp .env.example .env
    TEMP_ENV=true
    info "No .env here, so the checks use a copy of .env.example (removed afterwards)."
  fi
  run_checks
  commit_tag_push

  if ! $WATCH; then
    say ""
    say "Not following the build (--no-watch). Follow it with: ./release.sh --watch $TAG"
    return
  fi
  init_api
  find_run "head_sha=$RELEASE_SHA" wait || die "GitHub hasn't started a Release build for $TAG." \
    "Check https://github.com/$REPO/actions"
  watch_build
}

# One compound command, so bash has read the whole file before the sync lets
# git replace it.
{
  main "$@"
  exit
}
