#!/usr/bin/env bash
# A small SDK-provided Git runtime for the optional desktop trial.
set -euo pipefail
GIT_CORE="$(git --exec-path)"
install -Dm755 /usr/bin/git /app/bin/git
mkdir -p /app/libexec/git-core /app/share/doc/git /app/share/git-core
for name in git-upload-pack git-receive-pack git-upload-archive git-credential-cache git-credential-cache--daemon git-credential-store; do
  ln -sf ../../bin/git "/app/libexec/git-core/$name"
done
install -m755 "$GIT_CORE/git-remote-http" /app/libexec/git-core/git-remote-http
ln -sf git-remote-http /app/libexec/git-core/git-remote-https
cp -a /usr/share/git-core/templates /app/share/git-core/
install -m644 tools/github-trial-Git-COPYING /app/share/doc/git/COPYING
git --version > /app/share/doc/git/VERSION
printf 'Git source: https://github.com/git/git (see VERSION for the SDK build).\n' > /app/share/doc/git/SOURCE
