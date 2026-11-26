# CDSS-JuntaMed — Sistema de Apoio à Decisão Clínica

Repositório do projeto físico de banco de dados e lógica transacional do **CDSS-JuntaMed**, desenvolvido em **PostgreSQL**.

---

## Estrutura Atual do Banco de Dados (`sql/`)

Os scripts estão numerados na ordem obrigatória de execução:

1. **`sql/01_ddl_tabelas.sql`**: Criação das **13 tabelas principais** do domínio clínico (entidades fortes, entidades fracas com chave primária composta e relacionamentos N:M), contemplando as regras de integridade **R1 a R8**.
2. **`sql/02_ddl_staging_auditoria.sql`**: Criação das **6 tabelas de staging** (`stg_*`) sem chaves estrangeiras rígidas para ingestão em duplo estágio, além da tabela de auditoria **`etl_audit_log`**.
3. **`sql/03_indices.sql`**: Índices de desempenho, incluindo o índice composto B-Tree `(hadm_id, flag_anormal, charttime DESC)` (Spec 1) e índices em chaves estrangeiras críticas.
4. **`sql/04_funcoes_transacoes.sql`**: Implementação das **10 funções do catálogo (FN-01 a FN-10)**, controle de concorrência (`FOR UPDATE` e `FOR SHARE`) e *Constraint Trigger* `DEFERRABLE` para garantia da **Regra R7**.
5. **`sql/05_seed_inicial.sql`**: Carga inicial de governança clínica com protocolos oficiais **CONITEC/SUS** (`diretriz_clinica`) e cadastro dos especialistas de IA (`agente_ia`).

---

## Pré-requisitos

Escolha **uma** das opções abaixo para rodar o PostgreSQL na sua máquina:

- **Opção A (Recomendada para simplicidade):** [PostgreSQL](https://www.postgresql.org/download/) instalado localmente (com o comando `psql` disponível no terminal).
- **Opção B (Isolado em container):** [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado e em execução (*Engine running*).

Além disso, é necessário ter o **Git** instalado.

---

## Passo a Passo de Configuração

### 1. Clonar o repositório

```bash
git clone https://github.com/Clarabrt7/cdss-juntamed.git
cd cdss-juntamed
```

---

### 2. Criar o banco de dados `cdss_juntamed`

#### Opção A — Usando PostgreSQL local

```powershell
psql -U postgres -c "CREATE DATABASE cdss_juntamed;"
```

*(Informe a senha do usuário `postgres` configurada na instalação do seu PostgreSQL).*

#### Opção B — Usando Docker

Com o Docker Desktop aberto, suba o container (a variável `POSTGRES_DB` já cria o banco automaticamente):

```powershell
docker run --name pg-juntamed -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=cdss_juntamed -p 5432:5432 -d postgres:17
```

> **Nota sobre porta ocupada:** Caso você já tenha o PostgreSQL instalado localmente usando a porta `5432`, substitua `-p 5432:5432` por `-p 5433:5432`.

Para verificar se o container está ativo:

```powershell
docker ps
```

---

### 3. Executar os scripts SQL na ordem

> **Dica (Windows PowerShell):** Para não precisar digitar a senha do PostgreSQL em cada comando, defina a variável temporária na sessão atual do terminal antes de rodar os scripts:
> ```powershell
> $env:PGPASSWORD="sua_senha_do_postgres"
> ```

#### Opção A — No PostgreSQL local (PowerShell, VS Code ou Linux/macOS)

```powershell
psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 -f sql/01_ddl_tabelas.sql
psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 -f sql/02_ddl_staging_auditoria.sql
psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 -f sql/03_indices.sql
psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 -f sql/04_funcoes_transacoes.sql
psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 -f sql/05_seed_inicial.sql
```

#### Opção B — No Docker (Windows PowerShell)

```powershell
Get-Content sql/01_ddl_tabelas.sql | docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1
Get-Content sql/02_ddl_staging_auditoria.sql | docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1
Get-Content sql/03_indices.sql | docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1
Get-Content sql/04_funcoes_transacoes.sql | docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1
Get-Content sql/05_seed_inicial.sql | docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1
```

#### Opção B — No Docker (Linux, macOS, WSL ou Git Bash)

```bash
docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 < sql/01_ddl_tabelas.sql
docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 < sql/02_ddl_staging_auditoria.sql
docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 < sql/03_indices.sql
docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 < sql/04_funcoes_transacoes.sql
docker exec -i pg-juntamed psql -U postgres -d cdss_juntamed -v ON_ERROR_STOP=1 < sql/05_seed_inicial.sql
```

*(O parâmetro `-v ON_ERROR_STOP=1` garante que a execução seja interrompida imediatamente caso ocorra qualquer erro).*

---

### 4. Validar a instalação

#### Conferir as 20 tabelas criadas

* **PostgreSQL local:**
  ```powershell
  psql -U postgres -d cdss_juntamed -c "\dt"
  ```
* **Docker:**
  ```powershell
  docker exec -it pg-juntamed psql -U postgres -d cdss_juntamed -c "\dt"
  ```

Resultado esperado: **20 tabelas** no schema `public` (13 principais + 6 `stg_*` + `etl_audit_log`).

#### Testar uma função do catálogo (FN-09) e o seed inicial

* **PostgreSQL local:**
  ```powershell
  psql -U postgres -d cdss_juntamed -c "SELECT * FROM buscar_diretrizes_clinicas_ativas('Renal');"
  ```
* **Docker:**
  ```powershell
  docker exec -it pg-juntamed psql -U postgres -d cdss_juntamed -c "SELECT * FROM buscar_diretrizes_clinicas_ativas('Renal');"
  ```

Resultado esperado: retorno do protocolo **`PCDT Injúria Renal Aguda e Ajuste de Antimicrobianos - CONITEC/MS`**.

> **Dica de acentuação no Windows:** Se os acentos aparecerem desconfigurados no terminal PowerShell, execute `chcp 65001` antes de rodar o `psql`.

---

## Boas Práticas de Trabalho em Dupla (Git)

1. **Antes de começar a editar**, sempre baixe as alterações mais recentes:
   ```powershell
   git pull origin main
   ```
2. **Reexecução segura:** Todos os scripts SQL são idempotentes (`DROP TABLE IF EXISTS`, `CREATE INDEX IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `TRUNCATE ... RESTART IDENTITY`). Sempre que houver alteração nos arquivos `.sql`, basta rodá-los novamente na ordem.
3. **Segurança de credenciais:** Nunca envie arquivos `.env` com senhas reais para o repositório; utilize o `.env.example` apenas como modelo de variáveis.