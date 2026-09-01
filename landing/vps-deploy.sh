#!/bin/bash
# ==============================================================================
# Script de Despliegue Automático para OffData Landing Page en VPS
# Compatible con Ubuntu / Debian / CentOS
# ==============================================================================

set -e

echo "=========================================="
echo "🚀 Desplegando OffData Landing Page en VPS"
echo "=========================================="

# Verificar si Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "📦 Instalando Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
fi

# Verificar si Docker Compose está instalado
if ! command -v docker compose &> /dev/null; then
    echo "📦 Instalando Docker Compose plugin..."
    apt-get update && apt-get install -y docker-compose-plugin || yum install -y docker-compose-plugin
fi

echo "🔧 Construyendo e iniciando contenedor..."
docker compose down || true
docker compose up -d --build

echo "=========================================="
echo "✅ ¡Landing Page desplegada exitosamente!"
echo "🌐 Abre la IP o Dominio de tu VPS en el navegador para ver la página y descargar la APK."
echo "=========================================="
