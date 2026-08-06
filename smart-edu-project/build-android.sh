#!/bin/bash
set -e
export JAVA_HOME=/nix/store/k95pqfzyvrna93hc9a4cg5csl7l4fh0d-openjdk-21.0.7+6
export ANDROID_HOME=/home/runner/workspace/sdk
export PATH=$JAVA_HOME/bin:$PATH

cd android
./gradlew assembleDebug --no-daemon --console=plain 2>&1
