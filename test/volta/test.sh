#!/bin/bash

set -e

source dev-container-features-test-lib

check "Volta version" bash -c "volta --version"

reportResults
