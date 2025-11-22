#!/bin/bash

# E2E Test Helper Script
# This script helps set up and run E2E tests locally

set -e

echo "🚀 Numbers Evolution E2E Test Helper"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if PostgreSQL is running
echo "Checking PostgreSQL..."
if ! pg_isready -q; then
    echo -e "${RED}❌ PostgreSQL is not running. Please start PostgreSQL first.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ PostgreSQL is running${NC}"
echo ""

# Check if database exists
echo "Checking database..."
if MIX_ENV=test_e2e mix ecto.create --quiet 2>/dev/null; then
    echo -e "${GREEN}✅ Database created${NC}"
else
    echo -e "${YELLOW}⚠️  Database might already exist${NC}"
fi

# Run migrations
echo "Running migrations..."
MIX_ENV=test_e2e mix ecto.migrate
echo -e "${GREEN}✅ Migrations completed${NC}"
echo ""

# Check if port 4000 is available
if lsof -Pi :4000 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}⚠️  Port 4000 is already in use${NC}"
    echo "Please stop the server running on port 4000 or use a different port"
    exit 1
fi

echo -e "${GREEN}✅ Port 4000 is available${NC}"
echo ""

echo "Starting Phoenix server in test_e2e environment..."
echo "Server will be available at http://127.0.0.1:4000"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start server
MIX_ENV=test_e2e mix phx.server

