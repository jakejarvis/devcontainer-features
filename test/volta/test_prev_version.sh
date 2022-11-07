#!/bin/bash

set -e

source dev-container-features-test-lib

check "Volta version" volta --version | grep 1.0.8

reportResults