# Estudo de caso 06 - Energia IoT

## Contexto

Este caso simula um sistema de monitoramento de medidores inteligentes. A organizacao cresceu sem uma revisao de banco de dados e passou a sofrer com paineis lentos, buscas pontuais demoradas, relatorios com alto consumo de I/O e operacoes analiticas que geram arquivos temporarios.

O trabalho da equipe e atuar como DBA: medir, explicar o plano, formular uma hipotese, testar uma mudanca isolada e documentar o antes/depois.

## Ambiente

- PostgreSQL 18 em container.
- Porta local: `55506`.
- Usuario: `postgres`.
- Senha: `postgres`.
- Banco: `a2_energia`.
- Schema: `energia`.

O `compose.yaml` possui um container Python chamado `data-generator`.
Ele gera `init/02-dados.sql` antes da inicializacao do PostgreSQL.

```bash
podman compose up -d
podman compose exec postgres psql -U postgres -d a2_energia -f consultas_problema.sql
```

O gerador escreve `init/02-dados.sql`. O volume padrao possui mais de um milhao de linhas somando tabelas dimensionais, registros principais, eventos e avaliacoes.

Para regenerar com outro volume:

```bash
A2_ROWS=500000 A2_EVENTS_PER_RECORD=4 podman compose run --rm data-generator
podman compose down -v
podman compose up -d
```

O `down -v` e necessario quando a base ja foi inicializada, porque a imagem oficial do PostgreSQL so executa os scripts de `init/` na primeira criacao do volume.

## Entregaveis da equipe

1. Arquivo ZIP contendo SQLs, `compose.yaml`, scripts e `README.md`.
2. Relatorio com uma tabela por consulta: tempo, buffers, plano principal, hipotese, mudanca e resultado.
3. Scripts SQL de indices, reescritas de consultas e ajustes de parametros testados.
4. Declaracao dos custos colaterais: espaco dos indices, impacto em escrita e risco de ajuste global.

## Pistas tecnicas

- Indices de chaves estrangeiras foram omitidos.
- Filtros com `UPPER(coluna)`, `DATE(coluna)` e `LIKE '%termo%'` exigem reescrita ou indice adequado.
- `tags JSONB` precisa de GIN para filtros `@>`.
- A tabela de eventos tem perfil temporal e permite discutir BRIN, correlacao fisica e `CLUSTER`.
- `work_mem` deve ser testado primeiro na sessao, nao globalmente.
