import streamlit as st
import oracledb
from sqlalchemy import create_engine, text
import pandas as pd
import re
import time
import ollama
from pathlib import Path

# ══════════════════════════════════════════════════════════════
# PAGE CONFIG
# ══════════════════════════════════════════════════════════════
st.set_page_config(
    page_title="FIA IBMS Intelligence Assistant",
    page_icon="🔐",
    layout="centered",
    initial_sidebar_state="collapsed",
)

# ══════════════════════════════════════════════════════════════
# CUSTOM CSS — Light Professional Theme
# ══════════════════════════════════════════════════════════════
st.markdown("""
<style>
    /* Main container */
    .stApp {
        background-color: #f8f9fa;
    }
    
    /* Header */
    .main-header {
        background: linear-gradient(135deg, #1a365d 0%, #2c5282 100%);
        color: white;
        padding: 1.5rem 2rem;
        border-radius: 8px;
        margin-bottom: 1.5rem;
        text-align: center;
    }
    .main-header h1 {
        margin: 0;
        font-size: 1.8rem;
        font-weight: 700;
        letter-spacing: 0.5px;
    }
    .main-header p {
        margin: 0.3rem 0 0 0;
        font-size: 0.95rem;
        opacity: 0.85;
    }
    
    /* Chat messages */
    .user-msg {
        background-color: #e8f0fe;
        border-left: 4px solid #2c5282;
        padding: 0.8rem 1.2rem;
        border-radius: 0 8px 8px 0;
        margin: 0.8rem 0;
        font-size: 0.95rem;
    }
    .bot-msg {
        background-color: #ffffff;
        border: 1px solid #e2e8f0;
        padding: 1rem 1.2rem;
        border-radius: 8px;
        margin: 0.8rem 0;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }
    
    /* Pipeline status */
    .pipeline-step {
        font-size: 0.85rem;
        color: #4a5568;
        padding: 0.2rem 0;
    }
    
    /* Suggestion chips */
    .stButton > button {
        border-radius: 20px !important;
        font-size: 0.8rem !important;
        padding: 0.3rem 0.8rem !important;
        border: 1px solid #cbd5e0 !important;
        background-color: white !important;
        color: #2d3748 !important;
    }
    .stButton > button:hover {
        background-color: #e8f0fe !important;
        border-color: #2c5282 !important;
    }
    
    /* SQL details expander */
    .streamlit-expanderHeader {
        font-size: 0.85rem !important;
        color: #4a5568 !important;
    }
    
    /* Data table */
    .stDataFrame {
        border: 1px solid #e2e8f0;
        border-radius: 6px;
    }
    
    /* Input area */
    .stChatInput {
        border-top: 1px solid #e2e8f0;
    }
    
    /* Footer */
    .footer {
        text-align: center;
        font-size: 0.75rem;
        color: #a0aec0;
        padding: 1rem 0;
        border-top: 1px solid #e2e8f0;
        margin-top: 2rem;
    }
    
    /* Hide Streamlit branding */
    #MainMenu {visibility: hidden;}
    footer {visibility: hidden;}
    header {visibility: hidden;}
</style>
""", unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════
SQL_MODEL = "qwen2.5-coder:14b"
CHAT_MODEL = "qwen3-14b-fixed:latest"

QWEN3_OPTIONS = {
    "temperature": 0.7,
    "top_p": 0.8,
    "top_k": 20,
    "repeat_penalty": 1.5,
    "num_predict": 2048,
}

PROJECT_DIR = Path.home() / "ml-projects" / "python-projects" / "IBMS_LLM"
CONFIG_DIR = PROJECT_DIR / "Config"

EXAMPLE_QUERIES = [
    "How many travelers are in the system?",
    "Which airlines have the highest off-loading rate?",
    "How many watchlist alerts are currently active?",
    "Top 10 most frequent travelers this year",
    "Compare off-loading rates across all airports",
    "List off-loaded passengers at Islamabad Airport in 2025",
    "How many asylum claims were filed this year?",
    "What is IBMS?",
]

# ══════════════════════════════════════════════════════════════
# DATABASE CONNECTION (cached)
# ══════════════════════════════════════════════════════════════
@st.cache_resource
def get_engine():
    return create_engine(
        "oracle+oracledb://ibms_user:ibms_pass@localhost:1521/?service_name=FREEPDB1",
        pool_pre_ping=True,
        pool_size=3,
    )

@st.cache_data(ttl=3600)
def load_prompt_template():
    return (CONFIG_DIR / "prompt_template.txt").read_text()

# ══════════════════════════════════════════════════════════════
# PROMPTS
# ══════════════════════════════════════════════════════════════
SYSTEM_PROMPT_GENERAL = """You are an AI assistant for FIA (Federal Investigation Agency) Pakistan, specializing in the IBMS (Integrated Border Management System).

Guidelines:
- Match your response length to the question. Short questions get short answers. Detailed questions get detailed answers.
- For greetings (hello, hi, etc.), respond briefly and warmly. Introduce yourself in 1-2 sentences and ask how you can help.
- For follow-up questions about previous answers, provide relevant analysis or clarification.
- For FIA/IBMS concept questions, explain clearly with relevant context.
- If the officer needs specific data, suggest they ask a data question.
- Be professional but conversational. Do NOT pad responses with unnecessary information.
- Do NOT invent stories or hypothetical scenarios unless explicitly asked."""

NARRATION_PROMPT = """You are a senior FIA intelligence analyst. An officer asked a question and the system queried the IBMS database. Below are the results.

Write a professional intelligence briefing based ONLY on the data provided.

Rules:
- Lead with the key finding that directly answers the question.
- Include all important numbers exactly as shown (counts, percentages, dates).
- If results have rankings/tables, present and analyze them.
- If 0 rows returned, say "No records found" and suggest why.
- Do NOT invent data. Do NOT mention SQL or databases.
- Match response length to complexity: simple counts get 2-3 sentences, complex analyses get detailed paragraphs.
- End with a brief operational insight when the data warrants it.
- Do NOT pad your response to fill space. Be thorough but not verbose.

QUESTION: {question}

RESULTS:
{results}

Briefing:"""

CLASSIFIER_PROMPT = """Classify this message as DATABASE or GENERAL.

DATABASE = needs data from IBMS database (counts, lists, lookups, comparisons, statistics)
GENERAL = greeting, follow-up, explanation, opinion, or anything NOT needing a new database query

Reply with one word only: DATABASE or GENERAL
/no_think

Message: {message}"""

# ══════════════════════════════════════════════════════════════
# PIPELINE FUNCTIONS
# ══════════════════════════════════════════════════════════════
def clean_qwen3_output(text_input: str) -> str:
    text_input = re.sub(r'<think>.*?</think>\s*', '', text_input, flags=re.DOTALL)
    text_input = re.sub(r'<think>(?:(?!</think>).)*$', '', text_input, flags=re.DOTALL)
    text_input = re.sub(r'^(A:\s*\n?)+', '', text_input)
    text_input = re.sub(r'(Okay,.*?(done|ready|complete|wrap it up|finalize|all set)[.\s]*)+$', '', text_input, flags=re.DOTALL)
    return text_input.strip()


def classify_query(message: str, history: list) -> str:
    prompt = CLASSIFIER_PROMPT.replace("{message}", message)
    if history:
        recent = history[-4:]
        context = "\n".join(f"{m['role']}: {m['content'][:150]}" for m in recent)
        prompt += f"\n\nContext:\n{context}"
    try:
        response = ollama.chat(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            options={"temperature": 0.0, "num_predict": 10, "repeat_penalty": 1.5},
        )
        result = response["message"]["content"].strip().upper()
        return "DATABASE" if "DATABASE" in result else "GENERAL"
    except Exception:
        return "DATABASE"


def extract_sql(raw: str) -> str:
    raw = raw.strip()
    match = re.search(r'```(?:sql)?\s*\n?(.*?)\n?```', raw, re.DOTALL | re.IGNORECASE)
    if match:
        sql = match.group(1).strip()
    else:
        match = re.search(r'(SELECT\b.*)', raw, re.DOTALL | re.IGNORECASE)
        sql = match.group(1).strip() if match else raw
    if ';' in sql:
        sql = sql[:sql.index(';')].strip()
    return sql


def generate_sql(question: str) -> tuple:
    prompt_template = load_prompt_template()
    prompt = prompt_template.replace("{question}", question)
    t0 = time.time()
    response = ollama.chat(
        model=SQL_MODEL,
        messages=[{"role": "user", "content": prompt}],
        options={"temperature": 0.0, "num_predict": 1024},
    )
    latency = time.time() - t0
    raw = response["message"]["content"]
    return raw, extract_sql(raw), latency


IBMS_TABLES = {
    "countries", "ports_of_entry", "visa_categories", "sponsors",
    "travelers", "document_registry", "visa_applications", "travel_records",
    "asylum_claims", "removal_orders", "detention_records",
    "family_relationships", "watchlist", "ecl_entries",
    "trafficking_cases", "illegal_crossings", "offloading_records",
    "risk_profiles", "suspect_networks", "audit_log",
}

BLOCKED_KEYWORDS = [
    r"\bINSERT\b", r"\bUPDATE\b", r"\bDELETE\b", r"\bMERGE\b",
    r"\bCREATE\b", r"\bDROP\b", r"\bALTER\b", r"\bTRUNCATE\b", r"\bRENAME\b",
    r"\bGRANT\b", r"\bREVOKE\b",
    r"\bDBMS_", r"\bUTL_", r"\bSYS\.", r"\bDBA_",
    r"\bV\$", r"\bEXECUTE\s+IMMEDIATE\b",
    r"\bBEGIN\b", r"\bDECLARE\b", r"\bEXEC\b",
]


def validate_sql(sql: str) -> tuple:
    if not sql or not sql.strip():
        return False, "Empty SQL"
    sql_upper = sql.strip().upper()
    if not (sql_upper.startswith("SELECT") or sql_upper.startswith("WITH")):
        return False, f"Must start with SELECT/WITH"
    if ';' in sql:
        return False, "Multiple statements detected"
    for pattern in BLOCKED_KEYWORDS:
        match = re.search(pattern, sql, re.IGNORECASE)
        if match:
            return False, f"Blocked: {match.group()}"
    if '--' in sql or '/*' in sql:
        return False, "SQL comments not allowed"
    sql_lower = sql.lower()
    if not any(t in sql_lower for t in IBMS_TABLES):
        return False, "No known IBMS table referenced"
    return True, "OK"


def execute_sql(sql: str) -> tuple:
    is_valid, reason = validate_sql(sql)
    if not is_valid:
        return False, None, f"Validation failed: {reason}", 0.0
    try:
        engine = get_engine()
        t0 = time.time()
        with engine.connect() as conn:
            df = pd.read_sql(text(sql), conn)
        exec_time = time.time() - t0
        return True, df, f"{len(df)} rows", exec_time
    except Exception as e:
        return False, None, f"Error: {str(e)[:200]}", 0.0


def stream_narration(question: str, df: pd.DataFrame, placeholder):
    """Stream narration token-by-token into a Streamlit placeholder."""
    if df is None or df.empty:
        results_text = "(No results — 0 rows returned)"
    else:
        display_df = df.head(50)
        results_text = display_df.to_string(index=False)
        if len(df) > 50:
            results_text += f"\n\n... ({len(df)} total rows, showing first 50)"

    nar_prompt = NARRATION_PROMPT.replace("{question}", question).replace("{results}", results_text)
    nar_prompt += "\n/no_think"

    accumulated = ""
    t0 = time.time()

    stream = ollama.chat(
        model=CHAT_MODEL,
        messages=[{"role": "user", "content": nar_prompt}],
        options=QWEN3_OPTIONS,
        stream=True,
    )

    for chunk in stream:
        token = chunk.get("message", {}).get("content", "")
        if token:
            accumulated += token
            cleaned = clean_qwen3_output(accumulated)
            if cleaned:
                placeholder.markdown(cleaned)

    latency = time.time() - t0
    final = clean_qwen3_output(accumulated)
    placeholder.markdown(final)
    return final, latency


def stream_general_chat(message: str, history: list, placeholder):
    """Stream general chat response token-by-token."""
    combined = SYSTEM_PROMPT_GENERAL + "\n\n"
    if history:
        context = "\n".join(f"{m['role']}: {m['content'][:500]}" for m in history[-10:])
        combined += f"Previous conversation:\n{context}\n\n"
    combined += f"Officer's message: {message}\n\nRespond now. /no_think"

    messages = [{"role": "user", "content": combined}]

    accumulated = ""
    t0 = time.time()

    stream = ollama.chat(
        model=CHAT_MODEL,
        messages=messages,
        options=QWEN3_OPTIONS,
        stream=True,
    )

    for chunk in stream:
        token = chunk.get("message", {}).get("content", "")
        if token:
            accumulated += token
            cleaned = clean_qwen3_output(accumulated)
            if cleaned:
                placeholder.markdown(cleaned)

    latency = time.time() - t0
    final = clean_qwen3_output(accumulated)
    placeholder.markdown(final)
    return final, latency


# ══════════════════════════════════════════════════════════════
# HEADER
# ══════════════════════════════════════════════════════════════
st.markdown("""
    <div class="main-header">
        <h1>🔐 FIA IBMS Intelligence Assistant</h1>
        <p>Integrated Border Management System — Natural Language Query Interface</p>
    </div>
""", unsafe_allow_html=True)

# ══════════════════════════════════════════════════════════════
# SESSION STATE
# ══════════════════════════════════════════════════════════════
if "messages" not in st.session_state:
    st.session_state.messages = []
if "suggestion_used" not in st.session_state:
    st.session_state.suggestion_used = None

# ══════════════════════════════════════════════════════════════
# DISPLAY CHAT HISTORY
# ══════════════════════════════════════════════════════════════
for msg in st.session_state.messages:
    if msg["role"] == "user":
        with st.chat_message("user", avatar="👤"):
            st.markdown(msg["content"])
    else:
        with st.chat_message("assistant", avatar="🔐"):
            st.markdown(msg["content"])
            # Show data table if stored
            if "dataframe" in msg and msg["dataframe"] is not None:
                df_display = msg["dataframe"]
                st.dataframe(df_display, use_container_width=True, hide_index=True)
            # Show SQL details if stored
            if "details" in msg:
                with st.expander("📊 Query Details"):
                    st.markdown(msg["details"])

# ══════════════════════════════════════════════════════════════
# SUGGESTION CHIPS (shown only when no messages yet or after response)
# ══════════════════════════════════════════════════════════════
if len(st.session_state.messages) == 0:
    st.markdown("##### 💡 Try asking:")
    cols = st.columns(4)
    for i, query in enumerate(EXAMPLE_QUERIES):
        col = cols[i % 4]
        if col.button(query, key=f"suggest_{i}", use_container_width=True):
            st.session_state.suggestion_used = query
            st.rerun()

# ══════════════════════════════════════════════════════════════
# CHAT INPUT
# ══════════════════════════════════════════════════════════════
user_input = st.chat_input("Ask a question about IBMS data...")

# Handle suggestion click
if st.session_state.suggestion_used:
    user_input = st.session_state.suggestion_used
    st.session_state.suggestion_used = None

# ══════════════════════════════════════════════════════════════
# PROCESS USER INPUT
# ══════════════════════════════════════════════════════════════
if user_input:
    # Add user message
    st.session_state.messages.append({"role": "user", "content": user_input})
    with st.chat_message("user", avatar="👤"):
        st.markdown(user_input)

    # Assistant response
    with st.chat_message("assistant", avatar="🔐"):
        # Step 0: Classify
        status = st.status("Processing your question...", expanded=True)
        status.write("🔍 Analyzing your question...")

        history = [{"role": m["role"], "content": m["content"]} for m in st.session_state.messages[:-1]]
        query_type = classify_query(user_input, history)

        # ════════════════════════════
        # GENERAL PATH
        # ════════════════════════════
        if query_type == "GENERAL":
            status.write("💬 Generating response...")
            status.update(label="Responding...", state="running")

            response_placeholder = st.empty()
            final_text, latency = stream_general_chat(user_input, history, response_placeholder)

            status.update(label=f"✅ Done ({latency:.1f}s)", state="complete", expanded=False)

            details = f"**Mode:** General conversation\n\n**Model:** {CHAT_MODEL}\n\n**Time:** {latency:.1f}s"

            st.session_state.messages.append({
                "role": "assistant",
                "content": final_text,
                "details": details,
            })

            with st.expander("📊 Query Details"):
                st.markdown(details)

        # ════════════════════════════
        # DATABASE PATH
        # ════════════════════════════
        else:
            pipeline_start = time.time()

            # Step 1: Generate SQL
            status.write("⏳ Generating SQL...")
            status.update(label="Generating SQL...", state="running")
            try:
                raw, sql, gen_time = generate_sql(user_input)
            except Exception as e:
                status.update(label="❌ SQL generation failed", state="error")
                st.error(f"SQL generation failed: {str(e)[:200]}")
                st.stop()

            status.write(f"✅ SQL generated ({gen_time:.1f}s)")

            # Step 2: Validate
            status.write("⏳ Validating...")
            is_valid, val_msg = validate_sql(sql)
            if not is_valid:
                status.update(label="⚠️ Query blocked", state="error")
                st.warning(f"Query blocked for safety: {val_msg}\n\nPlease rephrase your question.")
                st.stop()

            status.write("✅ Validation passed")

            # Step 3: Execute
            status.write("⏳ Executing on Oracle...")
            status.update(label="Querying database...", state="running")
            exec_success, df, exec_msg, exec_time = execute_sql(sql)

            if not exec_success:
                status.update(label="⚠️ Execution failed", state="error")
                st.warning(f"Execution failed: {exec_msg}\n\nPlease rephrase.")
                st.stop()

            row_count = len(df) if df is not None else 0
            status.write(f"✅ Executed ({row_count} rows, {exec_time:.2f}s)")

            # Step 4: Narrate
            status.write("⏳ Narrating results...")
            status.update(label="Generating briefing...", state="running")

            response_placeholder = st.empty()
            narration, nar_time = stream_narration(user_input, df, response_placeholder)

            total_time = time.time() - pipeline_start
            status.update(label=f"✅ Complete ({total_time:.1f}s)", state="complete", expanded=False)

            # Show data table
            if df is not None and not df.empty:
                display_df = df.head(50)
                st.markdown("---")
                st.markdown(f"**📋 Results** ({row_count} rows{' — showing first 50' if row_count > 50 else ''})")
                st.dataframe(display_df, use_container_width=True, hide_index=True)

            # Show SQL details
            details = f"**Mode:** Database query (NL2SQL)\n\n"
            details += f"**Generated SQL:**\n```sql\n{sql}\n```\n\n"
            details += f"**Execution:** {row_count} rows in {exec_time:.2f}s\n\n"
            details += f"**Timings:** SQL Gen: {gen_time:.1f}s │ Exec: {exec_time:.2f}s │ Narration: {nar_time:.1f}s │ **Total: {total_time:.1f}s**"

            with st.expander("📊 Query Details"):
                st.markdown(details)

            # Store in session
            st.session_state.messages.append({
                "role": "assistant",
                "content": narration,
                "dataframe": df.head(50) if df is not None and not df.empty else None,
                "details": details,
            })

# ══════════════════════════════════════════════════════════════
# FOOTER
# ══════════════════════════════════════════════════════════════
st.markdown("""
    <div class="footer">
        FIA IBMS Intelligence Assistant • Prototype • Powered by Qwen2.5-Coder + Qwen3 via Ollama
    </div>
""", unsafe_allow_html=True)
