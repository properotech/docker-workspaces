# vim: et sr sw=4 ts=4 smartindent syntax=sh:
# node/libs.sh
#

export DOCKER_BUILD_ARGS=(
    --build-arg NODE_MAJOR_VERSION
)

node::labels() {
    bi=$(base_img) || return 1
    default_labels="$(default::labels)"
    if [[ $? -ne 0 ]] || [[ -z "$default_labels" ]]; then
        return 1
    fi

    nv=$(node_version $bi) || return 1
    yv=$(yarn_version $bi) || return 1

cat <<EOM
    --label node.node_version=$nv
    --label node.yarn_version=$yv
    $default_labels
EOM
}

node::base_img() {
    line=$(default::base_img)
    eval "echo \"$line\""
}

node::img_name() {
    line=$(default::img_name)
    eval "echo \"$line\""
}

node_version() {
    local bi="$1"
    docker run -i --rm --user root $bi $SHELL_IN_CON -c 'echo $NODE_VERSION'
}

yarn_version() {
    local bi="$1"
    docker run -i --rm --user root $bi $SHELL_IN_CON -c 'echo $YARN_VERSION'
}

