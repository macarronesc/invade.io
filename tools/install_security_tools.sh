#!/usr/bin/env bash
set -euo pipefail
# Official Linux x86_64 release assets, checked before executing any downloaded code.
dest="${1:?usage: install_security_tools.sh directory}"
mkdir -p "$dest"
fetch() {
	local repo="$1" version="$2" asset="$3" sha="$4" binary="$5"
	curl --fail --location --retry 3 "https://github.com/$repo/releases/download/$version/$asset" -o "$dest/$asset"
	printf '%s  %s\n' "$sha" "$dest/$asset" | sha256sum --check -
	tar -xOzf "$dest/$asset" --wildcards --no-anchored "$binary" > "$dest/$binary"
	chmod +x "$dest/$binary"
	rm "$dest/$asset"
}
fetch gitleaks/gitleaks v8.30.1 gitleaks_8.30.1_linux_x64.tar.gz 551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb gitleaks
fetch rhysd/actionlint v1.7.12 actionlint_1.7.12_linux_amd64.tar.gz 8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8 actionlint
fetch koalaman/shellcheck v0.11.0 shellcheck-v0.11.0.linux.x86_64.tar.gz b7af85e41cc99489dcc21d66c6d5f3685138f06d34651e6d34b42ec6d54fe6f6 shellcheck
