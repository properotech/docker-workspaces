# vim: et sr sw=4 ts=4 smartindent:
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

# On a pull-request event $GIT_SHA refers to the merge commit pointing to the
# PR not the last pushed commit. However, the check build url uses that
# last pushed commit ref.
github_api::last_commit_in_merge() {
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

img_name(){
    [[ ! -z "$IMG_NAME" ]] && echo "$IMG_NAME" && return 0

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

