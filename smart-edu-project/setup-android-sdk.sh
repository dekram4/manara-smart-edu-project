#!/bin/bash
set -e

export JAVA_HOME=/nix/store/xad649j61kwkh0id5wvyiab5rliprp4d-openjdk-17.0.15+6
export ANDROID_HOME=/home/runner/workspace/sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH

# Create license files to bypass interactive prompt
mkdir -p $ANDROID_HOME/licenses

echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-license
echo "d56f5187479451eabf01fb78af6dfcb131a6481e" >> $ANDROID_HOME/licenses/android-sdk-license
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > $ANDROID_HOME/licenses/android-sdk-preview-license
echo "84831b9409646a918e30573bab4c9c91346d8abd" > $ANDROID_HOME/licenses/google-gdk-license
echo "d975f751698a77b662f1254ddbeed3901e976f5a" > $ANDROID_HOME/licenses/intel-android-extra-license
echo "8933bad161af4178b1185d1a37fbf41ea5269c55" > $ANDROID_HOME/licenses/android-sdk-arm-dbt-license

# Install required SDK components
sdkmanager --verbose "platforms;android-34" "build-tools;34.0.0" "platform-tools" 2>&1

echo "Android SDK setup complete!"
