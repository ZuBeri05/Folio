#!/usr/bin/env bash
# Compile every source against a desktop compiler before pushing. The platform
# layer is built against tools/switch_stub/switch.h, so libnx-specific mistakes
# (missing headers, wrong struct names) show up here instead of in CI.
set -e
cd "$(dirname "$0")/.."

g++ -std=gnu++17 -Wall -Wextra -Wno-unused-parameter -fsyntax-only \
    -Isource -Itools/switch_stub -D__SWITCH__ -DFOLIO_HOST=0 \
    source/main.cpp source/platform/platform.cpp

g++ -std=gnu++17 -Wall -Wextra -Wno-unused-parameter -fsyntax-only \
    -Isource -D__SWITCH__ -DFOLIO_HOST=1 \
    source/core/*.cpp source/domain/*.cpp source/data/*.cpp \
    source/services/*.cpp source/ui/*.cpp tools/preview.cpp

echo "local checks passed"
