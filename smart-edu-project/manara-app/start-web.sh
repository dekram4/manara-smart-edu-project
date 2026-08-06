#!/bin/sh
# Wrapper to start Expo web server without browser auto-open
mkdir -p /tmp/fakebin
cat > /tmp/fakebin/xdg-open << 'EOF'
#!/bin/sh
exit 0
EOF
chmod +x /tmp/fakebin/xdg-open

export PATH="/tmp/fakebin:$PATH"
export EXPO_ROUTER_DISABLE_RN_NAVIGATION_CHECK=1
export CI=1

cd "$(dirname "$0")" && npx expo start --web --port 5000
