#!/bin/bash

set -e

source dev-container-features-test-lib

check "Volta version" volta --version

# Report results
reportResults