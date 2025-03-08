#!/bin/bash
set -e

# Get the app name from the current directory name
APP_NAME=$(basename $(pwd))
echo "📦 Packaging Splunk app: $APP_NAME"

# Load environment variables from .env file if it exists
if [ -f .env ]; then
  echo "🔑 Loading environment variables from .env"
  export $(grep -v '^#' .env | xargs)
fi

# Use default password if not set in .env
SPLUNK_PASSWORD=${SPLUNK_PASSWORD:-password}

# Check if Splunk service is running
if ! docker compose ps -a | grep -q "so1.*running"; then
  echo "⚠️ Splunk container is not running. Starting it now..."
  docker compose up -d so1
  
  # Wait for Splunk to be ready using health check
  echo "⏳ Waiting for Splunk to be ready..."
  timeout 360 bash -c 'until docker compose ps so1 | grep -q "(healthy)"; do sleep 5; echo -n "."; done'
  echo " ✅"
fi

echo "🔄 Creating Splunk app package..."

# Package the app
echo "🔧 Running package command in Splunk..."
docker compose exec so1 sudo /opt/splunk/bin/splunk package app $APP_NAME -auth admin:$SPLUNK_PASSWORD -merge-local-meta true

# The .spl file will be created at /opt/splunk/share/splunk/app_packages/
SPL_PATH="/opt/splunk/share/splunk/app_packages/$APP_NAME.spl"
LOCAL_SPL_PATH="./$APP_NAME.spl"

# Copy the SPL file to the local directory
echo "📥 Copying .spl file from $SPL_PATH to local directory..."
docker compose cp so1:$SPL_PATH .

# Clean up and extract the SPL file
echo "📂 Extracting SPL file..."

# Remove existing app directory if it exists
if [ -d "app" ]; then
  echo "🧹 Removing existing app directory..."
  rm -rf app
fi

# Remove existing extracted app directory if it exists
if [ -d "$APP_NAME" ]; then
  echo "🧹 Removing existing $APP_NAME directory..."
  rm -rf "$APP_NAME"
fi

# Extract SPL file
tar -xzf $APP_NAME.spl

# Rename the extracted directory to app
echo "🔄 Renaming $APP_NAME directory to app..."
mv "$APP_NAME" app

# Remove the local SPL file
echo "🧹 Cleaning up..."
rm $LOCAL_SPL_PATH

echo "✅ Done! App was packaged and local files were updated."
echo "📁 Your app directory now contains the packaged version of $APP_NAME."