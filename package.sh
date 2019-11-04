#!/bin/bash
repo="https://github.com/OpenXRay/xray-16.git"
last_commit_file="./last.commit"
tg_bot_token="xxx"
tg_chat_id="@OpenXRayLinuxBuilds"

#tools

_curl() {
    docker run --rm appropriate/curl "$@"
}

_git() {
    docker run --rm alpine/git "$@"
}

_builder() {
    docker run --rm kamehb/openxray-builder "$@"
}

_linker() {
    docker run --rm kamehb/openxray-linker "$@"
}

appimagetool=$(mktemp)
_curl -L https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage > "$appimagetool"
chmod a+x "$appimagetool"

bot() {
    if [ "$1" = "sendFile" ]; then
        _curl -F chat_id=$tg_chat_id -F document=@"$2" https://api.telegram.org/bot$tg_bot_token/sendDocument "$@"
    else
        _curl -s -X POST https://api.telegram.org/bot$tg_bot_token/$1 -d chat_id=$tg_chat_id "$@"
    fi
}

get_last_commit() {
    hash=$(_git ls-remote "$repo" HEAD | awk '{ print $1}')
    echo ${hash::7}
}

get_local_commit() {
    cat "$last_commit_file" 2>/dev/null
}

set_local_commit() {
    echo "$1" > "$last_commit_file"
}

build() {
    echo > ./error.log
    _builder -v ./build:/opt/OpenXRay 2>./error.log
}

link() {
    echo > ./error.log
    _linker -v ./build:/xray-16 2>./error.log
}

package() {
    echo > ./error.log
    sudo chmod 777 dist build 2>./error.log
    "$appimagetool" build dist/OpenXRay+$1.AppImage 2>./error.log
}

error_log() {
    bot sendMessage --data-urlencode text="There was an error. Last what I seen was: \`\`\`$(cat error.log | tail -n20)\`\`\`" -d parse_mode=Markdown
}

while true; do
    last_commit=$(get_last_commit)
    if [ "$(get_local_commit)" != "$last_commit" ]; then
        set_local_commit $last_commit
        bot sendMessage -d text="Found new commit: $last_commit. Building..."
        if build; then
            bot sendMessage -d text="Attaching libs..."
            if link; then
                bot sendMessage -d text="Packaging..."
                if package $last_commit; then
                    bot sendFile dist/OpenXRay+$last_commit.AppImage -F text="Done successfully"
                else
                    error_log
                fi
            else
                error_log
            fi
        else
            error_log
        fi
        rm -rf dist build
    else
        sleep 1m
    fi
done
