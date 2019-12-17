#!/usr/bin/env bash
# vim: et sr sw=4 ts=4 smartindent:
# helper script to generate label data for docker image during building
#
# docker_build will generate an image tagged :candidate
#
# It is a post-step to tag that appropriately and push to repo

GIT_SHA_LEN=8
IMG_TAG="${IMG_TAG:-candidate}"
DOCKERFILE=${DOCKERFILE:-Dockerfile}
SHELL_IN_CON=${SHELL_IN_CON:-bash}
WDIR=${WDIR:-$IMG_TYPE}

cd_wdir() {
    local wdir="${WDIR:-.}"
    if cd $wdir &>/dev/null
    then
        return 0
    else
        echo &>2 "ERROR $0: could not cd to $WDIR"
        return 1
    fi
}

base_img(){
    if declare -f -F $IMG_TYPE::base_img &>/dev/null
    then
        $IMG_TYPE::base_img || return 1
    else
        default::base_img || return 1
    fi
}

default::base_img() {
    (
        set -o pipefail
        grep -Po '(?<=^FROM ).*' $DOCKERFILE | head -n 1
    )
}

pull_base_img() {
    local img="$1"
    if docker pull $img >/dev/null 2>&1
    then
        return 0
    else
        echo >&2 "ERROR $0: unable to pull base img $img"
        return 1
    fi
}

github_actions::build_url() {
    local csid=""

    [[ "$GITHUB_ACTIONS" == "true" ]] || return 0   # return if not run by
                                                    # github actions
    local who="${GITHUB_ACTOR}"
    local org_repo="${GITHUB_REPOSITORY}"
    local sha=""

    sha="$GITHUB_SHA"
    if [[ "$GITHUB_EVENT_NAME" == "pull_request" ]]; then
        sha=$(github_api::last_commit_in_pr "$org_repo" "${GITHUB_SHA}")
        if [[ $? -ne 0 ]] || [[ -z "$sha" ]] || [[ "$sha" == "null" ]] ; then
            echo >&2 "ERROR $0: failed to get last commit in pr"
            return 1
        fi
    fi

    csid=$(github_api::check_suite_id "$org_repo" "$sha")
    if [[ $? -ne 0 ]] || [[ -z "$csid" ]] || [[ "$csid" == "null" ]] ; then
        echo >&2 "ERROR $0: failed to get github's check_suite_id"
        return 1
    fi

    local build_url="${who}@https://github.com/${org_repo}/commit/$sha/checks?check_suite_id=$csid"
    export BUILD_URL="$build_url"

}

# On a pull-request event $GIT_SHA refers to the merge commit pointing to the
# PR not the last pushed commit. However, the check build url uses that
# last pushed commit ref.
github_api::last_commit_in_pr() {
    local org_repo="$1"
    local sha="$2"

    local auth_header="Authorization: bearer $GIT_TOKEN"
    local accept_header="Accept: application/vnd.github.antiope-preview+json"

    (
        set -o pipefail
        curl -sS --retry 3 --retry-delay 1 --retry-max-time 10 \
            --header "$accept_header" --header "$auth_header" \
            "https://api.github.com/repos/$org_repo/commits/$sha" \
        | jq -r '.parents[1].sha' || return 1
    )
}

github_api::check_suite_id() {
    local org_repo="$1"
    local sha="$2"

    local app_id="15368" # this is the github internal id for github actions run as a github check
    local auth_header="Authorization: bearer $GIT_TOKEN"
    local accept_header="Accept: application/vnd.github.antiope-preview+json"
    (
        set -o pipefail
        curl -sS --retry 3 --retry-delay 1 --retry-max-time 10 \
            --header "$accept_header" --header "$auth_header" \
            "https://api.github.com/repos/$org_repo/commits/$sha/check-suites?app_id=$app_id" \
        | jq -r '.check_suites[0].id' || return 1
    )
        
}

built_by() {
    local user="--UNKNOWN--"
    if [[ ! -z "${BUILD_URL}" ]]; then
        user="${BUILD_URL}"
    elif [[ ! -z "${AWS_PROFILE}" ]] || [[ ! -z "${AWS_ACCESS_KEY_ID}" ]]; then
        user="$(aws iam get-user --query 'User.UserName' --output text)@$HOSTNAME"
    else
        user="$(git config --get user.name)@$HOSTNAME"
    fi
    echo "$user" | sed -e 's/ /--/g'
}

git_uri(){
    git config remote.origin.url || echo 'no-remote'
}

git_sha(){
    git rev-parse --short=${GIT_SHA_LEN} --verify HEAD
}

git_branch(){
    r=$(git rev-parse --abbrev-ref HEAD)
    [[ -z "$r" ]] && echo "ERROR $0: no rev to parse when finding branch? " >&2 && return 1
    [[ "$r" == "HEAD" ]] && r="not-a-branch"
    echo "$r"
}

git_path_to() {
    git ls-tree --name-only --full-name HEAD $1
}

img_name(){
    if declare -f -F $IMG_TYPE::img_name &>/dev/null
    then
        $IMG_TYPE::img_name || return 1
    else
        default::img_name || return 1
    fi
}

default::img_name() {
    (
        set -o pipefail;
        grep -Po '(?<=[nN]ame=")[^"]+' $DOCKERFILE | head -n 1
    )
}

labels() {
    if declare -f -F $IMG_TYPE::labels &>/dev/null
    then
        $IMG_TYPE::labels || return 1
    else
        default::labels || return 1
    fi
}

default::labels() {
    bi=$(base_img) || return 1
    pull_base_img $bi || return 1

    bb=$(built_by) || return 1
    gu=$(git_uri) || return 1
    gs=$(git_sha) || return 1
    gb=$(git_branch) || return 1
    gt=$(git describe 2>/dev/null || echo "no-git-tag")
    gp=$(git_path_to $DOCKERFILE)

    cat<<EOM
    --label version=$(date +'%Y%m%d%H%M%S')
    --label propero.build_git_path.dockerfile=$gp
    --label propero.build_git_uri=$gu
    --label propero.build_git_sha=$gs
    --label propero.build_git_branch=$gb
    --label propero.build_git_tag=$gt
    --label propero.built_by=$bb
    --label propero.from_image=$bi
EOM
}

source_build_libs() {
    if [[ -r "libs.sh" ]]; then
        if . libs.sh
        then
            echo "INFO $0: sourcing $(pwd)/libs.sh"
        else
            echo >&2 "ERROR $0: could not source $(pwd)/libs.sh"
            return 1
        fi
    fi
    return 0
}

docker_build(){
    (
        cd_wdir || return 1
        source_build_libs || return 1
        github_actions::build_url || return 1

        echo "... getting labels"
        labels=$(labels) || return 1
        echo "... getting img name"
        n=$(img_name) || return 1

        echo "INFO $0: adding these labels:"
        echo "$labels"
        echo "INFO $0: building $n:$IMG_TAG"
        docker build ${DOCKER_BUILD_ARGS[@]} \
            --force-rm $labels -t $n:$IMG_TAG -f $DOCKERFILE .
    )
}

[[ -z $GIT_TOKEN ]] && echo >&2 "ERROR $0: set GIT_TOKEN in env" && exit 1
docker_build
