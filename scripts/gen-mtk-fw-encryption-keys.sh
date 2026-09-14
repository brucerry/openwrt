#!/bin/sh
set -eu

usage() {
	cat >&2 <<'EOF'
Usage: gen-mtk-fw-encryption-keys.sh --platform-key FILE --roe-salt FILE \
       --output-dir DIR --key NAME:SALT_FILE [--key NAME:SALT_FILE ...]
EOF
	exit 1
}

hex_file() {
	od -An -tx1 -v "$1" | tr -d ' \n'
}

require_size() {
	actual=$(wc -c < "$1")
	[ "$actual" -eq "$2" ] || {
		echo "$1 must be exactly $2 bytes (got $actual)" >&2
		exit 1
	}
}

platform_key=
roe_salt=
output_dir=
keys=
openssl_bin=${OPENSSL_BIN:-}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--platform-key) platform_key=$2; shift 2 ;;
		--roe-salt) roe_salt=$2; shift 2 ;;
		--output-dir) output_dir=$2; shift 2 ;;
		--key) keys="${keys}${keys:+
}$2"; shift 2 ;;
		*) usage ;;
	esac
done

[ -n "$platform_key" ] && [ -n "$roe_salt" ] && [ -n "$output_dir" ] && [ -n "$keys" ] || usage

if [ -z "$openssl_bin" ]; then
	for candidate in /usr/bin/openssl /usr/local/bin/openssl "$(command -v openssl)"; do
		if [ -x "$candidate" ] && "$candidate" kdf -help >/dev/null 2>&1; then
			openssl_bin=$candidate
			break
		fi
	done
fi
[ -n "$openssl_bin" ] || {
	echo "An OpenSSL binary with the kdf command is required" >&2
	exit 1
}

require_size "$platform_key" 16
require_size "$roe_salt" 32
mkdir -p "$output_dir"
umask 077

roe_key="$output_dir/.roe_key.bin"
trap 'rm -f "$roe_key"' EXIT INT TERM
"$openssl_bin" kdf -binary -keylen 32 \
	-kdfopt digest:SHA256 \
	-kdfopt "hexkey:$(hex_file "$platform_key")" \
	-kdfopt "hexsalt:$(hex_file "$roe_salt")" \
	-out "$roe_key" HKDF

printf '%s\n' "$keys" | while IFS=: read -r name salt_file; do
	case "$name" in
		''|*[!A-Za-z0-9_-]*) echo "Invalid key name: $name" >&2; exit 1 ;;
	esac
	require_size "$salt_file" 32
	"$openssl_bin" kdf -binary -keylen 32 \
		-kdfopt digest:SHA256 \
		-kdfopt "hexkey:$(hex_file "$roe_key")" \
		-kdfopt "hexsalt:$(hex_file "$salt_file")" \
		-out "$output_dir/$name.bin" HKDF
done
