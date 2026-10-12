#!/bin/sh
set -eu

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

print_banner

REPO="cherries-works/pulse"
INSTALL_DIR="${PULSE_INSTALL_DIR:-${HOME:?HOME is not set}/.local/bin}"
BINARY_NAME="pulse"
BASE_URL="https://github.com/${REPO}/releases/latest/download"

say() {
    printf 'Pulse: %s\n' "$*"
}

die() {
    printf 'Pulse: error: %s\n' "$*" >&2
    exit 1
}

for cmd in uname mktemp mkdir chmod mv rm cp tar awk; do
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
        rm -f "$STAGED"
    fi
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

say "Downloading Pulse for Linux/$ARCH..."

download "$BASE_URL/$ASSET" "$TMP_DIR/$ASSET" ||
    die "Download failed: $ASSET"

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

mkdir -p "$TMP_DIR/extracted"

tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR/extracted" ||
    die "Could not extract release archive."

[ -f "$TMP_DIR/extracted/pulse" ] ||
    die "Archive does not contain a pulse binary at its root."

mkdir -p "$INSTALL_DIR" ||
    die "Could not create installation directory: $INSTALL_DIR"

STAGED="$INSTALL_DIR/.pulse-install-$$"

cp "$TMP_DIR/extracted/pulse" "$STAGED" ||
    die "Could not stage the binary."

chmod 755 "$STAGED" ||
    die "Could not set executable permissions."

mv -f "$STAGED" "$INSTALL_DIR/$BINARY_NAME" ||
    die "Could not install Pulse to $INSTALL_DIR."

STAGED=""

say "Installed successfully to $INSTALL_DIR/$BINARY_NAME"

case ":${PATH:-}:" in
    *":$INSTALL_DIR:"*)
        say "Run: pulse"
        ;;
    *)
        say "$INSTALL_DIR is not in your PATH."
        say "Add this to your shell configuration:"
        printf '  export PATH="%s:$PATH"\n' "$INSTALL_DIR"
        say "Then run: pulse"
        ;;
esac