#!/bin/sh
set -eu

print_usage() {
    cat <<'USAGE'
Usage: install-pulse.sh [OPTIONS] [VERSION]

Installs Pulse from the cherries-works/pulse GitHub releases.

Arguments:
  [VERSION]               Version to install, e.g. 0.6.3 or v0.6.3
                          (default: latest release)

Options:
  -v, --version VERSION   Version to install (same as the positional argument)
  -h, --help              Show this help and exit

Environment:
  PULSE_INSTALL_ROOT   Where versions are installed
                       (default: ~/.cherries-works/pulse/installations)
  PULSE_BIN_DIR        Where the symlinks are created (default: ~/.local/bin)
USAGE
}

print_banner() {
    if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
        cols=$(tput cols 2>/dev/null || echo 0)
    else
        cols=0
    fi

    if [ "$cols" -ge 85 ]; then
        cat <<'BANNER'
 cherries.works

 Installing Pulse...
 Hang tight, this will only take a minute.

                                  -------------------
                                  -------------------
                                  -------------------
                                  -----         ----------
                                  -----         ----------
                                  -----         ----------
                                  -----
                                  -----
                                  -----
                                  -----
                        **********-----**********
                        **********-----**********
                   ***************-----**************
                   ***************-----**************
                   **********************************
                   **********************************
                   ********************     *********
                   ********************     *********
                   ********************     *********
                   **********************************
                   **********************************
                        *************************
                        *************************

BANNER
    else
        printf '\ncherries.works\n\nInstalling Pulse...\nHang tight, this will only take a minute.\n\n'
    fi
}

REPO="cherries-works/pulse"
INSTALL_ROOT="${PULSE_INSTALL_ROOT:-${HOME:?HOME is not set}/.cherries-works/pulse/installations}"
BIN_DIR="${PULSE_BIN_DIR:-${HOME:?HOME is not set}/.local/bin}"
BINARY_NAME="pulse"

say() {
    printf 'Pulse: %s\n' "$*"
}

die() {
    printf 'Pulse: error: %s\n' "$*" >&2
    exit 1
}

# Safety fences: reject paths that must never be written to or removed.
check_safe_path() {
    check_path="$1"
    check_label="${2:-path}"

    case "$check_path" in
        ''|'.'|'..')
            die "Internal error: $check_label is empty or relative."
            ;;
    esac

    case "$check_path" in
        /*) ;;
        *) die "Internal error: $check_label is not an absolute path: $check_path" ;;
    esac

    case "$check_path" in
        /|/bin|/boot|/dev|/etc|/home|/lib|/lib64|/media|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var)
            die "Refusing unsafe $check_label at the filesystem root: $check_path"
            ;;
        *..*)
            die "Refusing unsafe $check_label containing '..': $check_path"
            ;;
    esac
}

# rm -rf only happens here, behind the guard. Optionally the target is
# verified to reside inside a given directory (e.g. INSTALL_ROOT).
remove_dir() {
    remove_path="$1"
    confine_to="${2:-}"

    check_safe_path "$remove_path" "directory to remove"

    if [ -n "$confine_to" ]; then
        case "$remove_path" in
            "$confine_to"/*)
                ;;
            *)
                die "Refusing to remove a path outside $confine_to: $remove_path"
                ;;
        esac
    fi

    rm -rf "$remove_path"
}

install_symlink() {
    link_path="$1"
    target="$2"

    if [ -d "$link_path" ] && [ ! -L "$link_path" ]; then
        die "Refusing to replace directory: $link_path"
    fi

    rm -f "$link_path" ||
        die "Could not remove existing file: $link_path"

    ln -s "$target" "$link_path" ||
        die "Could not create symlink: $link_path"
}

# Normalize user-provided version input ("0.6.3" or "v0.6.3") to a
# release tag ("v0.6.3") and reject anything unusable in a URL or path.
normalize_version() {
    raw="$1"
    [ -n "$raw" ] ||
        die "Empty version. Use e.g. 0.6.3 or v0.6.3."

    body=${raw#v}

    case "$body" in
        ''|'.'*'.'|[!A-Za-z0-9._-]*|*[!A-Za-z0-9._-]|'.'|'..')
            die "Invalid version: $raw"
            ;;
    esac

    case "$body" in
        [0-9]*) ;;
        *) die "Invalid version: $raw" ;;
    esac

    printf 'v%s\n' "$body"
}

check_safe_path "$HOME" "HOME directory"
check_safe_path "$INSTALL_ROOT" "installations directory"
check_safe_path "$BIN_DIR" "bin directory"

WANT_TAG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --help|-h)
            print_usage
            exit 0
            ;;
        --version=*)
            [ -z "$WANT_TAG" ] ||
                die "Version specified more than once."
            WANT_TAG=$(normalize_version "${1#--version=}")
            ;;
        --version|-v)
            [ $# -ge 2 ] ||
                die "Option $1 requires a version, e.g. $1 0.6.3"
            [ -z "$WANT_TAG" ] ||
                die "Version specified more than once."
            WANT_TAG=$(normalize_version "$2")
            shift
            ;;
        [!-]*)
            [ -z "$WANT_TAG" ] ||
                die "Version specified more than once."
            [ $# -eq 1 ] ||
                die "Unexpected extra argument: $2"
            WANT_TAG=$(normalize_version "$1")
            ;;
        *)
            die "Unknown option: $1 (see --help)"
            ;;
    esac
    shift
done

print_banner

for cmd in uname mktemp mkdir chmod mv rm cp ln tar grep awk; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command not found: $cmd"
done

if command -v curl >/dev/null 2>&1; then
    download() {
        curl --fail --silent --show-error --location \
            --retry 2 --connect-timeout 10 "$1" --output "$2"
    }
elif command -v wget >/dev/null 2>&1; then
    download() {
        wget -q "$1" -O "$2"
    }
else
    die "Install curl or wget first."
fi

[ "$(uname -s)" = "Linux" ] ||
    die "Pulse currently supports Linux only."

case "$(uname -m)" in
    x86_64|amd64)
        ARCH="x86_64"
        ;;
    aarch64|arm64)
        ARCH="aarch64"
        ;;
    *)
        die "Unsupported architecture: $(uname -m)"
        ;;
esac

ASSET="pulse_Linux_${ARCH}.tar.gz"

if [ -n "$WANT_TAG" ]; then
    BASE_URL="https://github.com/${REPO}/releases/download/${WANT_TAG}"
else
    BASE_URL="https://github.com/${REPO}/releases/latest/download"
fi

if command -v sha256sum >/dev/null 2>&1; then
    CHECKSUM_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
    CHECKSUM_CMD="shasum"
else
    die "Install sha256sum or shasum first."
fi

TMP_DIR=$(mktemp -d) ||
    die "Could not create temporary directory."

STAGED=""

cleanup() {
    if [ -n "$STAGED" ]; then
        remove_dir "$STAGED" "$INSTALL_ROOT"
    fi
    remove_dir "$TMP_DIR"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

say "Downloading Pulse for Linux/$ARCH..."

download "$BASE_URL/$ASSET" "$TMP_DIR/$ASSET" ||
    die "Download failed: $ASSET${WANT_TAG:+" for $WANT_TAG (does that version exist?)"}"

download "$BASE_URL/checksums.txt" "$TMP_DIR/checksums.txt" ||
    die "Could not download release checksums."

EXPECTED=$(awk -v name="$ASSET" '
    $2 == name || $2 == "*" name ||
    $2 == "release/" name || $2 == "*release/" name {
        print $1
        found++
    }
    END {
        if (found != 1) exit 1
    }
' "$TMP_DIR/checksums.txt") ||
    die "Missing or ambiguous checksum for $ASSET."

case "$EXPECTED" in
    *[!0123456789abcdefABCDEF]*|'')
        die "Invalid checksum in release manifest."
        ;;
esac

[ "${#EXPECTED}" -eq 64 ] ||
    die "Invalid SHA-256 checksum length."

if [ "$CHECKSUM_CMD" = "sha256sum" ]; then
    ACTUAL=$(sha256sum "$TMP_DIR/$ASSET" | awk '{print $1}')
else
    ACTUAL=$(shasum -a 256 "$TMP_DIR/$ASSET" | awk '{print $1}')
fi

[ "$EXPECTED" = "$ACTUAL" ] ||
    die "Checksum verification failed. Refusing to install."

if [ -n "$WANT_TAG" ]; then
    TAG="$WANT_TAG"
else
    say "Resolving latest release version..."

    if command -v curl >/dev/null 2>&1; then
        URL=$(curl --fail --silent --show-error --location \
            --retry 2 --connect-timeout 10 \
            --output /dev/null --write-out '%{url_effective}' \
            "https://github.com/${REPO}/releases/latest") || URL=""
    elif command -v wget >/dev/null 2>&1; then
        URL=$(wget --server-response --spider "https://github.com/${REPO}/releases/latest" 2>&1 |
            grep -m1 -o "${REPO}/releases/tag/.*") || URL=""
    fi

    if [ -n "${URL:-}" ]; then
        TAG=${URL##*/}
    fi

    case "${TAG:-}" in
        ''|'.'*'.'|[!A-Za-z0-9._-]*|*[!A-Za-z0-9._-]|'.'|'..')
            say "Could not determine the release version; using 'latest'."
            TAG="latest"
            ;;
    esac
fi

mkdir -p "$TMP_DIR/extracted"

tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR/extracted" ||
    die "Could not extract release archive."

[ -f "$TMP_DIR/extracted/pulse" ] ||
    die "Archive does not contain a pulse binary at its root."

mkdir -p "$INSTALL_ROOT" ||
    die "Could not create installations directory: $INSTALL_ROOT"

VERSION_DIR="$INSTALL_ROOT/$TAG"
STAGED="$INSTALL_ROOT/.pulse-install-$$"

remove_dir "$STAGED" "$INSTALL_ROOT"
mkdir -p "$STAGED" ||
    die "Could not create staging directory in: $INSTALL_ROOT"

cp -R "$TMP_DIR/extracted/." "$STAGED/" ||
    die "Could not stage release files."

cp "$TMP_DIR/checksums.txt" "$STAGED/checksums.txt" ||
    die "Could not stage release checksums."

chmod -R u+rwX,go+rX,go-w "$STAGED" ||
    die "Could not set file permissions."

STAGED=""
remove_dir "$VERSION_DIR" "$INSTALL_ROOT"
mv "$INSTALL_ROOT/.pulse-install-$$" "$VERSION_DIR" ||
    die "Could not install Pulse to $VERSION_DIR."

BIN_PATH="$BIN_DIR/$BINARY_NAME"

mkdir -p "$BIN_DIR" ||
    die "Could not create bin directory: $BIN_DIR"

install_symlink "$BIN_PATH" "$VERSION_DIR/$BINARY_NAME"

# Refresh versioned aliases (e.g. pulse-v0.6.3) for every installed
# version, so older releases remain invocable after an upgrade.
for VERSION in "$INSTALL_ROOT"/*; do
    [ -d "$VERSION" ] || continue
    [ -x "$VERSION/$BINARY_NAME" ] || continue
    install_symlink "$BIN_DIR/$BINARY_NAME-${VERSION##*/}" "$VERSION/$BINARY_NAME"
done

say "Installed Pulse ${TAG} to $VERSION_DIR"
say "Available at $BIN_PATH"

if [ -x "$BIN_DIR/$BINARY_NAME-$TAG" ]; then
    say "Pin to this version with: $BINARY_NAME-$TAG"
fi

case ":${PATH:-}:" in
    *":$BIN_DIR:"*)
        say "Run: pulse"
        ;;
    *)
        say "$BIN_DIR is not in your PATH."
        say "Add this to your shell configuration:"
        printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
        say "Then run: pulse"
        ;;
esac
