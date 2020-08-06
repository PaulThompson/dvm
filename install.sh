#!/usr/bin/env bash

get_rc_file() {
  shell=${SHELL##*/}

  if [ "$shell" == "bash" ]
  then
    rc_file="$HOME/.bashrc"
  elif [ "$shell" == "zsh" ]
  then
    rc_file="$HOME/.zshrc"
  else
    rc_file="$HOME/.profile"
  fi
}

add_nvm_into_rc_file() {
  get_rc_file

  defined=$(grep DVM_DIR < "$rc_file")

  if [ -n "$defined" ]
  then
    return
  fi

  echo "
# Deno Version Manager
export DVM_DIR=\"\$HOME/.dvm\"
export DVM_BIN=\"\$DVM_DIR/bin\"
export PATH=\"\$PATH:\$DVM_BIN\"
[ -f \"\$DVM_DIR/dvm.sh\" ] && alias dvm=\"\$DVM_DIR/dvm.sh\"
[ -f \"\$DVM_DIR/bash_completion\" ] && . \"\$DVM_DIR/bash_completion\"
" >> "$rc_file"
}

get_latest_version() {
  local request_url
  local response

  case "$DVM_SOURCE" in
  gitee)
    request_url="https://gitee.com/api/v5/repos/ghosind/dvm/releases/latest"
    ;;
  github|*)
    request_url="https://api.github.com/repos/ghosind/dvm/releases/latest"
    ;;
  esac

  if [ -x "$(command -v wget)" ]
  then
    response=$(wget -O- "$request_url" -nv)
  elif [ -x "$(command -v curl)" ]
  then
    response=$(curl -s "$request_url")
  else
    echo "wget or curl is required."
    exit 1
  fi

  # shellcheck disable=SC2181
  if [ "$?" != "0" ]
  then
    echo "failed to get the latest DVM version."
    exit 1
  fi

  DVM_LATEST_VERSION=$(echo "$response" | grep tag_name | cut -d '"' -f 4)
}

download_latest_version() {
  DVM_TMP_DIR=$(mktemp -d)

  archive_url="https://github.com/ghosind/dvm/archive/$DVM_LATEST_VERSION.tar.gz"

  if [ -x "$(command -v wget)" ]
  then
    wget "$archive_url" \
        -O "$DVM_TMP_DIR/dvm.tar.gz"
  else
    curl -LJ "$archive_url" \
        -o "$DVM_TMP_DIR/dvm.tar.gz"
  fi

  # shellcheck disable=SC2181
  if [ "$?" != "0" ]
  then
    echo "failed to download DVM."
    exit 1
  fi
}

install_latest_version() {
  local version
  version=$(echo "$DVM_LATEST_VERSION" | cut -d "v" -f 2)

  tar -xzvf "$DVM_TMP_DIR/dvm.tar.gz" -C "$DVM_TMP_DIR"
  cp -R "$DVM_TMP_DIR/dvm-$version/"* "$DVM_DIR"
}

set_dvm_dir() {
  DVM_DIR="$HOME/.dvm"

  if [ ! -d "$DVM_DIR" ]
  then
    mkdir -p "$DVM_DIR"
  fi
}

install_local_version() {
  cp -R "$script_dir/"* "$DVM_DIR"
}

install_dvm() {
  set_dvm_dir

  script_dir=${0%/*}

  if [ -f "$script_dir/dvm.sh" ]
  then
    install_local_version
  else
    get_latest_version
    download_latest_version
    install_latest_version
  fi

  add_nvm_into_rc_file

  echo "DVM has been installed, please restart your terminal or run \`source $rc_file\` to apply changes."
}

if [ "$1" = "--gitee" ]
then
  DVM_SOURCE="gitee"
else
  DVM_SOURCE="github"
fi

install_dvm
