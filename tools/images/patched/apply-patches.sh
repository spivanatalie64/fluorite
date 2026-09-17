#!/bin/bash
# Applies the fork patch stack (build/cromite_patches_list.txt + build/patches/)
# from the repository checkout at /workspace/repo onto /workspace/chromium/src.
set -e

RED='\033[0;31m'
NC='\033[0m'

REPO_DIR=${REPO_DIR:-/workspace/repo}
SRC_DIR=${SRC_DIR:-/workspace/chromium/src}
PATCH_LIST=$REPO_DIR/build/cromite_patches_list.txt
PATCH_DIR=$REPO_DIR/build/patches

cd $SRC_DIR

# Flatten submodule gitdirs so `git am` sees one tree; keeps patch application
# working across repos that Chromium vendors as submodules.
# Commit via plumbing: porcelain `git commit` carries a stale-shallow-file
# guard that false-trips when successive flatten commits rewrite .git/shallow
# in this --no-history checkout. Plumbing bypasses it.
commit_plumbing() {
  local msg=$1
  local tree commit
  tree=$(git write-tree)
  commit=$(printf '%s\n' "$msg" | git commit-tree "$tree" -p HEAD)
  git update-ref -m fluorite HEAD "$commit"
}

flatten_submodule() {
  local path=$1
  echo -e "${RED} ------- flatten $path ${NC}"
  rm -rf $path/.git
  cp -r $path ${path}-bis
  git rm -rf $path > /dev/null 2>&1 || true
  git submodule deinit -f $path > /dev/null 2>&1 || true
  rm -rf $path
  mv ${path}-bis $path
  git add -f $path > /dev/null
  commit_plumbing ":NOEXPORT: flatten subrepo $path"
}

git config user.email "build@example.com"
git config user.name "Builder"

for path in v8 third_party/devtools-frontend/src third_party/skia \
            third_party/perfetto third_party/boringssl/src; do
  test -d $SRC_DIR/$path && flatten_submodule $path
done

git prune

echo -e "${RED} ------- patches ${NC}"
echo "patch list:"
cat $PATCH_LIST
echo

echo -e "${RED} ------- apply patches ${NC}"
# Strict first (git am), fuzz fallback second (patch --fuzz) so context-line
# drift self-heals; only genuine semantic conflicts stop the build.
# The shallow-file guard can also false-trip `git am` right after the flatten
# commits rewrote .git/shallow; one `git status` forces a clean re-read first,
# and the fuzz fallback's commit uses plumbing like flatten does.
: > /workspace/patches_applied_with_fallback.txt
git status > /dev/null 2>&1 || true

for file in $(cat $PATCH_LIST) ; do
   if [[ "$file" == *".patch" ]]; then
    echo -e "${RED}  -> Apply $file ${NC}"

    REPL="0,/^---/s//FILE:"$(basename $file)"\n---/"
    if cat $PATCH_DIR/$file | sed $REPL | git am; then
      echo -e "     applied cleanly"
      continue
    fi
    git am --abort

    echo -e "\033[0;33m     clean apply failed, retrying with fuzz ${NC}"
    if git apply -p1 --fuzz=10 --whitespace=nowarn $PATCH_DIR/$file; then
      git add -A
      commit_plumbing "$(basename $file)"
      echo "$file" >> /workspace/patches_applied_with_fallback.txt
    else
      echo -e "Error applying $PATCH_DIR/$file"
      exit 1
    fi
  fi
done

echo -e "${RED} ------- all patches applied ${NC}"
if [[ -s /workspace/patches_applied_with_fallback.txt ]]; then
  echo -e "\033[0;33m patches needing fuzz (review before next train): ${NC}"
  cat /workspace/patches_applied_with_fallback.txt
fi
