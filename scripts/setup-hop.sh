#!/bin/bash
set -e

echo "🔧 VERIFICAÇÃO DOS ARQUIVOS MONTADOS..."

echo "📁 ESTRUTURA COMPLETA:"
find /opt/hop/projects -type f 2>/dev/null || echo "Nenhum arquivo encontrado"

echo ""
echo "🚨 TENTANDO ACESSAR ARQUIVOS ESPECÍFICOS:"

PIPELINE_FILE="/opt/hop/projects/email-project/pipelines/send-email-pipeline.hpl"
WORKFLOW_FILE="/opt/hop/projects/email-project/workflows/send-email-workflow.hwf"

if [ -f "$PIPELINE_FILE" ]; then
    echo "✅ PIPELINE ENCONTRADO: $PIPELINE_FILE"
    echo "   Tamanho: $(wc -l < "$PIPELINE_FILE") linhas"
else
    echo "❌ PIPELINE NÃO ENCONTRADO: $PIPELINE_FILE"
fi

if [ -f "$WORKFLOW_FILE" ]; then
    echo "✅ WORKFLOW ENCONTRADO: $WORKFLOW_FILE"
    echo "   Tamanho: $(wc -l < "$WORKFLOW_FILE") linhas"
else
    echo "❌ WORKFLOW NÃO ENCONTRADO: $WORKFLOW_FILE"
fi

echo ""
echo ""
echo "🚀 CRIANDO PROJETO VIA API..."

# Wait for Hop to be ready
echo "Aguardando Apache Hop inicializar..."
sleep 10

# Create project via API
curl -X POST "http://hop-web:8080/hop/project" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "email-project",
    "description": "Email sending project",
    "homeFolder": "/opt/hop/projects/email-project",
    "configFilename": "project-config.json"
  }' || echo "Projeto já existe ou erro na criação"

echo ""
echo "🎯 INSTRUÇÕES MANUAIS:"
echo "1. Acesse: http://localhost:8080/ui"
echo "2. Selecione 'Project: email-project'"
echo "3. Os arquivos devem aparecer automaticamente"