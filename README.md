# BD2 — A2 Energia IoT

Trabalho prático de Banco de Dados II — otimização de consultas PostgreSQL 18.

## Integrantes

| Nome | Queries |
|------|---------|
| Amanda | Q1, Q2, Relatório Final |
| Gustavo | Q3, Q4, Q5, README |
| Lucas | Q6, Q7, Q8, Q9 |

---

## Estrutura do repositório

```
BD2-A2-ENERGIA-IOT/
├── arquivos_originais/       ← não modificar (arquivos do professor)
│   ├── init/
│   │   ├── 01-schema.sql
│   │   └── 02-dados.sql      ← NÃO está no GitHub (ver abaixo)
│   ├── src/
│   │   └── gerar_dados.py    ← NÃO está no GitHub (ver abaixo)
│   ├── compose.yaml
│   ├── consultas_problema.sql
│   └── instrucoes.md
├── consultas/                ← análise de cada query (qN.md)
├── scripts/                  ← índices e rewrites (otimizacao_qN.sql)
├── evidencias/               ← prints do EXPLAIN ANALYZE (antes/depois)
├── relatorio/
│   └── relatorio-final.md
└── compose.override.yaml     ← sobrescreve porta para 15432 no Windows
```

---

## Como subir o banco

### 1. Pré-requisitos

- Docker Desktop instalado e **aberto**
- pgAdmin ou outro cliente SQL

### 2. Arquivos que não estão no GitHub

Dois arquivos grandes foram excluídos do repositório. Coloque-os nos caminhos
corretos antes de subir o banco:

| Arquivo | Onde colocar |
|---------|-------------|
| `gerar_dados.py` (do ZIP do professor) | `arquivos_originais/src/` |
| `02-dados.sql` (gerado pelo container) | gerado automaticamente |

> Se você clonou este repositório, o `gerar_dados.py` já está em
> `arquivos_originais/src/` — ele foi recriado pelo grupo.
> O `02-dados.sql` é gerado automaticamente pelo container Python na primeira
> execução.

### 3. Subir os containers

```bash
docker compose -f arquivos_originais/compose.yaml -f compose.override.yaml up -d
```

O compose sobe dois serviços em sequência:
1. **data-generator** — gera `arquivos_originais/init/02-dados.sql` (~750 MB de dados)
2. **postgres** — carrega o schema e os dados automaticamente

> A primeira execução demora alguns minutos. Aguarde o container ficar `healthy`.

### 4. Conexão no pgAdmin

| Campo | Valor |
|-------|-------|
| Host | `localhost` |
| Port | `15432` |
| Database | `a2_energia` |
| Username | `postgres` |
| Password | `postgres` |

> **Por que 15432?** A porta original `55506` cai numa faixa reservada pelo
> Windows (Hyper-V/WinNAT). Em Linux/Mac você pode usar a porta original.

---

## Como tirar as evidências (prints antes/depois)

Para cada query, a ordem correta é:

1. **Print do DEPOIS** — com os índices criados, rode o EXPLAIN e tire o print
2. **DROP INDEX** — remove o índice para simular o estado original
3. **Print do ANTES** — rode o mesmo EXPLAIN e tire o print
4. **Recriar o índice** — restaura o estado otimizado

No pgAdmin: abra o **Query Tool** em `a2_energia`, cole a query com
`EXPLAIN (ANALYZE, BUFFERS)` na frente e pressione **F5**.

---

## Fluxo de trabalho

```
Arquivos Originais
       ↓
Docker (data-generator → postgres)
       ↓
PostgreSQL 18 / pgAdmin
       ↓
EXPLAIN (ANALYZE, BUFFERS)  ← mede o problema
       ↓
Identificar causa no plano
       ↓
Criar otimização (índice ou reescrita)
       ↓
EXPLAIN novamente  ← mede o resultado
       ↓
Salvar evidências (antes/depois)
       ↓
Atualizar consultas/qN.md
       ↓
Relatório Final
```

---

## O que foi otimizado

| Query | Problema | Solução | Ganho |
|-------|----------|---------|-------|
| Q1 | Sem índice em `status` + `occurred_at` | Índice composto B-tree | ~3× |
| Q2 | `UPPER(email)` não-sargable | Índice de expressão | ~290× |
| Q3 | `@>` em JSONB sem GIN | Índice GIN em `tags` | ~65× |
| Q4 | `DATE(occurred_at)` não-sargable | Reescrita + índice B-tree | ~42× |
| Q5 | DISTINCT + JOIN explosão de linhas | Reescrita com EXISTS | ~3× |
| Q6 | Subconsulta correlacionada | Reescrita com JOIN | — |
| Q7 | `LIKE '%texto%'` sem índice | Índice GIN trigram | — |
| Q8 | Agregação pesada com spill | Ajuste de `work_mem` | — |
| Q9 | Série temporal sem índice | Índice BRIN em `occurred_at` | — |
