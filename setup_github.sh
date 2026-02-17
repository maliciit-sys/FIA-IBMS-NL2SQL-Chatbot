#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# FIA IBMS NL2SQL Chatbot — GitHub Repository Setup
# Creates repo with 30+ structured commits
# ═══════════════════════════════════════════════════════════════
#
# PREREQUISITES:
#   1. GitHub CLI or SSH key configured
#   2. Run from: ~/ml-projects/python-projects/IBMS_LLM/
#   3. All project files already in place
#
# USAGE:
#   chmod +x setup_github.sh
#   ./setup_github.sh
# ═══════════════════════════════════════════════════════════════

set -e  # Exit on error

PROJECT_DIR=~/ml-projects/python-projects/IBMS_LLM
REPO_NAME="FIA-IBMS-NL2SQL-Chatbot"
GITHUB_USER="maliciit-sys"

cd "$PROJECT_DIR"

echo "═══════════════════════════════════════════"
echo "  Setting up GitHub repo: $REPO_NAME"
echo "  Directory: $PROJECT_DIR"
echo "═══════════════════════════════════════════"

# ── Step 0: Create GitHub repo ──
echo ""
echo "[Step 0] Creating GitHub repository..."
gh repo create "$REPO_NAME" --public --description "Self-hosted NL2SQL chatbot for FIA Pakistan's IBMS — offline, Oracle-powered, LLM-driven intelligence queries" || echo "Repo may already exist, continuing..."

# ── Step 1: Initialize git ──
echo ""
echo "[Step 1] Initializing git..."
git init
git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git" 2>/dev/null || git remote set-url origin "https://github.com/$GITHUB_USER/$REPO_NAME.git"
git branch -M main

# ═══════════════════════════════════════════
# COMMIT 1: Project initialization
# ═══════════════════════════════════════════
echo "[Commit 1] Project initialization..."
git add .gitignore
git commit -m "chore: initialize project with .gitignore"

# ═══════════════════════════════════════════
# COMMIT 2: README
# ═══════════════════════════════════════════
echo "[Commit 2] Add README..."
git add README.md
git commit -m "docs: add project README with architecture overview"

# ═══════════════════════════════════════════
# COMMIT 3: Requirements
# ═══════════════════════════════════════════
echo "[Commit 3] Add requirements..."
git add requirements.txt
git commit -m "chore: add Python dependencies (requirements.txt)"

# ═══════════════════════════════════════════
# COMMIT 4: Config directory
# ═══════════════════════════════════════════
echo "[Commit 4] Add config directory..."
mkdir -p Config
git add Config/
git commit -m "feat: add Config directory with prompt templates" || echo "  (skipped — no changes)"

# ═══════════════════════════════════════════
# COMMIT 5: SQL prompt template
# ═══════════════════════════════════════════
echo "[Commit 5] SQL prompt template..."
if [ -f Config/prompt_template.txt ]; then
    git add Config/prompt_template.txt
    git commit -m "feat: add SQL generation prompt template with full IBMS schema"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 6: Test results
# ═══════════════════════════════════════════
echo "[Commit 6] Test results..."
if [ -f Config/nb03_test_results.json ]; then
    git add Config/nb03_test_results.json
    git commit -m "test: add pipeline test results (5/5 queries passing)"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 7: Notebook 01 — Oracle setup
# ═══════════════════════════════════════════
echo "[Commit 7] Notebook 01..."
mkdir -p notebooks
if [ -f notebooks/01_oracle_setup.ipynb ]; then
    git add notebooks/01_oracle_setup.ipynb
    git commit -m "feat: add notebook 01 — Oracle Docker setup and schema creation"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 8: Notebook 02 — System prompt
# ═══════════════════════════════════════════
echo "[Commit 8] Notebook 02..."
if [ -f notebooks/02_system_prompt_sql.ipynb ]; then
    git add notebooks/02_system_prompt_sql.ipynb
    git commit -m "feat: add notebook 02 — system prompt and SQL generation pipeline"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 9: Notebook 03 — Validation & narration
# ═══════════════════════════════════════════
echo "[Commit 9] Notebook 03..."
if [ -f notebooks/03_sql_validation_narration.ipynb ]; then
    git add notebooks/03_sql_validation_narration.ipynb
    git commit -m "feat: add notebook 03 — SQL validation, execution, and narration"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 10: Notebook 04 — Gradio UI
# ═══════════════════════════════════════════
echo "[Commit 10] Notebook 04..."
if [ -f notebooks/04_gradio_ui.ipynb ]; then
    git add notebooks/04_gradio_ui.ipynb
    git commit -m "feat: add notebook 04 — Gradio UI with smart routing and streaming"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 11: Notebook 05 — Streamlit UI
# ═══════════════════════════════════════════
echo "[Commit 11] Notebook 05..."
if [ -f notebooks/05_streamlit_ui.ipynb ]; then
    git add notebooks/05_streamlit_ui.ipynb
    git commit -m "feat: add notebook 05 — Streamlit UI with professional theme"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMIT 12: Streamlit app.py
# ═══════════════════════════════════════════
echo "[Commit 12] Streamlit app.py..."
if [ -f app.py ]; then
    git add app.py
    git commit -m "feat: add standalone Streamlit app with data tables and suggestion chips"
else
    echo "  (skipped — file not found)"
fi

# ═══════════════════════════════════════════
# COMMITS 13-15: Workflow diagrams
# ═══════════════════════════════════════════
echo "[Commit 13] Diagram generation script..."
mkdir -p workflow
if [ -f workflow/generate_diagrams.py ]; then
    git add workflow/generate_diagrams.py
    git commit -m "feat: add matplotlib diagram generation script"
else
    echo "  (skipped — file not found)"
fi

echo "[Commit 14] Architecture diagram..."
if [ -f workflow/diagram_2_architecture.png ]; then
    git add workflow/diagram_2_architecture.png
    git commit -m "docs: add system architecture diagram"
else
    echo "  (skipped — file not found)"
fi

echo "[Commit 15] Pipeline and workflow diagrams..."
if [ -f workflow/diagram_1_project_workflow.png ] && [ -f workflow/diagram_3_data_pipeline.png ]; then
    git add workflow/diagram_1_project_workflow.png workflow/diagram_3_data_pipeline.png
    git commit -m "docs: add project workflow and data pipeline diagrams"
else
    echo "  (skipped — files not found)"
fi

# ═══════════════════════════════════════════
# COMMITS 16-25: Data files (individual commits for each table/batch)
# ═══════════════════════════════════════════
echo ""
echo "[Commits 16-25] Adding data files..."
mkdir -p data/mock

# Check if data directory has files
if [ -d data ] && [ "$(find data -type f 2>/dev/null | head -1)" ]; then
    
    # Group 1: Reference tables
    FOUND=0
    for f in data/mock/countries* data/mock/ports* data/mock/visa_cat*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add reference tables (countries, ports, visa categories)" || echo "  (skipped group 1)"

    # Group 2: Travelers and documents
    FOUND=0
    for f in data/mock/travelers* data/mock/document*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add travelers and document registry data" || echo "  (skipped group 2)"

    # Group 3: Travel records
    FOUND=0
    for f in data/mock/travel_rec*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add travel records (500K flight records)" || echo "  (skipped group 3)"

    # Group 4: Visa and sponsors
    FOUND=0
    for f in data/mock/visa_app* data/mock/sponsor*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add visa applications and sponsors data" || echo "  (skipped group 4)"

    # Group 5: Security tables
    FOUND=0
    for f in data/mock/watchlist* data/mock/ecl* data/mock/offload*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add security tables (watchlist, ECL, offloading)" || echo "  (skipped group 5)"

    # Group 6: Investigation tables
    FOUND=0
    for f in data/mock/trafficking* data/mock/illegal* data/mock/suspect*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add investigation tables (trafficking, crossings, networks)" || echo "  (skipped group 6)"

    # Group 7: Immigration tables
    FOUND=0
    for f in data/mock/asylum* data/mock/removal* data/mock/detention*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add immigration tables (asylum, removal, detention)" || echo "  (skipped group 7)"

    # Group 8: Risk and family
    FOUND=0
    for f in data/mock/risk* data/mock/family*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add risk profiles and family relationships" || echo "  (skipped group 8)"

    # Group 9: Audit log
    FOUND=0
    for f in data/mock/audit*; do
        [ -f "$f" ] && git add "$f" && FOUND=1
    done
    [ $FOUND -eq 1 ] && git commit -m "data: add audit log (400K system activity records)" || echo "  (skipped group 9)"

    # Group 10: Any remaining data files
    REMAINING=$(git ls-files --others data/ 2>/dev/null | head -1)
    if [ -n "$REMAINING" ]; then
        git add data/
        git commit -m "data: add remaining mock data files"
    fi

else
    echo "  No data files found in data/ — skipping data commits"
    echo "  You can add data files later with individual commits"
fi

# ═══════════════════════════════════════════
# COMMIT 26: SQL security validator
# ═══════════════════════════════════════════
echo "[Commit 26] Document SQL validator..."
cat > SECURITY.md << 'SECEOF'
# Security: SQL Safety Validator

Every SQL query generated by the LLM passes through a security validator before execution.

## Blocked Operations

| Category | Blocked Keywords |
|---|---|
| DML | `INSERT`, `UPDATE`, `DELETE`, `MERGE` |
| DDL | `CREATE`, `DROP`, `ALTER`, `TRUNCATE`, `RENAME` |
| DCL | `GRANT`, `REVOKE` |
| System | `DBMS_*`, `UTL_*`, `SYS.*`, `DBA_*`, `V$`, `EXECUTE IMMEDIATE` |
| PL/SQL | `BEGIN`, `DECLARE`, `EXEC` |

## Additional Checks

- Must start with `SELECT` or `WITH`
- No semicolons (single statement only)
- No SQL comments (`--`, `/* */`)
- Must reference at least one known IBMS table
- Oracle user has read-only privileges (`SELECT` only)

## Data Protection

- Fully offline — no data leaves the machine
- All development data is synthetic (mock)
- Production deployment requires FIA's internal network only
SECEOF
git add SECURITY.md
git commit -m "docs: add security documentation for SQL validator"

# ═══════════════════════════════════════════
# COMMIT 27: Ollama model configuration
# ═══════════════════════════════════════════
echo "[Commit 27] Ollama model config..."
cat > Modelfile-qwen3-fixed << 'MODELEOF'
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
MODELEOF
git add Modelfile-qwen3-fixed
git commit -m "feat: add Ollama Modelfile for qwen3-14b-fixed"

# ═══════════════════════════════════════════
# COMMIT 28: Docker setup script
# ═══════════════════════════════════════════
echo "[Commit 28] Docker setup..."
mkdir -p scripts
cat > scripts/start_oracle.sh << 'DOCKEREOF'
#!/bin/bash
# Start Oracle Docker container
echo "Starting Oracle IBMS container..."
docker start oracle-ibms

echo "Waiting for Oracle to boot (60 seconds)..."
sleep 60

echo "Verifying connection..."
docker exec -it oracle-ibms bash -c \
  "echo 'SELECT 1 FROM dual;' | sqlplus -s ibms_user/ibms_pass@//localhost:1521/FREEPDB1"

echo "Oracle is ready!"
DOCKEREOF
chmod +x scripts/start_oracle.sh
git add scripts/start_oracle.sh
git commit -m "feat: add Oracle Docker startup script"

# ═══════════════════════════════════════════
# COMMIT 29: Model setup script
# ═══════════════════════════════════════════
echo "[Commit 29] Model setup script..."
cat > scripts/setup_models.sh << 'MODELSEOF'
#!/bin/bash
# Setup Ollama models for FIA IBMS chatbot
echo "Pulling qwen2.5-coder:14b..."
ollama pull qwen2.5-coder:14b

echo "Pulling qwen3-14b..."
ollama pull qwen3-14b:latest

echo "Creating qwen3-14b-fixed with custom Modelfile..."
ollama create qwen3-14b-fixed -f Modelfile-qwen3-fixed

echo "Verifying models..."
ollama list | grep -E "qwen2.5-coder|qwen3-14b"

echo "Done!"
MODELSEOF
chmod +x scripts/setup_models.sh
git add scripts/setup_models.sh
git commit -m "feat: add Ollama model setup script"

# ═══════════════════════════════════════════
# COMMIT 30: Final — catch any remaining files
# ═══════════════════════════════════════════
echo "[Commit 30] Final commit — any remaining files..."
git add -A
git diff --cached --quiet || git commit -m "chore: add remaining project files"

# ═══════════════════════════════════════════
# PUSH
# ═══════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════"
echo "  All commits ready! Pushing to GitHub..."
echo "═══════════════════════════════════════════"

git push -u origin main

echo ""
echo "═══════════════════════════════════════════"
echo "  DONE!"
echo "  Repo: https://github.com/$GITHUB_USER/$REPO_NAME"
echo "═══════════════════════════════════════════"

# Show commit count
COMMIT_COUNT=$(git rev-list --count HEAD)
echo "  Total commits: $COMMIT_COUNT"
echo ""
git log --oneline
