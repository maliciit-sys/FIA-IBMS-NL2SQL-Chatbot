# 🔐 FIA-IBMS NL2SQL Chatbot

> A self-hosted, fully offline NL2SQL chatbot for FIA Pakistan's Integrated Border Management System (IBMS). Officers ask questions in plain English, the system generates SQL, executes it on Oracle, and returns narrated intelligence briefings — zero cloud dependencies, zero data leakage.

---

## 📋 Project Status

- [x] Architecture finalized (NL2SQL, not RAG)
- [x] Tech stack selected & validated
- [x] LLM models configured (`qwen2.5-coder:14b` + `qwen3-14b-fixed`)
- [x] Oracle 23ai Free in Docker with 20-table IBMS schema
- [x] Mock data loaded (~1.56M records across 20 tables)
- [x] System prompt with full schema + data dictionary
- [x] SQL generation pipeline (NL → SQL)
- [x] SQL safety validator (blocks DML, DDL, DCL, system access)
- [x] SQL executor with Oracle connectivity
- [x] Result narration as intelligence briefings
- [x] Smart query routing (LLM classifier: database vs general)
- [x] Token-by-token streaming output
- [x] Gradio 6.4 web UI with dark theme
- [ ] Formal evaluation & benchmarking (deferred — 5/5 test queries passing)
- [ ] Extract to standalone `app.py`
- [ ] Connect to real Oracle replica
- [ ] Role-based access control & audit logging

---

## 🏗️ Architecture

### Why NL2SQL Instead of RAG?

IBMS contains **structured, numeric travel records** — not free text. Traditional RAG (embed → vector search) fails because:

- Passport numbers have no semantic meaning
- Dates can't be filtered by cosine similarity
- Aggregations (`COUNT`, `SUM`, `GROUP BY`) are impossible with embeddings
- Exact matches (passport lookup) need SQL, not "similar" results

### Pipeline

```
┌─────────────────────────────────────────────────────┐
│                  FIA Officer Query                    │
│  "How many travelers were off-loaded at ISB in 2025?" │
└───────────────────────┬─────────────────────────────┘
                        │
                        ▼
              ┌──────────────────┐
              │  Query Classifier │ ← qwen3-14b-fixed
              │  DATABASE or      │   classifies intent
              │  GENERAL          │
              └────────┬─────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
┌──────────────────┐     ┌──────────────────┐
│  DATABASE PATH    │     │  GENERAL PATH     │
│                   │     │                   │
│ qwen2.5-coder     │     │ qwen3-14b-fixed   │
│ → Generate SQL    │     │ → Direct chat     │
│ → Validate        │     │ → Conversational  │
│ → Execute Oracle  │     │   response        │
│ → Narrate results │     │                   │
└────────┬──────────┘     └────────┬──────────┘
         │                         │
         └────────────┬────────────┘
                      ▼
            ┌──────────────────┐
            │  Streamed Response │
            │  Token-by-token   │
            │  + SQL details    │
            └──────────────────┘
```

### How It Works

```
Officer: "Which airlines have the highest off-loading rate?"

[1] Classifier → DATABASE
[2] qwen2.5-coder generates SQL:
        SELECT airline, COUNT(*) AS offload_count
        FROM offloading_records
        GROUP BY airline
        ORDER BY offload_count DESC

[3] Validator → PASS (SELECT only, references IBMS table)
[4] Oracle executes → 3 rows returned
[5] qwen3-14b-fixed narrates:

    "Based on the offloading records, Kuwait Airways and Serene Air
     are tied at the top with 665 offloading incidents each. Etihad
     Airways follows closely with 660 incidents..."
```

---

## 🔧 Tech Stack

| Component | Technology | Purpose |
|---|---|---|
| **SQL Generation** | `qwen2.5-coder:14b` via Ollama | Generates Oracle SQL from natural language |
| **Narration & Chat** | `qwen3-14b-fixed` via Ollama | Narrates results + handles general conversation |
| **Query Routing** | `qwen3-14b-fixed` via Ollama | Classifies queries as DATABASE or GENERAL |
| **Database** | Oracle 23ai Free (Docker) | IBMS data store — 20 tables, ~1.56M rows |
| **Connector** | `oracledb` + SQLAlchemy | Python ↔ Oracle connectivity |
| **Web UI** | Gradio 6.4 | Chat interface with streaming + collapsible SQL |
| **Pipeline** | Custom Python (no LangChain) | End-to-end NL2SQL orchestration |
| **Security** | SQL validator + read-only user | Blocks writes, injections, system access |

### Dual Model Strategy

Two models, loaded on-demand (only one in VRAM at a time — Ollama swaps automatically):

```
qwen2.5-coder:14b   → SQL generation (code specialist, temp=0.0)
qwen3-14b-fixed     → Classification, narration, general chat
                       (custom Modelfile with official Qwen3 params)
```

### qwen3-14b-fixed Configuration

Custom Ollama Modelfile built from `qwen3-14b:latest` with:

```
temperature: 0.7    (official Qwen3 non-thinking mode)
top_p: 0.8
top_k: 20
repeat_penalty: 1.5 (critical for quantized models — stops repetition)
```

This fixes known Ollama issues: system prompt injection, thinking leaks, and repetitive output loops.

---

## 💻 Hardware

| Component | Specification |
|---|---|
| **Laptop** | Lenovo Legion 5 Pro |
| **GPU** | NVIDIA RTX 5070 Ti (12GB VRAM) |
| **RAM** | 32 GB |
| **Storage** | 2 TB NVMe |
| **OS** | Ubuntu 22.04 |

---

## 🗄️ IBMS Database Schema

20 tables across 6 domains, with ~1.56M total records:

### Core Tables

| Table | Records | Description |
|---|---|---|
| `countries` | 195 | Reference: country codes, names, risk levels |
| `ports_of_entry` | 7 | Pakistani airports / BM stations |
| `visa_categories` | 15 | Visa types with max stay durations |
| `sponsors` | 10,000 | Visa sponsors |
| `travelers` | 100,000 | Passenger profiles (passport, CNIC, nationality) |
| `document_registry` | 200,000 | Passports, CNICs, travel documents |
| `visa_applications` | 150,000 | Visa records with status |
| `travel_records` | 500,000 | Flights: airline, route, date, status |
| `offloading_records` | 10,000 | Off-loaded passenger details |
| `watchlist` | 10,000 | Watchlist entries with alert levels |
| `ecl_entries` | 5,000 | Exit Control List records |
| `asylum_claims` | 8,000 | Asylum/refugee claims |
| `removal_orders` | 5,000 | Deportation/removal orders |
| `detention_records` | 3,000 | Detention facility records |
| `family_relationships` | 50,000 | Family links between travelers |
| `trafficking_cases` | 2,000 | Human trafficking investigations |
| `illegal_crossings` | 5,000 | Unauthorized border crossing incidents |
| `risk_profiles` | 100,000 | Automated risk scores for travelers |
| `suspect_networks` | 3,000 | Criminal network associations |
| `audit_log` | 400,000 | System activity audit trail |

### Airports / BM Stations

| Airport | City |
|---|---|
| Jinnah International | Karachi |
| Islamabad International | Islamabad |
| Allama Iqbal International | Lahore |
| Bacha Khan International | Peshawar |
| Quetta International | Quetta |
| Multan International | Multan |
| Sialkot International | Sialkot |

---

## 📊 Sample Queries (Tested & Working)

| # | Query | Result | Time |
|---|---|---|---|
| 1 | List all off-loaded passengers at Islamabad Airport in 2025 | ✅ 100+ rows | 16.8s |
| 2 | Which airlines have the highest off-loading rate? | ✅ 3 rows | 12.9s |
| 3 | How many watchlist alerts are currently active? | ✅ 6,378 alerts | 11.7s |
| 4 | Top 10 most frequent travelers this year | ✅ 10 rows | 19.0s |
| 5 | Compare off-loading rates across all airports | ✅ 7 rows | 19.6s |

**Success rate: 5/5 (100%) | Average total time: 16.0s**

---

## 🔒 Security

### SQL Safety Validator

Every generated SQL query passes through a security validator before execution:

| Check | What It Blocks |
|---|---|
| **DML** | `INSERT`, `UPDATE`, `DELETE`, `MERGE` |
| **DDL** | `CREATE`, `DROP`, `ALTER`, `TRUNCATE`, `RENAME` |
| **DCL** | `GRANT`, `REVOKE` |
| **System Access** | `DBMS_*`, `UTL_*`, `SYS.*`, `DBA_*`, `V$`, `EXECUTE IMMEDIATE` |
| **PL/SQL** | `BEGIN`, `DECLARE`, `EXEC` |
| **Multi-statement** | Semicolons, SQL comments (`--`, `/* */`) |
| **Table whitelist** | Must reference at least one known IBMS table |

### Additional Security

| Concern | Mitigation |
|---|---|
| Write operations | Read-only Oracle user (`SELECT` only) |
| Data exposure | Fully offline — no data leaves the machine |
| PII in development | All mock data uses synthetic names/passports |
| Audit trail | Query, SQL, result, and timing logged per request |

---

## 📂 Project Structure

```
IBMS_LLM/
├── Config/
│   ├── prompt_template.txt          # Full schema prompt for SQL generation
│   ├── narration_prompt.txt         # Narration instructions
│   └── nb03_test_results.json       # Pipeline test results
├── notebooks/
│   ├── 01_oracle_setup.ipynb        # Oracle Docker + 20 tables + 1.56M rows
│   ├── 02_system_prompt_sql.ipynb   # System prompt + SQL generation
│   ├── 03_sql_validation_narration.ipynb  # Validator + executor + narrator
│   └── 04_gradio_ui.ipynb           # Gradio web UI with routing + streaming
└── README.md
```

### Notebook Progression

| Notebook | Cells | What It Does |
|---|---|---|
| **01** | 38 (15 code, 23 md) | Oracle 23ai Docker setup, schema creation, data loading |
| **02** | ~30 | System prompt with full schema, SQL generation with qwen2.5-coder |
| **03** | 41 (18 code, 23 md) | SQL validation, execution, narration, end-to-end pipeline |
| **04** | 20 (10 code, 10 md) | Gradio UI, smart routing, streaming, dark theme |

---

## 📦 Dependencies

```
oracledb              # Oracle database connector
sqlalchemy            # Connection management + query execution
ollama                # Ollama Python client for LLM inference
gradio==6.4.0         # Web UI framework
pandas                # DataFrame handling for query results
```

---

## 🏃 Quick Start

### 1. Start Oracle

```bash
docker start oracle-ibms
# Wait ~60 seconds for Oracle to boot
```

### 2. Verify Oracle

```bash
docker exec -it oracle-ibms bash -c \
  "echo 'SELECT 1 FROM dual;' | sqlplus -s ibms_user/ibms_pass@//localhost:1521/FREEPDB1"
```

### 3. Launch Chatbot

```bash
cd ~/ml-projects/python-projects/IBMS_LLM
source ~/ml-projects/ml-env/bin/activate
jupyter notebook notebooks/04_gradio_ui.ipynb
# Run all cells → open http://localhost:7861
```

### 4. Stop

```python
# In the notebook:
app.close()
```

---

## ⚙️ Configuration Reference

| Setting | Value |
|---|---|
| Oracle connection | `oracle+oracledb://ibms_user:ibms_pass@localhost:1521/?service_name=FREEPDB1` |
| SQL model | `qwen2.5-coder:14b` |
| Chat/Narration model | `qwen3-14b-fixed` |
| Gradio port | `7861` |
| Gradio theme | `gr.themes.Soft(primary_hue="slate")` |

### Ollama Model Setup

```bash
# qwen2.5-coder is pulled directly:
ollama pull qwen2.5-coder:14b

# qwen3-14b-fixed is built from a custom Modelfile:
cat > /tmp/Modelfile-qwen3-fixed << 'EOF'
FROM qwen3-14b:latest

PARAMETER temperature 0.7
PARAMETER top_p 0.8
PARAMETER top_k 20
PARAMETER repeat_penalty 1.5
PARAMETER stop <|im_start|>
PARAMETER stop <|im_end|>

TEMPLATE """{{- range .Messages }}
{{- if eq .Role "system" }}<|im_start|>system
{{ .Content }}<|im_end|>
{{ end }}
{{- if eq .Role "user" }}<|im_start|>user
{{ .Content }}<|im_end|>
{{ end }}
{{- if eq .Role "assistant" }}<|im_start|>assistant
{{ .Content }}<|im_end|>
{{ end }}
{{- end }}<|im_start|>assistant
"""
EOF

ollama create qwen3-14b-fixed -f /tmp/Modelfile-qwen3-fixed
```

---

## 🐛 Known Issues & Workarounds

| Issue | Cause | Workaround |
|---|---|---|
| Oracle `DPY-6003: SID not registered` | Container just started, listener not ready | Wait 60-90 seconds after `docker start` |
| qwen3 thinking leaks into output | Ollama `think=False` unreliable for qwen3 | Custom Modelfile + `clean_qwen3_output()` regex |
| qwen3 ignores system prompt | Ollama template bug for Qwen models | Custom template in Modelfile fixes this |
| qwen3 repetitive loops ("Okay, done...") | Missing `repeat_penalty` | Set to 1.5 in Modelfile (official Qwen3 recommendation) |
| Gradio `bubble_full_width` error | Gradio 6.x removed this parameter | Removed from code |
| Gradio `theme`/`css` in Blocks() | Moved to `.launch()` in Gradio 6.x | Pass to `.launch()` instead |
| Port already in use | Previous app not closed | Run `app.close()` before re-launching |

---

## 🚀 Roadmap

### Completed (Prototype)
- ✅ Full NL2SQL pipeline (question → SQL → validate → execute → narrate)
- ✅ Smart routing (database queries vs general conversation)
- ✅ Streaming web UI with live progress indicators
- ✅ 100% success rate on test queries

### Next Steps
- [ ] UI improvements and polish
- [ ] Extract notebook to standalone `app.py`
- [ ] Formal evaluation with 50+ queries
- [ ] Audit logging (officer ID, timestamp, query, SQL, result)
- [ ] Role-based access control
- [ ] Connect to FIA's Oracle replica (change connection string only)

---

## 📝 License

Internal project for FIA Pakistan. Not for public distribution.
