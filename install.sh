# Copyright Contributors to the Open Cluster Management project
#!/usr/bin/env bash

# Clusteradm CLI location
: ${INSTALL_DIR:="/usr/local/bin"}

# sudo is required to copy binary to INSTALL_DIR for linux
: ${USE_SUDO:="false"}

# Http request CLI
HTTP_REQUEST_CLI=curl

# GitHub Organization and repo name to download release
GITHUB_ORG=open-cluster-management-io
GITHUB_REPO=clusteradm

# CLI filename
CLI_FILENAME=clusteradm

CLI_FILE="${INSTALL_DIR}/${CLI_FILENAME}"

getSystemInfo() {
    ARCH=$(uname -m)
    case $ARCH in
        armv7*) ARCH="arm";;
        aarch64) ARCH="arm64";;
        x86_64) ARCH="amd64";;
    esac

    OS=$(echo `uname`|tr '[:upper:]' '[:lower:]')

    # Most linux distro needs root permission to copy the file to /usr/local/bin
    if [[ "$OS" == "linux" || "$OS" == "darwin" ]] && [ "$INSTALL_DIR" == "/usr/local/bin" ]; then
        USE_SUDO="true"
    fi
}

verifySupported() {
    local supported=(darwin-amd64 linux-amd64 linux-arm64 windows-amd64)
    local current_osarch="${OS}-${ARCH}"

    for osarch in "${supported[@]}"; do
        if [ "$osarch" == "$current_osarch" ]; then
            echo "Your system is ${OS}_${ARCH}"
            return
        fi
    done

    echo "No prebuilt binary for ${current_osarch}"
    exit 1
}

checkHttpRequestCLI() {
    if type "curl" > /dev/null; then
        HTTP_REQUEST_CLI=curl
    elif type "wget" > /dev/null; then
        HTTP_REQUEST_CLI=wget
    else
        echo "Either curl or wget is required"
        exit 1
    fi
}

checkExisting() {
    if [ -f "$CLI_FILE" ]; then
        echo -e "\nclusteradm CLI is detected:"
        echo -e "Reinstalling clusteradm CLI - ${CLI_FILE}...\n"
    else
        echo -e "Installing clusteradm CLI...\n"
    fi
}

getLatestRelease() {
    local releaseUrl="https://api.github.com/repos/${GITHUB_ORG}/${GITHUB_REPO}/releases"
    local latest_release=""

    if [ "$HTTP_REQUEST_CLI" == "curl" ]; then
        latest_release=$(curl -s $releaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    else
        latest_release=$(wget -q --header="Accept: application/json" -O - $releaseUrl | grep \"tag_name\" | grep -v rc | awk 'NR==1{print $2}' |  sed -n 's/\"\(.*\)\",/\1/p')
    fi

    ret_val=$latest_release
}

downloadFile() {
    LATEST_RELEASE_TAG=$1

    CLI_ARTIFACT="${CLI_FILENAME}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${CLI_ARTIFACT}"

    # Create the temp directory
    TMP_ROOT=$(mktemp -dt clusteradm-install-XXXXXX)
    ARTIFACT_TMP_FILE="$TMP_ROOT/$CLI_ARTIFACT"

    echo "Downloading $DOWNLOAD_URL ..."
    if [ "$HTTP_REQUEST_CLI" == "curl" ]; then
        curl -SsL "$DOWNLOAD_URL" -o "$ARTIFACT_TMP_FILE"
    else
        wget -q -O "$ARTIFACT_TMP_FILE" "$DOWNLOAD_URL"
    fi

    if [ ! -f "$ARTIFACT_TMP_FILE" ]; then
        echo "failed to download $DOWNLOAD_URL ..."
        exit 1
    fi
}

isReleaseAvailable() {
    LATEST_RELEASE_TAG=$1

    CLI_ARTIFACT="${CLI_FILENAME}_${OS}_${ARCH}.tar.gz"
    DOWNLOAD_BASE="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}/releases/download"
    DOWNLOAD_URL="${DOWNLOAD_BASE}/${LATEST_RELEASE_TAG}/${CLI_ARTIFACT}"

    if [ "$HTTP_REQUEST_CLI" == "curl" ]; then
        httpstatus=$(curl -sSLI -o /dev/null -w "%{http_code}" "$DOWNLOAD_URL")
        if [ "$httpstatus" == "200" ]; then
            return 0
        fi
    else
        wget -q --spider "$DOWNLOAD_URL"
        exitstatus=$?
        if [ $exitstatus -eq 0 ]; then
            return 0
        fi
    fi
    return 1
}

installFile() {
    tar xf "$ARTIFACT_TMP_FILE" -C "$TMP_ROOT"
    local tmp_root_cli="$TMP_ROOT/$CLI_FILENAME"

    if [ ! -f "$tmp_root_cli" ]; then
        echo "Failed to unpack clusteradm CLI executable."
        exit 1
    fi

    chmod o+x $tmp_root_cli
    cp "$tmp_root_cli" "$INSTALL_DIR"

    if [ -f "$CLI_FILE" ]; then
        echo "$CLI_FILENAME installed into $INSTALL_DIR successfully."
    else
        echo "Failed to install $CLI_FILENAME"
        exit 1
    fi
}

fail_trap() {
    result=$?
    if [ "$result" != "0" ]; then
        echo "Failed to install clusteradm CLI"
        echo "For support, go to https://open-cluster-management.io/"
    fi
    cleanup
    exit $result
}

cleanup() {
    if [[ -d "${TMP_ROOT:-}" ]]; then
        rm -rf "$TMP_ROOT"
    fi
}

installCompleted() {
    echo -e "\nTo get started with clusteradm, please visit https://open-cluster-management.io/getting-started/"
}

# -----------------------------------------------------------------------------
# main
# -----------------------------------------------------------------------------
trap "fail_trap" EXIT

getSystemInfo
checkHttpRequestCLI

if [ -z "$1" ]; then
    echo "Getting the latest clusteradm CLI..."
    getLatestRelease
else
    ret_val=v$1
fi

verifySupported $ret_val
checkExisting

echo "Installing $ret_val OCM clusteradm CLI..."

downloadFile $ret_val
installFile
cleanup

installCompleted