#!/bin/bash

echo "🔍 Debugowanie połączenia z bazą danych..."
echo "==========================================="

# Sprawdź status aplikacji
echo "📊 Status aplikacji:"
fly status -a numbers-evolution-akkdua

echo ""
echo "📊 Status bazy danych:"
fly status -a numbers-evolution-db

echo ""
echo "🔌 Test połączenia z bazą:"
fly postgres connect -a numbers-evolution-db --command "SELECT version();"

echo ""
echo "📋 Lista aplikacji:"
fly apps list

echo ""
echo "🔑 Lista sekretów aplikacji:"
fly secrets list -a numbers-evolution-akkdua

echo ""
echo "📝 Logi aplikacji (ostatnie 50 linii):"
fly logs -a numbers-evolution-akkdua --tail 50

echo ""
echo "🔍 Sprawdzanie czy baza jest dostępna:"
# Próba połączenia z bazą
timeout 10 bash -c 'until echo > /dev/tcp/numbers-evolution-db.internal/5432; do sleep 1; done' && echo "✅ Baza dostępna" || echo "❌ Baza niedostępna"
