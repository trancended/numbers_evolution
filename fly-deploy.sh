#!/bin/bash

# Fly.io deployment script for Numbers Evolution
set -e

echo "🚀 Deploying Numbers Evolution to Fly.io..."

# Check if fly CLI is installed
if ! command -v fly &> /dev/null; then
    echo "❌ Fly CLI is not installed. Please install it first:"
    echo "   curl -L https://fly.io/install.sh | sh"
    exit 1
fi

# Check if logged in to Fly.io
if ! fly auth whoami &> /dev/null; then
    echo "❌ Not logged in to Fly.io. Please run:"
    echo "   fly auth login"
    exit 1
fi

# Create the app if it doesn't exist
if ! fly apps list | grep -q "numbers-evolution"; then
    echo "📦 Creating Fly.io app..."
    fly launch --name numbers-evolution --region fra --yes --internal-port 4000
else
    echo "✅ App already exists"
fi

# Set up PostgreSQL database
echo "🗄️  Setting up PostgreSQL database..."
fly postgres create --name numbers-evolution-db --region fra --yes || echo "Database might already exist"

# Attach database to app
echo "🔗 Attaching database to app..."
fly postgres attach numbers-evolution-db --app numbers-evolution --yes || echo "Database might already be attached"

# Set secrets
echo "🔐 Setting up secrets..."
echo "Please provide your secrets:"
read -p "OpenRouter API Key: " openrouter_key
read -p "Secret Key Base (leave empty to generate): " secret_key

if [ -z "$secret_key" ]; then
    secret_key=$(mix phx.gen.secret)
    echo "Generated secret key: $secret_key"
fi

fly secrets set OPENROUTER_API_KEY="$openrouter_key" SECRET_KEY_BASE="$secret_key" --app numbers-evolution

# Deploy
echo "🚀 Deploying application..."
fly deploy --app numbers-evolution

echo "✅ Deployment complete!"
echo "🌐 Your app should be available at: https://numbers-evolution.fly.dev"
