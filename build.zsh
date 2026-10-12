#!/bin/zsh
# Wrapper that runs build.sh under zsh so the (N) glob qualifier and other
# zsh-specific syntax in the script parse and execute as intended.
#
# The upstream repo ships build.sh with a #!/bin/zsh shebang and zsh-only
# extglob patterns. On this machine the default /bin/sh is bash 3.2, which
# does not understand (N), so zsh is used for both syntax-checking and
# execution when called through this wrapper.
set -euo pipefail
exec /bin/zsh "$0:A:h/build.sh" "$@"
