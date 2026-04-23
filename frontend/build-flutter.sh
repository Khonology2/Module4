#!/bin/bash
set -e

echo "Installing Flutter..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1

echo "Setting up Flutter..."
export PATH="$PATH:$(pwd)/flutter/bin"

echo "Getting dependencies..."
flutter pub get

echo "Building Flutter web app..."
flutter build web

echo "Build completed successfully!"
