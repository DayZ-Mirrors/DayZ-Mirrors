#!/bin/bash

# full github url
GITHUB_REPO_URL="https://${access_token}@github.com/${GITHUB_REPOSITORY_OWNER}/${github_repo}"

# break down branch list
ALL_BRANCHES=(${branch//,/ })
BRANCHES=()

# disable early exit during branch selection but keep pipefail to skip pipestatus
set +e -o pipefail

for branch_name in "${ALL_BRANCHES[@]}"; do
    # fetch commit-checksums
    LOCAL_SHA=$(git ls-remote "${GITHUB_REPO_URL}" ${branch_name} | cut -f1)
    REMOTE_SHA=$(git ls-remote "${source_repo}" ${branch_name} | head -n1 | cut -f1)
    if (($? != 0)) || [[ "${REMOTE_SHA// /}" == "" ]]; then
        # error while getting remote status, log error and skip this branch
        >&2 echo "Could not get remote status for branch '${branch_name}', skipping branch."
        continue
    fi

    echo "Local sha: ${LOCAL_SHA} (${github_repo})"
    echo "Remote sha: ${REMOTE_SHA} (${source_repo})"

    # add to list if commits are not equal
    if [[ "${LOCAL_SHA}" != "${REMOTE_SHA}" ]]; then
        echo "Changes detected in '${branch_name}' branch."
        BRANCHES+=("${branch_name}")
    fi
done

# from now on do not tolerate any errors, enable fail fast
set -eo pipefail

# bail out with failure if list is empty
((${#BRANCHES[@]} > 0))

# clone (use first branch in cloning)
rm gh_repo -rf
git clone "${GITHUB_REPO_URL}" gh_repo || exit 1
cd gh_repo

# pull and push all branches
for branch_name in "${BRANCHES[@]}"; do
    echo "Updating branch '${branch_name}'"
    git checkout -b "${branch_name}"
    git pull "${source_repo}" "${branch_name}" || exit 1
    git push origin "${branch_name}" || exit 1
done
