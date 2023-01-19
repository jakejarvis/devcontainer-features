#!/usr/bin/env bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
VERSION=${VERSION:-"latest"}
SKIP_SETUP="${SKIPSETUP:="false"}"
INSTALL_GLOBAL_NODE="${INSTALLGLOBALNODE-:"false"}"

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Ensure that login shells get the correct path if the user updated the PATH using ENV.
rm -f /etc/profile.d/00-restore-env.sh
echo "export PATH=${PATH//$(sh -lc 'echo $PATH')/\$PATH}" > /etc/profile.d/00-restore-env.sh
chmod +x /etc/profile.d/00-restore-env.sh

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME="${CURRENT_USER}"
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Compares given semvers to determine if $1 is newer than $2
version_greater_equal() {
    printf '%s\n%s\n' "$2" "$1" | sort --check=quiet --version-sort
}

###########################################
# Start volta installation
###########################################

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl ca-certificates

# Skip volta setup if SKIP_SETUP is true
INSTALLER_ARGS="--version ${VERSION}"
if [ "${SKIP_SETUP}" = "true" ]; then
    INSTALLER_ARGS+=" --skip-setup"
fi

# Install volta
if type volta > /dev/null 2>&1; then
    echo "Volta already installed."
elif [ "${VERSION}" = "latest" ] || version_greater_equal "${VERSION}" 1.1.0; then
    su "${USERNAME}" -c "curl -sSL https://get.volta.sh | bash -s -- ${INSTALLER_ARGS}"
else
    # https://docs.volta.sh/advanced/installers#installing-old-versions
    su "${USERNAME}" -c "curl -sSL https://raw.githubusercontent.com/volta-cli/volta/8f2074f423c65405dfba9858d9bcf393c38ffb45/dev/unix/volta-install.sh | bash -s -- ${INSTALLER_ARGS}"
fi

if [ "${INSTALL_GLOBAL_NODE}" = "true" ]; then
    su "${USERNAME}" -c "volta install --verbose node@lts npm@latest yarn@latest"
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
