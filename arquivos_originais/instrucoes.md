# Instruções da Avaliação A2 - Banco de Dados II

## 1. Objetivo do trabalho

A Avaliação A2 é um trabalho prático de Banco de Dados II. Cada grupo receberá um estudo de caso com um banco PostgreSQL 18 propositalmente pouco otimizado. O objetivo é atuar como uma equipe de banco de dados: preparar o ambiente, gerar a massa de dados, medir consultas lentas, interpretar planos de execução, propor melhorias e documentar os resultados.

O foco do trabalho não é apenas "deixar a consulta mais rápida". O foco é demonstrar método:

1. medir o problema;
2. interpretar o plano de execução;
3. formular uma hipótese;
4. aplicar uma mudança isolada;
5. medir novamente;
6. explicar o ganho e o custo da mudança.

## 2. Organização dos grupos

- O trabalho deve ser feito em grupo de 2 a 3 alunos.
- Apenas um integrante deve entregar o arquivo final no Educ@.
- Todos os integrantes devem compreender o que foi entregue, pois o professor poderá questionar decisões técnicas do grupo.

## 3. Estrutura do estudo de caso

Cada grupo receberá um arquivo ZIP com uma pasta semelhante a esta:

```text
01_clinica_regional/
├── compose.yaml
├── README.md
├── consultas_problema.sql
├── init/
│   └── 01-schema.sql
└── src/
    └── gerar_dados.py
```

O arquivo `init/01-schema.sql` contém o esquema do banco. Ele deve ser mantido como ponto de partida.

O arquivo `init/02-dados.sql` não é entregue pronto. Ele será gerado pelo container Python definido no `compose.yaml`.

## 4. Pré-requisitos

Antes de iniciar, o grupo deve ter instalado:

- Podman ou Docker;
- Podman Compose ou Docker Compose;
- DBeaver, pgAdmin ou outro cliente SQL;
- editor de texto ou IDE;
- espaço livre em disco para gerar a base de dados.

Nos exemplos abaixo será usado `podman compose`. Se o grupo usa Docker, substitua por `docker compose`.

## 5. Como subir o ambiente

Entre na pasta do estudo de caso:

```bash
cd 01_clinica_regional
```

Suba o ambiente:

```bash
podman compose up -d
```

O `compose.yaml` possui dois serviços:

- `data-generator`: container Python que gera `init/02-dados.sql`;
- `postgres`: container PostgreSQL 18 que carrega o schema e os dados.

Na primeira execução, o serviço Python gera a carga de dados antes da inicialização do PostgreSQL. Em seguida, o PostgreSQL executa automaticamente os arquivos da pasta `init/`.

Confira se o banco está ativo:

```bash
podman compose ps
```

Teste a conexão:

```bash
podman compose exec postgres psql -U postgres -d <nome_do_banco> -c "SELECT version();"
```

O nome do banco está no `README.md` do estudo de caso e no `compose.yaml`, em `POSTGRES_DB`.

## 6. Como regenerar os dados

Se for necessário apagar a base e gerar os dados novamente:

```bash
podman compose down -v
podman compose up -d
```

O `down -v` remove o volume do PostgreSQL. Isso é importante porque a imagem oficial do PostgreSQL só executa os scripts da pasta `init/` na primeira criação do volume.

Para gerar uma base maior ou menor, use variáveis de ambiente:

```bash
A2_ROWS=500000 A2_EVENTS_PER_RECORD=4 podman compose up -d
```

Principais variáveis:

| Variável | Significado |
|---|---|
| `A2_ROWS` | quantidade de linhas na tabela principal |
| `A2_EVENTS_PER_RECORD` | quantidade média de eventos por registro principal |
| `A2_ENTITIES` | quantidade de entidades principais, como clientes, pacientes ou usuários |
| `A2_AGENTS` | quantidade de operadores, atendentes, técnicos ou equivalentes |
| `A2_CATEGORIES` | quantidade de categorias |
| `A2_RATINGS` | quantidade de avaliações |

Use volumes maiores apenas se o computador do grupo suportar. O volume padrão já é suficiente para observar diferenças de otimização.

## 7. Consultas-problema

O arquivo `consultas_problema.sql` contém as consultas que devem ser analisadas.

Execute as consultas com:

```bash
podman compose exec postgres psql -U postgres -d <nome_do_banco> -f consultas_problema.sql
```

O grupo deve analisar cada consulta usando:

```sql
EXPLAIN (ANALYZE, BUFFERS)
```

Para cada consulta, registre:

- tempo de execução;
- tipo de varredura principal (`Seq Scan`, `Index Scan`, `Bitmap Heap Scan`, etc.);
- quantidade de linhas estimadas e reais;
- buffers lidos;
- presença de ordenação ou agregação cara;
- presença de arquivos temporários ou spill em disco;
- hipótese de otimização.

## 8. O que o grupo deve investigar

Os estudos de caso foram construídos para permitir investigação de problemas comuns em PostgreSQL:

- ausência de índice em chave estrangeira;
- ausência de índice composto;
- uso de função sobre coluna no `WHERE`;
- filtros com `DATE(coluna)`;
- busca textual com `LIKE '%termo%'`;
- filtros em `JSONB`;
- subconsulta correlacionada;
- `JOIN` que multiplica linhas e depois tenta corrigir com `DISTINCT`;
- agregações que podem depender de `work_mem`;
- tabelas temporais candidatas a BRIN;
- diferença entre melhorar uma consulta e criar custo de escrita/manutenção.

Nem toda consulta exige o mesmo tipo de solução. Algumas exigem índice, outras exigem reescrita SQL, outras exigem ajuste de parâmetro ou apenas melhor interpretação do plano.

## 9. Regras para otimização

O grupo deve seguir estas regras:

1. Não aplicar todas as mudanças de uma vez.
2. Medir antes da mudança.
3. Aplicar uma mudança isolada.
4. Medir depois da mudança.
5. Justificar tecnicamente a decisão.
6. Declarar custo colateral.

Exemplos de custo colateral:

- índice ocupa espaço em disco;
- índice torna `INSERT`, `UPDATE` e `DELETE` mais caros;
- índice GIN pode ser excelente para leitura e caro para escrita;
- `work_mem` global alto pode consumir muita memória em sessões concorrentes;
- `CLUSTER` reorganiza tabela, mas exige bloqueio e manutenção.

## 10. Entregáveis

O grupo deve entregar um único arquivo ZIP contendo:

1. `README.md` do grupo, com identificação dos integrantes;
2. scripts SQL criados pelo grupo;
3. relatório técnico em Markdown ou PDF;
4. evidências dos planos antes e depois;
5. arquivos de configuração modificados, se houver;
6. observações sobre limitações e decisões não adotadas.

O relatório deve conter, para cada consulta analisada:

| Campo | O que informar |
|---|---|
| Consulta | Q1, Q2, Q3... |
| Sintoma inicial | tempo, buffers e plano antes |
| Hipótese | causa provável do problema |
| Mudança aplicada | índice, reescrita SQL, parâmetro ou outra ação |
| Resultado | tempo, buffers e plano depois |
| Custo | impacto em escrita, espaço, manutenção ou risco operacional |

## 11. Barema sugerido

| Critério | Pontuação |
|---|---:|
| Grupo de 2 a 3 alunos e entrega organizada | 1,0 |
| ZIP contendo todos os arquivos exigidos | 1,0 |
| Compreensão do estudo de caso e do modelo | 1,0 |
| Medições antes/depois com `EXPLAIN (ANALYZE, BUFFERS)` | 1,5 |
| Qualidade das hipóteses de otimização | 1,5 |
| Scripts SQL corretos e reproduzíveis | 1,0 |
| Discussão de custos colaterais | 1,0 |

## 12. Recomendações finais

- Não entregue apenas scripts soltos: explique o raciocínio.
- Não confunda `Seq Scan` com erro automático. Ele pode ser correto em alguns cenários.
- Não crie índice sem justificar qual consulta ele atende.
- Não ajuste parâmetro global sem testar antes na sessão.
- Não apague evidências ruins: elas fazem parte do diagnóstico.
- O relatório deve mostrar maturidade técnica, não apenas resultado numérico.

O trabalho será avaliado pela capacidade do grupo de demonstrar método, clareza e domínio dos conceitos estudados na disciplina.
