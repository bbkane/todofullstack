#!/bin/bash

# exit the script on command errors or unset variables
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# https://stackoverflow.com/a/246128/295807
# readonly script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# cd "${script_dir}"

origin='http://localhost:5000'

cat > ./tasks.txt << 'EOF'
first task
second thingie
EOF

set -x

http --check-status POST "$origin/api/items" content='a thing'

http --check-status GET "$origin/api/items/2"

http --check-status PATCH "$origin/api/items/2" content='a new thing'

http --check-status DELETE "$origin/api/items/2"

http --check-status GET "$origin/api/items"

set +x
