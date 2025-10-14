#!/bin/bash
set -e

echo "🚀 Iniciando configuração do Apache Hop Web..."

# Aguardar o Hop Web iniciar
echo "⏳ Aguardando Hop Web iniciar..."
while ! curl -s http://localhost:8080/ui > /dev/null; do
    sleep 5
done

echo "✅ Hop Web está rodando!"

# Criar diretório de projetos se não existir
mkdir -p /projects

echo "📁 Estrutura de projetos criada:"
ls -la /projects/

echo "🎯 Configuração inicial concluída!"