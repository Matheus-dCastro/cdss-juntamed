# Plano de Execução, Clean Architecture e Quadro Kanban — CDSS-JuntaMed (MVP Python)

> **Projeto:** CDSS-JuntaMed — Sistema de Suporte à Decisão Clínica e Auditoria Prescritiva com Junta Médica Multiagente (IMD0401 · UFRN)  
> **Equipe:** Maria Clara Silva Brito & Matheus Vinícius Silva Freire de Castro  
> **Base analisada:** `sql/01..05`, `specs/spec_01..03.yaml`, `README.md`, `docs/documenta_o_de_configura_o_cdss_juntamed.md`, `docs/Entrega 1 e 2 ja feitas - Banco de Dados.pdf` e `docs/entrega_3.pdf`

---

## 1. Alinhamento de Datas, Prazos e Premissas

> [!IMPORTANT]
> **Atenção ao calendário oficial da disciplina vs. meta do time:**  
> O edital em `docs/entrega_3.pdf` registra prazo de envio no SIGAA em **30/11/2026** (PDF + `.zip` + slides) e apresentações nos dias **01, 03 e 08/12/2026**.  
> Conforme definido pelo time, este plano organiza a entrega do **MVP mínimo funcional em Python até Domingo, 06/12/2026**, considerando:
> - **Sex 27/11/2026:** Preparação e alinhamento inicial.
> - **Sáb 28/11 e Dom 29/11/2026:** **Sem trabalho no projeto** (fim de semana reservado).
> - **Seg 30/11 a Dom 06/12/2026:** Sprint de execução em Python (com **Seg 30/11** servindo de marco intermediário caso seja necessário envio prévio no SIGAA, e **Seg 07/12** como margem de ensaio caso a apresentação ocorra em **08/12**).

---

## 2. Diagnóstico do Estado Atual e Lacunas Mapeadas

Ao cruzar os scripts `sql/`, as `specs/` e os PDFs de Entrega 1–3, foram identificados pontos críticos que precisam virar issues explícitas no Kanban para atender à regra de rastreabilidade (*"Regras, ERD, funções, esquema e código contam a mesma história"*) e ao item 13(c) da Entrega 3 (*diferenças entre especificado e implementado*):

| Área | O que existe hoje no repo | Lacuna / Divergência encontrada | Impacto no Kanban |
| :--- | :--- | :--- | :--- |
| **Código Python (`etl/` / `src/`)** | Apenas `requirements.txt` e `.env.example`. | A pasta `etl/` citada no `README.md` não existe na branch `main`; não há código Python, CLI nem testes. | Criar estrutura Clean Architecture + ETL 2 estágios + Use Cases + CLI + `LEIAME.md`. |
| **Formas Normais (1FN/2FN/3FN)** | `paciente.alergias TEXT[]` e `exame_clinico(itemid, item_name)` em `01_ddl_tabelas.sql`. | `TEXT[]` fere a atomicidade da **1FN**; `itemid -> item_name` gera dependência transitiva (**3FN**). Item 12(a) da Entrega 3 exige demonstrar **3FN**. | `ISS-01`: decidir normalização (`paciente_alergia` / `catalogo_exame`) ou justificativa formal + checks no backend. |
| **Checks no Banco vs. Backend** | `CHECK`s no DDL (`idade`, `escore_sofa`, `seq_exame`, `indice_discordancia`, `num_parecer`) e validações em PL/pgSQL (`FN-02`, `FN-06`, `FN-07`). | Regra solicitada: trazer validações de **formas normais, domínios e checks para dentro do backend Python**. | `ISS-02`, `ISS-06`, `ISS-07`, `ISS-08`: centralizar validações na camada `domain` em Python. |
| **Atributos da Entrega 2 ausentes no DDL** | DDL enxuto em `01_ddl_tabelas.sql`. | Faltam campos citados no catálogo da Entrega 2: `medico.especialidade`, `unidade_saude.codigo_municipio`, `paciente.genero`, `atendimento.co_cnes` / `dischtime` / `motivo_admissao`, `sessao_junta.data_hora_abertura` / `status_sessao`, `parecer_agente.hipotese_diagnostica` / `risco_detectado`, `agente_ia.nome_agente`, `diretriz_clinica.url_protocolo`. | `ISS-01`: fechar contrato único (adicionar colunas essenciais ou registrar mudança no Item 13c). |
| **`FN-06` vs. `spec_02`** | `FN-06` aceita `>= 1` parecer, recebe `p_indice_discordancia` pronto e retorna `INT`. | `spec_02` e Entrega 2 exigem **mínimo 2 pareceres**, hipótese/risco, cálculo de `indice_discordancia` e retorno de alertas de viés (> 60%). | `ISS-03`, `ISS-09`, `ISS-21`: cálculo e checagem de >= 2 pareceres no Domain/UseCase + alinhamento SQL. |
| **`FN-07` vs. `spec_03`** | `FN-07` dá `FOR SHARE` em `medicamento`, olha `flag_anormal` e retorna `BOOLEAN`. | `spec_03` e Entrega 2 pedem `FOR SHARE` no último exame de creatinina (`valuenum > 1.5 mg/dL`) e retorno com `status_prescricao`, `alerta_renal` e `mensagem_orientativa`. | `ISS-03`, `ISS-14`, `ISS-21`: leitura consistente e regra renal completa no backend + query com `FOR SHARE`. |
| **`FN-10` (SOFA)** | `FN-10` calcula `LEAST(24, count_anormais * 2)`. | Entrega 2 descreve cálculo sobre parâmetros (Plaquetas, Bilirrubina, Creatinina etc.) com categoria de risco. | `ISS-09`, `ISS-21`: serviço de cálculo SOFA no backend + documentação do critério adotado. |
| **Tabela de rejeição ETL** | `02_ddl_staging_auditoria.sql` cria `etl_audit_log`. | Entrega 2 cita o nome `carga_rejeitada_log`. | `ISS-02`, `ISS-18`: padronizar uso de `etl_audit_log` e registrar no Item 13(c). |

---

## 3. Estratégia: Formas Normais e `CHECK`s dentro do Backend Python

Para atender simultaneamente ao pedido do time (*migrar/centralizar formas normais e checks dentro do backend*) e à exigência da disciplina (*demonstrar 3FN e rastreabilidade no banco*), adotamos a seguinte divisão clara de responsabilidades:

### 3.1. Formas Normais (1FN, 2FN, 3FN)
1. **1FN — Atomicidade de `alergias` (`PACIENTE`)**:
   - **No Backend (`Domain`)**: `Paciente` modela `alergias` como coleção tipada e normalizada (`tuple[Alergia, ...]` / conjunto deduplicado, sem strings compostas por vírgula). O pipeline ETL e os checks de entrada explodem, limpam e validam cada alergia individualmente.
   - **No PostgreSQL (`DDL`)**: Opção recomendada para 3FN rigorosa na Entrega 3 — substituir `alergias TEXT[]` por tabela normalizada `paciente_alergia(subject_id, alergia)` (`PK` composta), mantendo no `Domain` o check de atomicidade e unicidade antes de persistir.
2. **2FN/3FN — Dependência transitiva `itemid -> item_name` (`EXAME_CLINICO`)**:
   - **No Backend (`Domain`)**: Criar check de consistência entre `itemid` e `item_name` (catálogo canônico dos marcadores críticos: ex. `50912 -> Creatinina`, `50813 -> Lactato`, Plaquetas, Bilirrubina) garantindo que um mesmo `itemid` nunca entre com nomes/unidades conflitantes.
   - **No PostgreSQL (`DDL`)**: Avaliar na `ISS-01` criar tabela `catalogo_exame(itemid PK, item_name, valueuom_padrao)` (3FN pura) **ou** justificar formalmente a desnormalização controlada em `exame_clinico` para manter a consulta da Spec 1 sem `JOIN` extra.
3. **3FN — Atributos derivados (`escore_sofa`, `indice_discordancia`, `alerta_renal`)**:
   - Nenhum campo derivado é aceito como input arbitrário externo no backend: todos são calculados deterministicamente por **Domain Services** em Python a partir dos dados atômicos antes da gravação no banco.

### 3.2. Mapeamento dos `CHECK`s e Regras (R1–R8) para o Backend

| Regra / Check | Como estava no SQL | Como fica no Backend Python (`domain/`) | Papel residual do PostgreSQL |
| :--- | :--- | :--- | :--- |
| **Faixas numéricas** (`idade`, `escore_sofa`, `indice_discordancia`, `seq_exame`, `num_parecer`) | `CHECK (...)` direto no `CREATE TABLE` | **Value Objects** (`IdadePaciente`, `EscoreSofa`, `IndiceDiscordancia`, `SequencialPositivo`) validados na criação da entidade, levantando `DomainValidationError`. | `NOT NULL` e tipos base; `CHECK`s removidos do DDL (ou mantidos apenas se o grupo optar por dupla barreira — decidir na `ISS-02`). |
| **Formatos e Domínios** (`crm`, `co_cnes`, `num_registro`, `motivo_admissao`, `situacao_registro`, `categoria_risco_renal`) | Sem `CHECK` completo no DDL (apenas `VARCHAR` + checagem parcial em `FN-07`) | **Value Objects & Enums** (`CRM` 4–10 chars, `CoCnes` 6–7 dígitos, `RegistroAnvisa` 13 chars alfanuméricos/dígitos, `SituacaoRegistro`, `RiscoRenal`, `MotivoAdmissao` 5–500 chars). | Índices e PK/FK. |
| **Regra R1** (Médico ↔ Unidade N:M) | `IF NOT EXISTS` em `FN-02` | **Policy `RegraLotacaoService`**: valida vínculo ativo em `lota` antes de abrir atendimento e impede cadastro de médico sem ao menos 1 unidade no ETL/UseCase. | Tabela associativa `lota` com FKs. |
| **Regra R2/R3** (Atendimento exige Paciente + Médico) | FKs em `atendimento` | **Agregado `Atendimento`**: exige `subject_id`, `crm` e `co_cnes` válidos no domínio antes de persistir. | `NOT NULL` + `FOREIGN KEY`. |
| **Regra R4** (Exame pertence ao Atendimento) | `PK(hadm_id, seq_exame)` + `FOR UPDATE` em `FN-04` | **Entidade `ExameClinico`**: exige `hadm_id` existente e `seq_exame > 0` + sanitização de unidade (`UNID_NAO_INFORMADA`). | `FOR UPDATE` em `atendimento` para serializar `seq_exame` sob concorrência. |
| **Regras R5, R6, R7** (Sessão ≥ 2 pareceres, Agente válido, ≥ 1 Diretriz por parecer) | Trigger `DEFERRABLE` em `parecer_agente` + loop em `FN-06` | **Agregado `SessaoJunta`**: garante no construtor/método de domínio `>= 2` pareceres (`spec_02`), cada um com `id_agente` e `>= 1 id_diretriz` (bloqueia antes de tocar o BD!). | Transação única (`BEGIN..COMMIT`) ao inserir `sessao_junta` + `parecer_agente` + `fundamenta` (com rollback total em falha). |
| **Regra R8** (Prescrição + Alerta Renal) | `FN-07` simplificada | **Domain Service `AvaliadorRiscoRenal`**: bloqueia medicamento `situacao_registro != 'VALIDO'`, cruza `categoria_risco_renal` (`MODERADO`/`ALTO`) com última creatinina (`> 1.5 mg/dL` ou `flag_anormal`) e gera `alerta_renal` + `mensagem_orientativa`. | Leitura consistente com `FOR SHARE` no exame de creatinina/medicamento dentro da transação de `PRESCREVE`. |

---

## 4. Arquitetura Clean Architecture em Python (Escopo MVP)

Regra absoluta de dependência:  
`presentation` $\rightarrow$ `application` $\rightarrow$ `domain` $\leftarrow$ `infrastructure`  
*(A camada `domain` contém Python puro — zero dependência de `psycopg`, `pandas`, `requests` ou CLI).*

```text
cdss-juntamed/
├── docs/
│   └── KANBAN_PLANO_MVP.md
├── sql/
│   ├── 01_ddl_tabelas.sql
│   ├── 02_ddl_staging_auditoria.sql
│   ├── 03_indices.sql
│   ├── 04_funcoes_transacoes.sql
│   └── 05_seed_inicial.sql
├── specs/
│   ├── spec_01_listar_exames_criticos.yaml
│   ├── spec_02_convocar_junta_deliberativa.yaml
│   └── spec_03_prescrever_medicamento_com_alerta.yaml
├── src/
│   └── cdss_juntamed/
│       ├── domain/
│       │   ├── exceptions.py                 # Erros de domínio e violação R1–R8
│       │   ├── value_objects/                # CRM, CoCnes, RegistroAnvisa, Idade, EscoreSofa, IndiceDiscordancia
│       │   ├── entities/                     # Paciente, Medico, UnidadeSaude, Atendimento, ExameClinico, SessaoJunta, Medicamento, Prescricao
│       │   ├── checks/                       # Validadores de domínio, 1FN/3FN e políticas R1–R8
│       │   ├── services/                     # CalculadoraSofa, CalculadoraDiscordancia, AvaliadorRiscoRenal
│       │   └── repositories/                 # Interfaces (Protocol/ABC) de persistência
│       ├── application/
│       │   ├── dto/                          # DTOs de entrada/saída (Specs 01–03 e FNs)
│       │   ├── interfaces/                   # UnitOfWork, FonteDadosPort, AgenteJuntaPort
│       │   └── use_cases/
│       │       ├── etl/                      # Extract, LoadStaging (audit log), MergeProduction
│       │       └── clinico/                  # FN-01 a FN-10 (com destaque às Specs 01, 02 e 03)
│       ├── infrastructure/
│       │   ├── config/                       # Carregamento de .env (DB_*, caminhos/URLs)
│       │   ├── database/                     # PostgresConnectionFactory e PostgresUnitOfWork (BEGIN/COMMIT/ROLLBACK)
│       │   ├── repositories/                 # Repositórios psycopg3 (com FOR UPDATE e FOR SHARE)
│       │   ├── etl/                          # Extractors CNES (API/CSV), ANVISA (CSV), MIMIC-IV (CSV)
│       │   └── ai/                           # AgenteJuntaDeterministico (ou adaptador LLM opcional)
│       └── presentation/
│           └── cli/                          # Interface CLI interativa e comandos de demonstração
├── tests/
│   ├── unit/                                 # Testes dos checks no backend e regras R1–R8 (sem BD)
│   └── integration/                          # Testes no PostgreSQL (ETL, Spec 1, Spec 2 rollback, Spec 3 FOR SHARE, FN-04 concorrência)
├── main.py                                   # Entrypoint único do protótipo
├── LEIAME.md                                 # Guia exigido pela Entrega 3 (máquina limpa)
├── requirements.txt
└── .env.example
```

---

## 5. Recorte do MVP para 06/12/2026

### O que ENTRA no MVP (Must-Have até 06/12)
1. **Banco PostgreSQL ajustado e reprodutível** (`01`..`05` rodando sem erro em Docker ou local).
2. **Camada `domain` completa com todos os checks de domínio, formas normais e R1–R8** testados unitariamente.
3. **ETL Python real em duplo estágio (`stg_*` + `etl_audit_log` $\rightarrow$ produção)**:
   - Consome **OpenDataSUS/CNES** (API REST ou CSV oficial com fallback resiliente), **ANVISA** (CSV com detecção de encoding/delimitador) e **MIMIC-IV Demo** (`patients.csv`, `admissions.csv`, `labevents.csv`).
   - Aplica sanitização, rejeição auditada em `etl_audit_log` e carga atômica com `ON CONFLICT` / `ROW_NUMBER()`.
4. **Casos de uso das 10 funções (`FN-01` a `FN-10`) operando sobre o banco carregado**, garantindo principalmente:
   - **Spec 1 (`FN-05`)**: `listar_exames_criticos_atendimento` usando índice B-Tree composto.
   - **Spec 2 (`FN-06`)**: `convocar_junta_deliberativa` com $\ge 2$ pareceres, diretrizes CONITEC obrigatórias, cálculo de discordância + alerta de viés (> 60%) e rollback total em falha.
   - **Spec 3 (`FN-07`)**: `prescrever_medicamento_com_alerta` com `FOR SHARE`, verificação de registro ANVISA ativo e alerta renal (`creatinina > 1.5 mg/dL`).
   - **Concorrência (`FN-04`)** e **Escore derivado (`FN-10`)**.
5. **CLI funcional (`main.py`)** para executar ETL, demonstrar todas as funções e exibir saídas reais formatadas no terminal.
6. **Suíte de testes automatizados (`pytest`)** + **`LEIAME.md`** + evidências para o relatório final (itens 12a, 13b, 13c) e slides.

### O que FICA FORA do MVP (Backlog Pós-06/12)
- Interface Web visual (HTML/React/Streamlit) ou API REST FastAPI completa *(só entra como bônus se tudo do MVP já estiver verde antes de 06/12)*.
- Integração obrigatória com API paga de LLM externo *(o motor da Junta usa adaptador `AgenteJuntaPort` com implementação determinística baseada nos exames + diretrizes CONITEC, mantendo possibilidade de plugar LLM depois sem alterar `domain`/`application`)*.

---

## 6. Organização do Quadro Kanban

### Colunas sugeridas
`Backlog` $\rightarrow$ `To Do (Sprint)` $\rightarrow$ `In Progress` $\rightarrow$ `Review / Testes` $\rightarrow$ `Done`

### Labels padrão
- **Épicos:** `epic:sql-normalizacao`, `epic:domain-checks`, `epic:infra-db`, `epic:etl`, `epic:use-cases-cli`, `epic:docs-entrega`
- **Prioridade:** `P0-MVP` (obrigatório para 06/12), `P1-MVP` (importante para qualidade/apresentação), `P2-Bonus` (só se sobrar tempo)
- **Divisão sugerida na dupla** *(lembrando a Premissa d: ambos devem dominar e explicar tudo)*:
  - **Dev A (Foco Dados/SQL/ETL/Infra):** SQL/Normalização, PostgreSQL/UnitOfWork, Extractors CNES/ANVISA/MIMIC, Load Staging/Merge, Testes de Integração.
  - **Dev B (Foco Arquitetura/Domínio/Casos de Uso/CLI):** Esqueleto Clean Architecture, Value Objects/Checks no Backend, Serviços de Domínio, Use Cases Clínicos, Motor da Junta, CLI e Testes Unitários.

---

## 7. Épicos, Issues e Tasks para o Kanban

### ÉPICO 1 — Governança de Dados, Formas Normais e Alinhamento SQL (`epic:sql-normalizacao`)

#### `ISS-01` — Auditar e alinhar DDL (`01_ddl_tabelas.sql`) com 1FN/2FN/3FN e Catálogo da Entrega 2
- **Prioridade:** `P0-MVP` | **Responsável:** Dupla (Dev A lidera PR) | **Camada:** SQL / Modelagem | **Estimativa:** 2h | **Dia alvo:** Sex 27/11
- **Dependências:** Nenhuma
- **Contexto:** Resolver divergências estruturais antes de escrever entidades Python e garantir demonstração limpa de **3FN** (Item 12a da Entrega 3).
- **Subtasks:**
  - [ ] Decidir tratamento de **1FN** em `paciente.alergias`: criar tabela `paciente_alergia(subject_id, alergia)` ou manter `TEXT[]` com justificativa formal (recomendado: normalizar para `paciente_alergia`).
  - [ ] Decidir tratamento de **3FN** em `exame_clinico(itemid, item_name)`: extrair `catalogo_exame(itemid PK, item_name, valueuom_padrao)` ou justificar desnormalização para Spec 1.
  - [ ] Alinhar colunas faltantes citadas na Entrega 2/Specs: `atendimento.co_cnes` e `motivo_admissao`; `parecer_agente.hipotese_diagnostica` e `risco_detectado`; `sessao_junta.data_hora_abertura` e `status_sessao`; `diretriz_clinica.url_protocolo`; `medico.especialidade`; `unidade_saude.codigo_municipio`; `paciente.genero`; `agente_ia.nome_agente`.
  - [ ] Anotar cada mudança/escolha para o histórico do Item 13(c).
- **Critérios de Aceite:**
  - DDL fechado, versionado e 100% compatível com o ERD revisado e com o modelo de entidades do backend.

#### `ISS-02` — Migrar `CHECK`s do SQL para o Backend e padronizar tabela de auditoria ETL
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** SQL / Arquitetura | **Estimativa:** 1h30 | **Dia alvo:** Sex 27/11
- **Dependências:** `ISS-01`
- **Contexto:** Concretizar a diretriz *"mudança das formas normais e checks para dentro do backend"* e padronizar `etl_audit_log` vs. `carga_rejeitada_log`.
- **Subtasks:**
  - [ ] Remover ou documentar claramente a transferência dos `CHECK`s de domínio (`idade`, `escore_sofa`, `seq_exame`, `indice_discordancia`, `num_parecer`) de `sql/01_ddl_tabelas.sql` para validadores explícitos no backend Python (`domain/checks`).
  - [ ] Manter no PostgreSQL integridade estrutural (`PRIMARY KEY`, `FOREIGN KEY`, `NOT NULL`, `UNIQUE`) e locks transacionais (`FOR UPDATE`, `FOR SHARE`).
  - [ ] Confirmar uso único do nome `etl_audit_log` em `sql/02_ddl_staging_auditoria.sql` e atualizar referência no relatório (antigo `carga_rejeitada_log`).
- **Critérios de Aceite:**
  - Matriz de responsabilidade ("o que o Backend checa" vs. "o que o PostgreSQL garante") documentada e scripts `01`/`02` atualizados.

#### `ISS-03` — Alinhar regras transacionais (`FN-02`, `FN-04`, `FN-06`, `FN-07`, `FN-10`) com `specs/`
- **Prioridade:** `P0-MVP` | **Responsável:** Dupla | **Camada:** SQL / Application | **Estimativa:** 2h | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-01`, `ISS-02`
- **Contexto:** Corrigir divergências entre `sql/04_funcoes_transacoes.sql` e `specs/spec_01..03.yaml`.
- **Subtasks:**
  - [ ] Definir estratégia: mover orquestração e regras de negócio de `FN-06` (mínimo 2 pareceres, cálculo de discordância, alerta de viés), `FN-07` (`FOR SHARE` na creatinina + `valuenum > 1.5` + mensagem orientativa) e `FN-10` (SOFA real) para Use Cases em Python + queries SQL parametrizadas, mantendo compatibilidade caso o banco seja testado diretamente via `psql`.
  - [ ] Atualizar `sql/04_funcoes_transacoes.sql` e `sql/05_seed_inicial.sql` se houver novas colunas (ex.: `nome_agente`, `url_protocolo`).
- **Critérios de Aceite:**
  - Spec 1, Spec 2 e Spec 3 têm contrato único (entradas, locks, regras e retornos) entre código Python, YAML e SQL.

#### `ISS-04` — Validar execução limpa de `sql/01` a `sql/05` e `sql/03_indices.sql`
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** SQL / Infra | **Estimativa:** 1h | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-01`, `ISS-02`, `ISS-03`
- **Subtasks:**
  - [ ] Subir PostgreSQL limpo (Docker `postgres:17` ou local) e executar `01` $\rightarrow$ `05` com `-v ON_ERROR_STOP=1`.
  - [ ] Conferir tabelas principais, `stg_*`, `etl_audit_log`, índices (`idx_exame_clinico_criticos`) e seed inicial (`diretriz_clinica` e `agente_ia`).
- **Critérios de Aceite:**
  - Execução idempotente sem erros ou warnings bloqueantes em banco recém-criado.

---

### ÉPICO 2 — Fundação Clean Architecture, Domínio e Checks no Backend (`epic:domain-checks`)

#### `ISS-05` — Criar estrutura base do pacote Python em Clean Architecture
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Arquitetura | **Estimativa:** 1h30 | **Dia alvo:** Sex 27/11
- **Dependências:** Nenhuma
- **Subtasks:**
  - [ ] Criar árvore `src/cdss_juntamed/{domain,application,infrastructure,presentation}` com subpacotes e `__init__.py`.
  - [ ] Criar `tests/{unit,integration}`, `main.py` e configurar `pyproject.toml` / `PYTHONPATH` para importação limpa.
  - [ ] Atualizar `requirements.txt` adicionando `pytest` (e `typer` ou `rich`, se escolhidos para CLI — ou manter `argparse` da stdlib para zero risco).
- **Critérios de Aceite:**
  - `pytest` roda na raiz e `python main.py --help` executa sem erros de importação; `domain` não importa bibliotecas externas de infra.

#### `ISS-06` — Implementar Exceções de Domínio e Value Objects com Checks
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Domain | **Estimativa:** 3h | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-05`
- **Subtasks:**
  - [ ] Criar hierarquia de exceções em `domain/exceptions.py`: `DomainValidationError`, `NormalizacaoVioladaError`, `RegraNegocioVioladaError` (R1–R8), `EntidadeNaoEncontradaError`, `PrescricaoBloqueadaError`.
  - [ ] Implementar Value Objects imutáveis (`@dataclass(frozen=True)`) com validação no `__post_init__`:
    - `CRM` (texto 4–10 chars não vazio, normalizado).
    - `CoCnes` (código numérico válido, 6–7 dígitos com normalização).
    - `RegistroAnvisa` (13 caracteres, conforme Spec 3).
    - `IdadePaciente` (`0 <= idade <= 130`).
    - `EscoreSofa` (`0 <= valor <= 24`, com classificação de risco).
    - `IndiceDiscordancia` (`0.0 <= valor <= 100.0`).
    - `MotivoAdmissao` (5 a 500 caracteres).
    - `Posologia` (texto obrigatório não vazio, até 200 caracteres).
- **Critérios de Aceite:**
  - Qualquer valor fora de faixa ou formato inválido falha imediatamente na instanciação do Value Object sem depender de banco de dados.

#### `ISS-07` — Modelar Entidades, Entidades Fracas e Checks de Normalização (1FN/2FN/3FN)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Domain | **Estimativa:** 3h30 | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-06`, `ISS-01`
- **Subtasks:**
  - [ ] Modelar entidades fortes: `UnidadeSaude`, `Medico`, `Paciente`, `Atendimento`, `SessaoJunta`, `AgenteIA`, `DiretrizClinica`, `Medicamento`.
  - [ ] Modelar entidades fracas: `ExameClinico` (`hadm_id`, `seq_exame > 0`, `itemid`, `item_name`, `valuenum`, `valueuom`, `charttime`, `flag_anormal`) e `ParecerAgente` (`id_sessao`, `num_parecer > 0`, `id_agente`, `texto_parecer`, `hipotese`, `risco`, `diretrizes_ids`).
  - [ ] Modelar associações: `Prescricao` (`hadm_id`, `num_registro`, `posologia`, `alerta_renal`, `data_prescricao`).
  - [ ] Implementar **Checks das Formas Normais no Backend** (`domain/checks/normalizacao.py`):
    - **Check 1FN (`Paciente`)**: validar que cada item de alergia é atômico (sem delimitadores compostos `,`/`;`, sem nulos ou duplicados).
    - **Check 2FN/3FN (`ExameClinico`)**: validar coerência entre `itemid` e `item_name` / unidade canônica e impedir atributos derivados inconsistentes (`escore_sofa`, `indice_discordancia`).
- **Critérios de Aceite:**
  - Todas as 13 entidades/relações do ERD estão representadas em `domain/entities/` com invariantes verificadas no construtor/métodos.

#### `ISS-08` — Implementar Policies e Checks das Regras de Negócio R1–R8 no Backend
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Domain | **Estimativa:** 3h | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-07`
- **Subtasks:**
  - [ ] **R1**: validar que médico tem ao menos 1 `co_cnes` vinculado antes de atuar/abrir atendimento.
  - [ ] **R2 / R3 / R4**: garantir vínculo obrigatório de `Atendimento` a `Paciente` + `Medico` e de `ExameClinico` a `Atendimento`.
  - [ ] **R5 / R6 / R7**: no agregado `SessaoJunta.criar(...)`, exigir **mínimo 2 pareceres** de agentes distintos (`spec_02`), cada um emitido por um `AgenteIA` válido e vinculado a **pelo menos 1 `id_diretriz`** (impedindo na aplicação o que antes só disparava na trigger `DEFERRABLE`).
  - [ ] **R8**: na política de prescrição, bloquear medicamento com `situacao_registro != 'VALIDO'` e exigir avaliação de disfunção renal.
- **Critérios de Aceite:**
  - Tentativa de violar qualquer regra R1–R8 no backend levanta `RegraNegocioVioladaError` explícita com código da regra (`R1`..`R8`).

#### `ISS-09` — Implementar Serviços de Domínio (`SOFA`, `Discordância/Viés` e `Risco Renal`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Domain | **Estimativa:** 3h | **Dia alvo:** Ter 01/12
- **Dependências:** `ISS-07`, `ISS-08`
- **Subtasks:**
  - [ ] `CalculadoraSofaService`: calcular pontuação SOFA (0–24) a partir dos exames laboratoriais mais recentes do atendimento (Plaquetas, Bilirrubina, Creatinina e fallback documentado para exames anormais) + retornar categoria de risco de mortalidade.
  - [ ] `CalculadoraDiscordanciaService`: calcular `indice_discordancia` (0–100%) a partir da divergência entre hipóteses/níveis de risco dos pareceres e emitir alerta de **viés de ancoragem** quando `indice_discordancia > 60%`.
  - [ ] `AvaliadorRiscoRenalService`: cruzar `categoria_risco_renal` do medicamento (`MODERADO`/`ALTO`) com a última dosagem de creatinina sérica (`valuenum > 1.5 mg/dL` ou `flag_anormal = True`) e gerar `(alerta_renal: bool, mensagem_orientativa: str)`.
- **Critérios de Aceite:**
  - Cálculos 100% determinísticos em Python puro, fáceis de explicar na banca e com casos de borda testados.

#### `ISS-10` — Definir Portas/Contratos de Repositórios e `UnitOfWork`
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Domain / Application | **Estimativa:** 1h30 | **Dia alvo:** Ter 01/12
- **Dependências:** `ISS-07`
- **Subtasks:**
  - [ ] Definir `Protocol`/`ABC` para: `CorpoClinicoRepository`, `PacienteRepository`, `AtendimentoRepository`, `ExameClinicoRepository`, `JuntaMedicaRepository`, `MedicamentoRepository`, `PrescricaoRepository`, `StagingRepository`.
  - [ ] Definir interface `UnitOfWork` (`__enter__`, `__exit__`, `commit()`, `rollback()`) e `AgenteJuntaPort`.
- **Critérios de Aceite:**
  - Camada `application` depende apenas das abstrações de `domain`/`application`, permitindo testar Use Cases com repositórios falsos em memória.

---

### ÉPICO 3 — Infraestrutura PostgreSQL e Repositórios (`epic:infra-db`)

#### `ISS-11` — Implementar Config `.env` e `PostgresUnitOfWork` (`psycopg3`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure | **Estimativa:** 2h | **Dia alvo:** Seg 30/11
- **Dependências:** `ISS-04`, `ISS-05`
- **Subtasks:**
  - [ ] Criar `Settings` lendo `.env` (`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `CNES_API_URL`, `ANVISA_CSV_PATH`, `MIMIC_DIR_PATH`).
  - [ ] Implementar fábrica de conexões `psycopg` v3 e `PostgresUnitOfWork` gerenciando `BEGIN` implícito, `COMMIT` ao sair sem erro e `ROLLBACK` automático em qualquer exceção.
- **Critérios de Aceite:**
  - Erro no meio de uma operação multi-tabela desfaz 100% das gravações anteriores na mesma UoW.

#### `ISS-12` — Implementar Repositórios de Corpo Clínico, Paciente e Atendimento
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure | **Estimativa:** 2h30 | **Dia alvo:** Qua 02/12
- **Dependências:** `ISS-10`, `ISS-11`
- **Subtasks:**
  - [ ] `PostgresCorpoClinicoRepository`: consulta `lota + medico + unidade_saude` (`FN-01`) e checagem de lotação (R1).
  - [ ] `PostgresPacienteRepository`: busca paciente + alergias normalizadas (`FN-03`) e histórico de atendimentos ordenados cronologicamente.
  - [ ] `PostgresAtendimentoRepository`: abre atendimento (`FN-02`), atualiza `escore_sofa` (`FN-10`) e verifica existência de `hadm_id`.
- **Critérios de Aceite:**
  - Queries parametrizadas (sem SQL injection) mapeando linhas diretamente para entidades/DTOs de domínio.

#### `ISS-13` — Implementar `PostgresExameClinicoRepository` (`FOR UPDATE`, Índice B-Tree e Última Creatinina)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure | **Estimativa:** 2h30 | **Dia alvo:** Qua 02/12
- **Dependências:** `ISS-10`, `ISS-11`
- **Subtasks:**
  - [ ] Implementar gravação de exame (`FN-04`) com `SELECT 1 FROM atendimento WHERE hadm_id = %s FOR UPDATE` antes de calcular `MAX(seq_exame) + 1`.
  - [ ] Implementar consulta da **Spec 1 (`FN-05`)** filtrando `hadm_id`, `flag_anormal = TRUE` (quando `apenas_anormais=True`), `ORDER BY charttime DESC LIMIT %s` usando o índice `idx_exame_clinico_criticos`.
  - [ ] Implementar busca dos últimos exames por `itemid`/nome para cálculo de SOFA (`FN-10`) e busca da **última creatinina sérica com `FOR SHARE`** para a Spec 3 (`FN-07`).
- **Critérios de Aceite:**
  - `EXPLAIN ANALYZE` da Spec 1 utiliza o índice composto em massa de dados do MIMIC-IV; inserções concorrentes no mesmo `hadm_id` não colidem na PK `(hadm_id, seq_exame)`.

#### `ISS-14` — Implementar Repositórios da Junta Médica e de Medicamentos/Prescrições (`FOR SHARE`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure | **Estimativa:** 2h30 | **Dia alvo:** Qua 02/12
- **Dependências:** `ISS-10`, `ISS-11`
- **Subtasks:**
  - [ ] `PostgresJuntaMedicaRepository`: persistir `sessao_junta` + N `parecer_agente` + N `fundamenta` na mesma transação (`FN-06`), consultar deliberações (`FN-08`) e buscar diretrizes ativas (`FN-09`) + listar agentes ativos.
  - [ ] `PostgresMedicamentoPrescricaoRepository`: ler medicamento com `FOR SHARE` (`FN-07`), validar existência/situação ANVISA e gravar `prescreve` com `posologia` e `alerta_renal`.
- **Critérios de Aceite:**
  - Falha no último parecer ou diretriz inexistente gera `ROLLBACK` total da sessão (`FN-06`); prescrição lê medicamento e creatinina com `FOR SHARE` antes de gravar (`FN-07`).

---

### ÉPICO 4 — Pipeline ETL em Duplo Estágio (`epic:etl`)

#### `ISS-15` — Implementar Extractor OpenDataSUS / CNES (API REST + Fallback CSV)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure / ETL | **Estimativa:** 3h | **Dia alvo:** Ter 01/12
- **Dependências:** `ISS-05`, `ISS-11`
- **Subtasks:**
  - [ ] Consultar endpoint paginado `CNES_API_URL` (ex.: recorte de estabelecimentos hospitalares / Natal-RN para manter volume ágil na máquina limpa) e ler CSV local se fornecido em `data/raw/`.
  - [ ] Aplicar política defensiva para `no_fantasia` nulo (usar `razao_social`) e extrair/preparar vínculos de médicos e unidades (`UNIDADE_SAUDE`, `MEDICO`, `LOTA`).
  - [ ] Garantir que a carga obtenha os dados da fonte sem exigir o arquivo bruto versionado no `.zip` (regra item 02(e) da Entrega 3).
- **Critérios de Aceite:**
  - Extractor retorna registros estruturados de unidades e corpo clínico prontos para staging, com tratamento de timeout/erro HTTP.

#### `ISS-16` — Implementar Extractor ANVISA (CSV com Detecção de Encoding e Delimitador)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure / ETL | **Estimativa:** 2h30 | **Dia alvo:** Ter 01/12
- **Dependências:** `ISS-05`, `ISS-11`
- **Subtasks:**
  - [ ] Detectar encoding (`chardet`: UTF-8 / ISO-8859-1) e delimitador dinâmico (`csv.Sniffer` para `;` ou `,`).
  - [ ] Padronizar conversão para UTF-8, limpar `NUMERO_REGISTRO_PRODUTO` (13 chars), `NOME_PRODUTO`, `SITUACAO_REGISTRO` (`VÁLIDO` $\rightarrow$ `VALIDO`) e classificar/mapear `categoria_risco_renal` (ex.: antibióticos nefrotóxicos como Vancomicina/Aminoglicosídeos/Meropenem).
  - [ ] Suportar download/leitura a partir de URL oficial ou arquivo em `data/raw/anvisa_medicamentos.csv`.
- **Critérios de Aceite:**
  - Arquivo ANVISA real com acentuação ISO-8859-1 e `;` é lido sem `UnicodeDecodeError`, preservando registros válidos e encaminhando inválidos para rejeição.

#### `ISS-17` — Implementar Extractor MIMIC-IV Demo v2.2 (`patients`, `admissions`, `labevents`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Infrastructure / ETL | **Estimativa:** 3h | **Dia alvo:** Ter 01/12
- **Dependências:** `ISS-05`, `ISS-11`
- **Subtasks:**
  - [ ] Ler `patients.csv`, `admissions.csv` e `labevents.csv` (suportando `.csv` ou `.csv.gz` direto da pasta configurada em `MIMIC_DIR_PATH` / download PhysioNet Demo).
  - [ ] Coergir decimais com vírgula (`"1,5"` $\rightarrow$ `1.5`), aplicar default `'UNID_NAO_INFORMADA'` em `valueuom` ausente e derivar `flag_anormal` a partir do campo `flag` (`abnormal`) ou faixas de referência.
  - [ ] Vincular médicos/unidades carregados do CNES às admissões do MIMIC-IV na etapa de integração controlada para atender R1–R3.
- **Critérios de Aceite:**
  - Subconjunto real dos 100 pacientes / ~250 internações e exames laboratoriais (incluindo Creatinina `50912` e Lactato `50813`) extraído e pronto para staging.

#### `ISS-18` — Implementar `LoadStagingUseCase` (Stage 1 + Checks Defensivos + `etl_audit_log`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Application / Infrastructure | **Estimativa:** 2h30 | **Dia alvo:** Qua 02/12
- **Dependências:** `ISS-07`, `ISS-15`, `ISS-16`, `ISS-17`
- **Subtasks:**
  - [ ] Criar estágio 1 usando os **checks de domínio** do backend para validar registros antes da promoção:
    - Registros sem chave essencial (`num_registro` nulo/inválido, `co_cnes` inválido, `hadm_id`/`subject_id` ausente, `valuenum` inválido) são rejeitados e gravados em `etl_audit_log` com `fonte`, `registro_bruto` e `motivo_rejeicao`.
    - Registros válidos são gravados nas 6 tabelas `stg_*` (usando `COPY` ou `executemany` eficiente no `psycopg`).
- **Critérios de Aceite:**
  - Dados sujos propositalmente não quebram o lote nem contaminam a produção; ficam registrados em `etl_audit_log` com resumo de aceitos vs. rejeitados.

#### `ISS-19` — Implementar `MergeProductionUseCase` (Stage 2: Transação Única ACID)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Application / Infrastructure | **Estimativa:** 2h30 | **Dia alvo:** Qua 02/12
- **Dependências:** `ISS-18`
- **Subtasks:**
  - [ ] Executar migração `stg_*` $\rightarrow$ tabelas principais dentro de **uma única transação (`PostgresUnitOfWork`)**:
    - CNES (`unidade_saude`, `medico`, `lota`) e ANVISA (`medicamento`): `INSERT ... ON CONFLICT (...) DO UPDATE SET ...`.
    - MIMIC-IV (`paciente`, `paciente_alergia` se normalizado, `atendimento`): upsert sem duplicação.
    - `exame_clinico`: deduplicação via `ROW_NUMBER() OVER (PARTITION BY hadm_id, itemid, charttime ORDER BY charttime DESC)` gerando `seq_exame` incremental por `hadm_id`.
  - [ ] Em qualquer erro de banco durante o merge, disparar `ROLLBACK` total sem deixar carga pela metade.
- **Critérios de Aceite:**
  - Rodar o ETL duas vezes seguidas (idempotência) não duplica registros nem falha por chave duplicada; falha simulada no meio do merge reverte toda a operação.

---

### ÉPICO 5 — Casos de Uso Clínicos, Motor da Junta, CLI e Testes (`epic:use-cases-cli`)

#### `ISS-20` — Implementar Casos de Uso de Leitura (`FN-01`, `FN-03`, `FN-05` [Spec 1], `FN-08`, `FN-09`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Application | **Estimativa:** 2h30 | **Dia alvo:** Qui 03/12
- **Dependências:** `ISS-10`, `ISS-12`, `ISS-13`, `ISS-14`
- **Subtasks:**
  - [ ] `AutenticarEConsultarCorpoClinicoUseCase` (`FN-01`).
  - [ ] `ConsultarHistoricoPacienteUseCase` (`FN-03`).
  - [ ] `ListarExamesCriticosAtendimentoUseCase` (`FN-05` / Spec 1: validar `1 <= limite <= 100`, `hadm_id` existente, ordenar por `charttime DESC`).
  - [ ] `ConsultarDeliberacoesJuntaUseCase` (`FN-08`).
  - [ ] `BuscarDiretrizesClinicasAtivasUseCase` (`FN-09`).
- **Critérios de Aceite:**
  - Todos os 5 casos de uso retornam DTOs limpos com validação de entrada no backend.

#### `ISS-21` — Implementar Casos de Uso Transacionais (`FN-02`, `FN-04`, `FN-06` [Spec 2], `FN-07` [Spec 3], `FN-10`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Application | **Estimativa:** 4h | **Dia alvo:** Qui 03/12
- **Dependências:** `ISS-08`, `ISS-09`, `ISS-10`, `ISS-12`, `ISS-13`, `ISS-14`
- **Subtasks:**
  - [ ] `AbrirAtendimentoClinicoUseCase` (`FN-02`): valida R1, R2, R3 e cria atendimento com `escore_sofa = 0`.
  - [ ] `RegistrarResultadoExameUseCase` (`FN-04`): aplica checks de domínio/3FN e grava sob lock `FOR UPDATE`.
  - [ ] `ConvocarJuntaDeliberativaUseCase` (`FN-06` / Spec 2): lê atendimento + exames, exige $\ge 2$ agentes e diretrizes CONITEC válidas (R5–R7), calcula `indice_discordancia` + alerta de viés (> 60%) via `Domain Service`, e grava `sessao_junta` + `parecer_agente` + `fundamenta` em transação atômica com rollback total.
  - [ ] `PrescreverMedicamentoComAlertaUseCase` (`FN-07` / Spec 3): lê medicamento e última creatinina com `FOR SHARE`, valida situação `VALIDO` na ANVISA, avalia risco renal (R8) e persiste `prescreve` retornando `status_prescricao`, `alerta_renal` e `mensagem_orientativa`.
  - [ ] `CalcularEscoreGravidadeSofaUseCase` (`FN-10`): lê últimos exames, calcula SOFA (0–24) + categoria de risco e atualiza `atendimento`.
- **Critérios de Aceite:**
  - Todas as 5 operações de escrita funcionam de ponta a ponta contra o PostgreSQL respeitando atomicidade e regras R1–R8.

#### `ISS-22` — Implementar Adaptador `AgenteJuntaProvider` (Motor Multiagente Determinístico / Plugável)
- **Prioridade:** `P1-MVP` | **Responsável:** Dev B | **Camada:** Infrastructure / AI | **Estimativa:** 2h | **Dia alvo:** Qui 03/12
- **Dependências:** `ISS-10`, `ISS-20`
- **Contexto:** Garantir que a demonstração da Junta Médica (Spec 2) funcione offline/em máquina limpa sem depender de chaves pagas de API externa, mantendo arquitetura pronta para LLM.
- **Subtasks:**
  - [ ] Implementar `MotorJuntaClinicaLocal` que analisa os exames críticos do atendimento (ex.: creatinina alta, lactato elevado), compara com a `hipotese_assistente` e seleciona pareceres dos agentes cadastrados (Risco SOFA, Advogado do Diabo / Red-Teaming, Auditoria Renal, Conformidade CONITEC) sempre amarrados a `id_diretriz` reais do banco.
- **Critérios de Aceite:**
  - Ao convocar a junta para um paciente real do MIMIC-IV na demo, o motor produz pelo menos 2 pareceres coerentes com diretrizes reais do seed `05_seed_inicial.sql`.

#### `ISS-23` — Construir Interface Mínima CLI (`presentation/cli` + `main.py`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Presentation | **Estimativa:** 3h | **Dia alvo:** Sex 04/12
- **Dependências:** `ISS-19`, `ISS-20`, `ISS-21`, `ISS-22`
- **Subtasks:**
  - [ ] Criar CLI estruturada com subcomandos claros (usando `argparse` ou `typer`):
    - `etl run` (executa carga completa staging $\rightarrow$ produção e imprime estatísticas + rejeições de `etl_audit_log`).
    - `clinica corpo-clinico` (`FN-01`), `clinica abrir-atendimento` (`FN-02`), `clinica historico` (`FN-03`).
    - `exames registrar` (`FN-04`), `exames criticos` (`FN-05` / Spec 1), `clinica calcular-sofa` (`FN-10`).
    - `junta convocar` (`FN-06` / Spec 2), `junta consultar` (`FN-08`), `diretrizes buscar` (`FN-09`).
    - `prescricao criar` (`FN-07` / Spec 3).
    - `demo run` (fluxo guiado completo para a apresentação de 10 minutos sobre os dados públicos carregados).
- **Critérios de Aceite:**
  - Qualquer integrante da dupla consegue rodar um único comando `python main.py demo run` (ou comandos individuais) e visualizar tabelas/resultados claros no terminal.

#### `ISS-24` — Escrever Testes Unitários dos Checks no Backend (`tests/unit/`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev B | **Camada:** Tests | **Estimativa:** 3h | **Dia alvo:** Sex 04/12
- **Dependências:** `ISS-06`, `ISS-07`, `ISS-08`, `ISS-09`
- **Subtasks:**
  - [ ] Testar rejeição de valores inválidos nos Value Objects (`idade=-1`, `idade=131`, `sofa=25`, `discordancia=101`, `registro ANVISA != 13 chars`).
  - [ ] Testar checks de Formas Normais (alergia composta rejeitada na 1FN; inconsistência `itemid <-> item_name`).
  - [ ] Testar violações R1–R8: sessão com apenas 1 parecer falha, parecer sem diretriz falha (R7), prescrição de medicamento inativo falha, prescrição nefrotóxica com creatinina `> 1.5 mg/dL` aciona `alerta_renal=True`.
  - [ ] Testar cálculos de SOFA e `indice_discordancia` > 60% disparando alerta de viés.
- **Critérios de Aceite:**
  - 100% dos testes unitários passam em < 2 segundos sem precisar de PostgreSQL ativo.

#### `ISS-25` — Escrever Testes de Integração e Concorrência no PostgreSQL (`tests/integration/`)
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Tests | **Estimativa:** 3h30 | **Dia alvo:** Sáb 05/12
- **Dependências:** `ISS-13`, `ISS-14`, `ISS-19`, `ISS-21`
- **Subtasks:**
  - [ ] Testar pipeline ETL completo em banco de teste (incluindo registro malformado gravado em `etl_audit_log` e reexecução idempotente).
  - [ ] Testar **Spec 1 (`FN-05`)**: validar retorno ordenado e conferir uso do índice via `EXPLAIN`.
  - [ ] Testar **Spec 2 (`FN-06`)**: forçar falha/violação de R7 no 2º parecer e comprovar `ROLLBACK` total (nenhuma linha órfã em `sessao_junta` ou `parecer_agente`).
  - [ ] Testar **Spec 3 (`FN-07`)**: validar cenário com creatinina normal (`alerta_renal=False`) e alterada > 1.5 (`alerta_renal=True`) + comportamento com `FOR SHARE` concorrente.
  - [ ] Testar **`FN-04` concorrente**: disparar threads simultâneas inserindo exames no mesmo `hadm_id` e comprovar geração sequencial de `seq_exame` sem colisão (`FOR UPDATE`).
- **Critérios de Aceite:**
  - Todos os cenários de concorrência, rollback e atomicidade exigidos no `README.md` e na Entrega 2 passam em `pytest tests/integration`.

---

### ÉPICO 6 — Documentação, Máquina Limpa e Entrega Acadêmica (`epic:docs-entrega`)

#### `ISS-26` — Criar `LEIAME.md` para Máquina Limpa e Atualizar `README.md` / `.env.example`
- **Prioridade:** `P0-MVP` | **Responsável:** Dev A | **Camada:** Docs | **Estimativa:** 1h30 | **Dia alvo:** Sáb 05/12 – Dom 06/12
- **Dependências:** `ISS-23`, `ISS-25`
- **Subtasks:**
  - [ ] Escrever `LEIAME.md` (exigido pelo item 13a da Entrega 3) com passos exatos em máquina limpa: subir PostgreSQL (Docker/local), rodar `sql/01..05`, criar `.venv`, `pip install -r requirements.txt`, configurar `.env`, rodar `python main.py etl run`, rodar `python main.py demo run` e rodar `pytest`.
  - [ ] Atualizar `README.md` refletindo a nova estrutura `src/cdss_juntamed` (Clean Architecture) no lugar dos antigos arquivos citados em `etl/`.
- **Critérios de Aceite:**
  - O outro integrante da dupla consegue clonar/extrair o projeto do zero seguindo exclusivamente o `LEIAME.md` e executar a demo sem ajustes manuais.

#### `ISS-27` — Consolidar Seções da Etapa 4 no Relatório PDF (Itens 11, 12 e 13)
- **Prioridade:** `P0-MVP` | **Responsável:** Dupla | **Camada:** Docs | **Estimativa:** 3h | **Dia alvo:** Dom 06/12
- **Dependências:** `ISS-01`, `ISS-02`, `ISS-23`, `ISS-25`
- **Subtasks:**
  - [ ] **Item 11 (Escolha do banco)**: justificar PostgreSQL 17 (OLTP relacional) com base nas funções da Etapa 3 + preço da escolha (ex.: rigidez para séries temporais massivas/RAG vetorial e como contornam).
  - [ ] **Item 12 (Esquema lógico + 3FN + Índices)**: mapear cada relacionamento (1:N, N:M, fraca, multivalorado), **demonstrar 3FN**, explicar a migração dos checks para o backend Python e anexar DDL completo legível no PDF.
  - [ ] **Item 13(b) e 13(c)**: colar comandos/queries reais e prints/outputs do protótipo rodando sobre CNES + ANVISA + MIMIC-IV + tabela de **diferenças entre Etapas 1–3 e implementação final** com justificativas.
  - [ ] Incluir seção de **Histórico de alterações** das Etapas 1–3 conforme Item 02(c).
- **Critérios de Aceite:**
  - Relatório em PDF contém todas as seções na ordem exigida pelo Item 02(b) da `entrega_3.pdf`, sem anexos externos soltos.

#### `ISS-28` — Montar Slides (10 min), Ensaio da Demo e Empacotamento `.zip`
- **Prioridade:** `P1-MVP` | **Responsável:** Dupla | **Camada:** Docs / Entrega | **Estimativa:** 2h | **Dia alvo:** Dom 06/12
- **Dependências:** `ISS-26`, `ISS-27`
- **Subtasks:**
  - [ ] Montar slides em PDF cobrindo o roteiro do Item 03(a): dor real, fontes públicas, ERD + 1 decisão de modelagem, funções principais, escolha do banco, esquema lógico/checks e demonstração ao vivo.
  - [ ] Gerar `.zip` do código do protótipo **verificando que `data/raw/` NÃO contém as bases inteiras** (apenas `.gitkeep` ou amostra mínima se permitido, com script buscando da fonte).
  - [ ] Ensaiar apresentação em <= 10 minutos garantindo que **ambos integrantes** dominem decisões de modelagem, 3FN, checks no backend e transações.
- **Critérios de Aceite:**
  - Pacote completo validado: `Relatório.pdf`, `Slides.pdf` e `cdss-juntamed.zip` testado em máquina limpa.

---

### Bônus Pós-MVP (`P2-Bonus` — Executar APENAS se tudo acima estiver `Done`)

#### `ISS-29` `[P2-Bonus]` — Expor Endpoints Mínimos via FastAPI + Swagger
- **Contexto:** Só iniciar se o MVP CLI + testes + docs fecharem antes do fim de 06/12.
- **Subtasks:**
  - [ ] Criar `presentation/api/app.py` reutilizando os mesmos Use Cases (`FN-05`, `FN-06`, `FN-07`, `FN-10`) já prontos na camada `application` — provando o valor da Clean Architecture sem duplicar lógica.

---

## 8. Cronograma Sugerido (27/11 a 06/12/2026)

| Data | Dia | Status | Foco do Dev A (SQL / Infra / ETL) | Foco do Dev B (Clean Arch / Domain / CLI) | Marco do Dia |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **27/11** | Sex | Trabalho | `ISS-01`, `ISS-02` (DDL + 1FN/3FN + fronteira checks) | `ISS-05` (Esqueleto Clean Architecture + `pytest`) | Contrato SQL/Backend fechado e repo estruturado |
| **28/11** | Sáb | **OFF** | *Sem trabalho no projeto* | *Sem trabalho no projeto* | Descanso |
| **29/11** | Dom | **OFF** | *Sem trabalho no projeto* | *Sem trabalho no projeto* | Descanso |
| **30/11** | Seg | Trabalho | `ISS-03` (com Dev B), `ISS-04`, `ISS-11` (Postgres + UoW) | `ISS-03` (com Dev A), `ISS-06`, `ISS-07`, `ISS-08` (VOs, Entidades, Checks R1–R8) | Banco de pé + camada Domain com checks pronta *(checar envio SIGAA se aplicável)* |
| **01/12** | Ter | Trabalho | `ISS-15`, `ISS-16`, `ISS-17` (Extractors CNES, ANVISA, MIMIC-IV) | `ISS-09`, `ISS-10` (Serviços SOFA/Discordância/Renal + Portas) | Todos os extractors e serviços de domínio prontos |
| **02/12** | Qua | Trabalho | `ISS-12`, `ISS-13`, `ISS-14`, `ISS-18`, `ISS-19` (Repos + Staging/Merge) | Apoio na validação dos checks de ETL + início `ISS-20` | **ETL completo carregando dados reais no PostgreSQL** |
| **03/12** | Qui | Trabalho | Ajustes nos repositórios (`FOR UPDATE` / `FOR SHARE`) | `ISS-20`, `ISS-21`, `ISS-22` (Todos Use Cases FN-01..FN-10 + Motor Junta) | Todas as 10 funções funcionando via Python |
| **04/12** | Sex | Trabalho | Preparar massa/cenários de teste e `EXPLAIN ANALYZE` | `ISS-23`, `ISS-24` (CLI `main.py` + Demo + Testes Unitários) | CLI demonstrável + testes unitários dos checks verdes |
| **05/12** | Sáb | Trabalho | `ISS-25` (Testes integração/concorrência/rollback) + `ISS-26` (`LEIAME`) | Apoio em `ISS-25` + revisão de saídas reais para relatório | **Código MVP congelado e 100% testado** |
| **06/12** | Dom | **Entrega MVP** | `ISS-26`, `ISS-27`, `ISS-28` (Teste em máquina limpa + `.zip` + Relatório/Slides) | `ISS-27`, `ISS-28` (Evidências 13b/13c + Slides + Ensaio 10 min) | **MVP Python entregue, validado e pronto para apresentação** |

---

## 9. Definition of Done (Checklist Final do MVP — 06/12)

- [ ] Banco sobe do zero executando `sql/01` $\rightarrow$ `sql/05` sem erros.
- [ ] Esquema está demonstrado em **3FN** (incluindo decisão de `alergias` e `exame_clinico`).
- [ ] Regras de domínio, limites numéricos, formatos, normalização e R1–R8 são validados por **checks explícitos no backend Python** (`domain/`) antes da persistência.
- [ ] Pipeline ETL em duplo estágio baixa/lê **CNES + ANVISA + MIMIC-IV Demo**, audita rejeições em `etl_audit_log` e migra em transação única ACID.
- [ ] `FN-05` (Spec 1), `FN-06` (Spec 2 com rollback), `FN-07` (Spec 3 com `FOR SHARE` e alerta renal), `FN-04` (concorrência `FOR UPDATE`) e `FN-10` (SOFA) executam pela CLI sobre os dados públicos carregados.
- [ ] Testes unitários (checks no backend) e testes de integração/concorrência passam via `pytest`.
- [ ] `LEIAME.md` validado em ambiente limpo e `.zip` gerado sem base pública bruta embutida.
