# Relatório Técnico - Avaliação A2 de Banco de Dados II

## Estudo de caso 06 - Energia IoT

**Integrantes:**
- AMANDA RIBEIRO DA COSTA
- (nome 2)
- (nome 3)

---

## 1. Ambiente

O estudo de caso usa um banco PostgreSQL 18 em container, com o schema `energia`
e cerca de 1 milhão de linhas somando todas as tabelas (50 mil unidades, 250 mil
leituras e 750 mil eventos). O banco foi entregue sem índices auxiliares, de
propósito, para que as otimizações fossem medidas e justificadas.

Todas as medições foram feitas com `EXPLAIN (ANALYZE, BUFFERS)`, comparando o
plano de execução antes e depois de cada mudança. As evidências (prints) estão
na pasta `evidencias/` e os scripts de cada otimização na pasta `scripts/`.

---

## 2. Metodologia

Para cada consulta seguimos o mesmo método:

1. Medir o tempo e o plano de execução antes da mudança.
2. Interpretar o plano e identificar o gargalo (tipo de varredura, filtros,
   ordenação, leitura de disco).
3. Formular uma hipótese sobre a causa do problema.
4. Aplicar uma única mudança isolada (índice, reescrita da consulta ou ajuste
   de parâmetro).
5. Medir novamente e comparar com o resultado anterior.
6. Registrar o ganho obtido e o custo colateral da mudança.

### Priorização por custo agregado

Antes de otimizar, usamos a extensão `pg_stat_statements` para identificar quais
consultas pesavam mais para o banco como um todo:

```sql
SELECT calls,
       round(total_exec_time::numeric, 2) AS total_ms,
       round(mean_exec_time::numeric, 2) AS media_ms,
       rows,
       left(query, 120) AS consulta
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 12;
```

O custo real de uma consulta não é só o tempo de uma execução, mas o tempo total
acumulado (número de execuções × tempo médio). Uma consulta rápida que roda
muitas vezes pode pesar mais do que uma consulta lenta que roda raramente. Por
isso priorizamos as otimizações pelo tempo total, e não apenas pelo tempo
individual de cada consulta.

---

## 3. Análise por consulta

### Q1 - Painel operacional recente

| Campo | Descrição |
|---|---|
| **Consulta** | Lista os chamados em aberto ou em andamento dos últimos 90 dias, com dados do técnico. |
| **Sintoma inicial** | Seq Scan na tabela `leituras` (250 mil linhas), ~318 ms, acessando quase 10 mil blocos (8.699 lidos do disco). |
| **Hipótese** | Ausência de índice nas colunas filtradas (`status` e `occurred_at`). |
| **Mudança aplicada** | Índice composto `(status, occurred_at)`. |
| **Resultado** | Bitmap Index Scan, ~110 ms e apenas ~540 blocos. Cerca de 3× mais rápido (e poucos ms com cache aquecido). |
| **Custo** | Índice de ~9,5 MB em disco; escrita um pouco mais cara em `leituras`, compensada pelo uso intenso do painel. |

Evidências: `evidencias/q1_antes.png`, `evidencias/q1_depois.png` · Detalhes: `consultas/q1.md`

### Q2 - Busca por e-mail ignorando maiúsculas/minúsculas

| Campo | Descrição |
|---|---|
| **Consulta** | Busca uma unidade pelo e-mail digitado, sem diferenciar maiúsculas de minúsculas. |
| **Sintoma inicial** | Seq Scan na tabela `unidades` (50 mil linhas), ~88 ms, 797 blocos. O `UPPER(email)` impedia o uso do índice `UNIQUE`. |
| **Hipótese** | Aplicar uma função sobre a coluna (`UPPER`) torna o filtro não-sargable e inviabiliza o índice existente. |
| **Mudança aplicada** | Índice de expressão sobre `UPPER(email)`. |
| **Resultado** | Index Scan, ~0,9 ms e apenas 4 blocos. Acesso direto a uma única linha. |
| **Custo** | Índice de ~2,4 MB; recálculo de `UPPER()` a cada escrita, custo baixo em tabela cadastral. |

Evidências: `evidencias/q2_antes.png`, `evidencias/q2_depois.png` · Detalhes: `consultas/q2.md`

### Q3 - Filtro em JSONB

| Campo | Descrição |
|---|---|
| **Consulta** | Busca leituras cujo campo `tags` (JSONB) contém um produto específico. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes — esperado Seq Scan)_ |
| **Hipótese** | _(a preencher — esperado: filtro `@>` em JSONB sem índice GIN)_ |
| **Mudança aplicada** | _(a preencher — esperado: índice GIN sobre `tags`)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher — ex.: GIN ocupa mais espaço e encarece a escrita)_ |

Evidências: `evidencias/q3_antes.png`, `evidencias/q3_depois.png` · Detalhes: `consultas/q3.md`

### Q4 - Predicado não-sargable em data

| Campo | Descrição |
|---|---|
| **Consulta** | Conta as leituras de um dia específico usando `DATE(occurred_at) = ...`. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes)_ |
| **Hipótese** | _(a preencher — esperado: `DATE()` sobre a coluna impede uso de índice)_ |
| **Mudança aplicada** | _(a preencher — esperado: reescrever para faixa `>= dia AND < dia+1` e/ou índice em `occurred_at`)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher)_ |

Evidências: `evidencias/q4_antes.png`, `evidencias/q4_depois.png` · Detalhes: `consultas/q4.md`

### Q5 - DISTINCT mascarando explosão de JOIN

| Campo | Descrição |
|---|---|
| **Consulta** | Lista unidades distintas com leituras concluídas e eventos recentes. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes)_ |
| **Hipótese** | _(a preencher — esperado: o JOIN multiplica linhas e o `DISTINCT` esconde o problema)_ |
| **Mudança aplicada** | _(a preencher — esperado: reescrever com `EXISTS` e/ou índices de FK)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher)_ |

Evidências: `evidencias/q5_antes.png`, `evidencias/q5_depois.png` · Detalhes: `consultas/q5.md`

### Q6 - Subconsulta correlacionada

| Campo | Descrição |
|---|---|
| **Consulta** | Para cada chamado aberto, conta os eventos relacionados via subconsulta. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes)_ |
| **Hipótese** | _(a preencher — esperado: subconsulta correlacionada reexecutada por linha; FK `leituras_id` sem índice)_ |
| **Mudança aplicada** | _(a preencher — esperado: índice em `eventos_leitura(leituras_id)` e/ou reescrever com JOIN + agregação)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher)_ |

Evidências: `evidencias/q6_antes.png`, `evidencias/q6_depois.png` · Detalhes: `consultas/q6.md`

### Q7 - Busca textual com curinga à esquerda

| Campo | Descrição |
|---|---|
| **Consulta** | Busca leituras cuja descrição contém um texto, usando `LIKE '%...%'`. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes)_ |
| **Hipótese** | _(a preencher — esperado: curinga à esquerda impede índice B-tree comum)_ |
| **Mudança aplicada** | _(a preencher — esperado: extensão `pg_trgm` + índice GIN trigram)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher)_ |

Evidências: `evidencias/q7_antes.png`, `evidencias/q7_depois.png` · Detalhes: `consultas/q7.md`

### Q8 - Dashboard gerencial com risco de spill em work_mem

| Campo | Descrição |
|---|---|
| **Consulta** | Agregação por técnico, unidade e status, com soma e datas mín/máx. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes — observar uso de disco na ordenação/agrupamento)_ |
| **Hipótese** | _(a preencher — esperado: agregação grande pode gerar arquivos temporários com `work_mem` padrão)_ |
| **Mudança aplicada** | _(a preencher — esperado: ajustar `work_mem` na sessão e remedir)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher — ex.: `work_mem` alto global consome memória em sessões concorrentes)_ |

Evidências: `evidencias/q8_antes.png`, `evidencias/q8_depois.png` · Detalhes: `consultas/q8.md`

### Q9 - Série temporal em tabela de milhões de eventos

| Campo | Descrição |
|---|---|
| **Consulta** | Conta eventos por dia a partir de uma data, em `eventos_leitura`. |
| **Sintoma inicial** | _(a preencher: tempo, buffers e plano antes)_ |
| **Hipótese** | _(a preencher — esperado: varredura grande em tabela temporal sem índice adequado)_ |
| **Mudança aplicada** | _(a preencher — esperado: índice BRIN em `occurred_at`)_ |
| **Resultado** | _(a preencher: tempo, buffers e plano depois)_ |
| **Custo** | _(a preencher — ex.: BRIN é pequeno e barato, mas depende da correlação física dos dados)_ |

Evidências: `evidencias/q9_antes.png`, `evidencias/q9_depois.png` · Detalhes: `consultas/q9.md`

---

## 4. Considerações finais

_(a preencher pelo grupo ao concluir as consultas. Sugestões de pontos a abordar:)_

- Limitações encontradas durante as medições (ex.: variação de tempo por causa
  de cache).
- Decisões que o grupo optou por não adotar e o motivo (ex.: índice parcial em
  vez de composto, ajuste global de parâmetro descartado).
- Equilíbrio geral entre ganho de leitura e custo de escrita/espaço dos índices.
- Observação sobre o arquivo `02-dados.sql`, que não foi versionado por exceder
  o limite de tamanho do GitHub (deve ser gerado/copiado localmente).
