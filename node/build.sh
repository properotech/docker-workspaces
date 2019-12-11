#!/usr/bin/env bash
# vim: et sr sw=4 ts=4 smartindent:
# helper script to generate label data for docker image during building
#
# docker_build will generate an image tagged :candidate
#
# It is a post-step to tag that appropriately and push to repo

BASE_TYPE="node"
GIT_SHA_LEN=8
IMG_TAG="${BASE_TYPE}-candidate"
DOCKERFILE=${DOCKERFILE:-Dockerfile}

base_img(){
    grep -Po '(?<=^FROM ).*' $DOCKERFILE
}

pull_base_img() {
    local img="$1"
    docker pull $img >/dev/null 2>&1 || return 1
}

apt_pkg_version() {
    local img="$1"
    local pkg="$2"

    cmd="apt-get update &>/dev/null ; apt-cache show $pkg"

    docker run -i --rm --user root $img bash -c "$cmd" \
    | grep -Po '(?<=^Version: )[-\d\.]+'
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
    [[ -z "$r" ]] && echo "ERROR: no rev to parse when finding branch? " >&2 && return 1
    [[ "$r" == "HEAD" ]] && r="from-a-tag"
    echo "$r"
}

git_path_to() {
    git ls-tree --name-only --full-name HEAD $1
}

img_name(){
    (
        set -o pipefail;
        grep -Po '(?<=[nN]ame=")[^"]+' $DOCKERFILE | head -n 1
    )
}

node_version() {
    local bi="$1"
    docker run -i --rm --user root $bi bash -c 'echo $NODE_VERSION'
}

yarn_version() {
    local bi="$1"
    docker run -i --rm --user root $bi bash -c 'echo $YARN_VERSION'
}

labels() {
    local ai av cv jv tv bb gu gs gb gt
    bi=$(base_img) || return 1
    pull_base_img $bi || return 1

    nv=$(node_version $bi) || return 1
    yv=$(yarn_version $bi) || return 1
    bb=$(built_by) || return 1
    gu=$(git_uri) || return 1
    gs=$(git_sha) || return 1
    gb=$(git_branch) || return 1
    gt=$(git describe 2>/dev/null || echo "no-git-tag")
    gp=$(git_path_to $DOCKERFILE)

    cat<<EOM
    --label node.node_version=$nv
    --label node.yarn_version=$yv
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

docker_build(){

    echo "... getting labels"
    labels=$(labels) || return 1
    echo "... getting img name"
    n=$(img_name) || return 1

    echo "INFO: adding these labels:"
    echo "$labels"
    echo "INFO: building $n:$IMG_TAG"
    docker build --force-rm $labels -t $n:$IMG_TAG .
}

docker_build
