-- ============================================================
-- Immigration Database Schema (Oracle 19c)
-- Converted from PostgreSQL | 20 Tables
-- Generated for: Jan 2025 - Dec 2025
-- Target: gvenzl/oracle-free:23-slim (FREEPDB1)
-- Schema Owner: ibms_user
-- ============================================================

-- Drop tables in reverse dependency order
BEGIN EXECUTE IMMEDIATE 'DROP TABLE audit_log CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE suspect_networks CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE risk_profiles CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE offloading_records CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE illegal_crossings CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE trafficking_cases CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ecl_entries CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE watchlist CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE family_relationships CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE detention_records CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE removal_orders CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE asylum_claims CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE travel_records CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE visa_applications CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE document_registry CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE sponsors CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE travelers CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE visa_categories CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ports_of_entry CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE countries CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ============================================================
-- 1. COUNTRIES
-- ============================================================
CREATE TABLE countries (
    country_id          NUMBER(10) PRIMARY KEY,
    country_name        VARCHAR2(100) NOT NULL,
    iso3_code           VARCHAR2(3) NOT NULL,
    region              VARCHAR2(50) NOT NULL,
    sub_region          VARCHAR2(50),
    income_group        VARCHAR2(30),
    is_conflict_zone    NUMBER(1) DEFAULT 0,
    CONSTRAINT uq_countries_iso3 UNIQUE (iso3_code)
);

-- ============================================================
-- 2. PORTS OF ENTRY
-- ============================================================
CREATE TABLE ports_of_entry (
    port_id             NUMBER(10) PRIMARY KEY,
    port_name           VARCHAR2(150) NOT NULL,
    port_type           VARCHAR2(20) NOT NULL,
    city                VARCHAR2(100),
    country_id          NUMBER(10) NOT NULL,
    iata_code           VARCHAR2(10),
    latitude            NUMBER(9,6),
    longitude           NUMBER(9,6),
    is_active           NUMBER(1) DEFAULT 1,
    CONSTRAINT chk_port_type CHECK (port_type IN ('Airport','Land Border','Seaport')),
    CONSTRAINT fk_port_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 3. VISA CATEGORIES
-- ============================================================
CREATE TABLE visa_categories (
    visa_code           VARCHAR2(5) PRIMARY KEY,
    visa_name           VARCHAR2(100) NOT NULL,
    visa_class          VARCHAR2(20) NOT NULL,
    max_duration_days   NUMBER(10),
    allows_work         NUMBER(1) DEFAULT 0,
    allows_study        NUMBER(1) DEFAULT 0,
    requires_sponsor    NUMBER(1) DEFAULT 0,
    description         VARCHAR2(255),
    CONSTRAINT chk_visa_class CHECK (visa_class IN ('Immigrant','Non-Immigrant','Refugee','Transit','Diplomatic'))
);

-- ============================================================
-- 4. TRAVELERS
-- ============================================================
CREATE TABLE travelers (
    traveler_id         NUMBER(10) PRIMARY KEY,
    passport_number     VARCHAR2(20) NOT NULL,
    first_name          VARCHAR2(100) NOT NULL,
    last_name           VARCHAR2(100) NOT NULL,
    date_of_birth       DATE NOT NULL,
    gender              CHAR(1),
    nationality_id      NUMBER(10) NOT NULL,
    birth_country_id    NUMBER(10) NOT NULL,
    occupation          VARCHAR2(100),
    education_level     VARCHAR2(20),
    marital_status      VARCHAR2(10),
    phone_number        VARCHAR2(20),
    email               VARCHAR2(150),
    created_at          TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT uq_travelers_passport UNIQUE (passport_number),
    CONSTRAINT chk_gender CHECK (gender IN ('M','F','X')),
    CONSTRAINT chk_education CHECK (education_level IN ('None','Primary','Secondary','Bachelors','Masters','Doctorate','Professional')),
    CONSTRAINT chk_marital CHECK (marital_status IN ('Single','Married','Divorced','Widowed')),
    CONSTRAINT fk_traveler_nationality FOREIGN KEY (nationality_id) REFERENCES countries(country_id),
    CONSTRAINT fk_traveler_birth_country FOREIGN KEY (birth_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 5. SPONSORS
-- ============================================================
CREATE TABLE sponsors (
    sponsor_id          NUMBER(10) PRIMARY KEY,
    sponsor_type        VARCHAR2(20) NOT NULL,
    sponsor_name        VARCHAR2(200) NOT NULL,
    country_id          NUMBER(10) NOT NULL,
    city                VARCHAR2(100),
    industry            VARCHAR2(100),
    registration_number VARCHAR2(50),
    is_verified         NUMBER(1) DEFAULT 0,
    CONSTRAINT chk_sponsor_type CHECK (sponsor_type IN ('Employer','Family','Institution','Government','Self')),
    CONSTRAINT fk_sponsor_country FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 6. DOCUMENT REGISTRY
-- ============================================================
CREATE TABLE document_registry (
    document_id         NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    document_type       VARCHAR2(30) NOT NULL,
    document_number     VARCHAR2(50) NOT NULL,
    issuing_country_id  NUMBER(10) NOT NULL,
    issue_date          DATE NOT NULL,
    expiry_date         DATE,
    status              VARCHAR2(20) NOT NULL,
    CONSTRAINT chk_doc_type CHECK (document_type IN ('Passport','CNIC','NICOP','Travel Document','Refugee Card','Laissez-Passer')),
    CONSTRAINT chk_doc_status CHECK (status IN ('Valid','Expired','Cancelled','Reported Stolen','Suspended','Under Review')),
    CONSTRAINT fk_doc_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_doc_country FOREIGN KEY (issuing_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 7. VISA APPLICATIONS
-- ============================================================
CREATE TABLE visa_applications (
    application_id      NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    visa_code           VARCHAR2(5) NOT NULL,
    sponsor_id          NUMBER(10),
    application_date    DATE NOT NULL,
    decision_date       DATE,
    status              VARCHAR2(15) NOT NULL,
    denial_reason       VARCHAR2(255),
    processing_office   VARCHAR2(100),
    fee_amount          NUMBER(10,2),
    fee_currency        VARCHAR2(3) DEFAULT 'PKR',
    CONSTRAINT chk_visa_status CHECK (status IN ('Pending','Approved','Denied','Revoked','Expired','Withdrawn')),
    CONSTRAINT fk_visa_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_visa_code FOREIGN KEY (visa_code) REFERENCES visa_categories(visa_code),
    CONSTRAINT fk_visa_sponsor FOREIGN KEY (sponsor_id) REFERENCES sponsors(sponsor_id)
);

-- ============================================================
-- 8. TRAVEL RECORDS
-- ============================================================
CREATE TABLE travel_records (
    record_id           NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    application_id      NUMBER(10),
    entry_port_id       NUMBER(10),
    exit_port_id        NUMBER(10),
    entry_date          TIMESTAMP,
    exit_date           TIMESTAMP,
    travel_direction    VARCHAR2(10) NOT NULL,
    travel_purpose      VARCHAR2(30),
    flight_number       VARCHAR2(15),
    carrier             VARCHAR2(100),
    declared_stay_days  NUMBER(10),
    actual_stay_days    NUMBER(10),
    overstay_flag       NUMBER(1) DEFAULT 0,
    flagged_suspicious  NUMBER(1) DEFAULT 0,
    referral_to_investigation NUMBER(1) DEFAULT 0,
    CONSTRAINT chk_travel_dir CHECK (travel_direction IN ('Inbound','Outbound','Transit')),
    CONSTRAINT fk_travel_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_travel_app FOREIGN KEY (application_id) REFERENCES visa_applications(application_id),
    CONSTRAINT fk_travel_entry_port FOREIGN KEY (entry_port_id) REFERENCES ports_of_entry(port_id),
    CONSTRAINT fk_travel_exit_port FOREIGN KEY (exit_port_id) REFERENCES ports_of_entry(port_id)
);

-- ============================================================
-- 9. ASYLUM CLAIMS
-- ============================================================
CREATE TABLE asylum_claims (
    claim_id            NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    filing_date         DATE NOT NULL,
    claim_basis         VARCHAR2(20) NOT NULL,
    origin_country_id   NUMBER(10) NOT NULL,
    status              VARCHAR2(25) NOT NULL,
    decision_date       DATE,
    assigned_officer    VARCHAR2(100),
    dependents_count    NUMBER(10) DEFAULT 0,
    CONSTRAINT chk_asylum_basis CHECK (claim_basis IN ('Persecution','War','Political','Religious','Ethnic','Gender-Based','Other')),
    CONSTRAINT chk_asylum_status CHECK (status IN ('Filed','Under Review','Interview Scheduled','Approved','Denied','Appealed','Withdrawn')),
    CONSTRAINT fk_asylum_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_asylum_country FOREIGN KEY (origin_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 10. REMOVAL ORDERS
-- ============================================================
CREATE TABLE removal_orders (
    order_id            NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    order_date          DATE NOT NULL,
    reason              VARCHAR2(30) NOT NULL,
    destination_country_id NUMBER(10) NOT NULL,
    execution_date      DATE,
    status              VARCHAR2(15) NOT NULL,
    voluntary_departure NUMBER(1) DEFAULT 0,
    CONSTRAINT chk_removal_reason CHECK (reason IN ('Visa Overstay','Criminal Offense','Security Threat','Fraudulent Documents','Unauthorized Work','Failed Asylum','Trafficking Involvement','Other')),
    CONSTRAINT chk_removal_status CHECK (status IN ('Issued','Appealed','Executed','Stayed','Cancelled')),
    CONSTRAINT fk_removal_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_removal_country FOREIGN KEY (destination_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 11. DETENTION RECORDS
-- ============================================================
CREATE TABLE detention_records (
    detention_id        NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    facility_name       VARCHAR2(150) NOT NULL,
    facility_country_id NUMBER(10) NOT NULL,
    intake_date         DATE NOT NULL,
    release_date        DATE,
    reason              VARCHAR2(255),
    removal_order_id    NUMBER(10),
    status              VARCHAR2(15),
    CONSTRAINT chk_detention_status CHECK (status IN ('Active','Released','Transferred','Deported')),
    CONSTRAINT fk_detention_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_detention_country FOREIGN KEY (facility_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_detention_order FOREIGN KEY (removal_order_id) REFERENCES removal_orders(order_id)
);

-- ============================================================
-- 12. FAMILY RELATIONSHIPS
-- ============================================================
CREATE TABLE family_relationships (
    relationship_id     NUMBER(10) PRIMARY KEY,
    traveler_id_1       NUMBER(10) NOT NULL,
    traveler_id_2       NUMBER(10) NOT NULL,
    relationship_type   VARCHAR2(15) NOT NULL,
    verified            NUMBER(1) DEFAULT 0,
    CONSTRAINT chk_rel_type CHECK (relationship_type IN ('Spouse','Parent','Child','Sibling','Grandparent','Grandchild','Other')),
    CONSTRAINT fk_rel_traveler1 FOREIGN KEY (traveler_id_1) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_rel_traveler2 FOREIGN KEY (traveler_id_2) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 13. WATCHLIST
-- ============================================================
CREATE TABLE watchlist (
    alert_id            NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10),
    passport_number     VARCHAR2(20),
    alert_type          VARCHAR2(25) NOT NULL,
    severity            VARCHAR2(10),
    issued_by           VARCHAR2(100),
    issued_date         DATE NOT NULL,
    expiry_date         DATE,
    is_active           NUMBER(1) DEFAULT 1,
    notes               VARCHAR2(500),
    CONSTRAINT chk_alert_type CHECK (alert_type IN ('Security','Criminal','Immigration Violation','Interpol','Lost Document','Fraud','Trafficking','Smuggling','ECL')),
    CONSTRAINT chk_severity CHECK (severity IN ('Low','Medium','High','Critical')),
    CONSTRAINT fk_watchlist_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 14. ECL ENTRIES (Exit Control List)
-- ============================================================
CREATE TABLE ecl_entries (
    ecl_id              NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    reason              VARCHAR2(30) NOT NULL,
    issuing_authority   VARCHAR2(100) NOT NULL,
    issued_date         DATE NOT NULL,
    expiry_date         DATE,
    status              VARCHAR2(10) NOT NULL,
    case_reference      VARCHAR2(50),
    CONSTRAINT chk_ecl_reason CHECK (reason IN ('Financial Crime','Court Order','National Security','Terrorism','Tax Evasion','Money Laundering','Pending Investigation','Other')),
    CONSTRAINT chk_ecl_status CHECK (status IN ('Active','Lifted','Expired','Under Review')),
    CONSTRAINT fk_ecl_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 15. TRAFFICKING CASES
-- ============================================================
CREATE TABLE trafficking_cases (
    case_id             NUMBER(10) PRIMARY KEY,
    case_type           VARCHAR2(20) NOT NULL,
    victim_traveler_id  NUMBER(10),
    suspect_traveler_id NUMBER(10),
    origin_country_id   NUMBER(10) NOT NULL,
    transit_country_id  NUMBER(10),
    destination_country_id NUMBER(10) NOT NULL,
    reported_date       DATE NOT NULL,
    status              VARCHAR2(25) NOT NULL,
    victim_age_at_time  NUMBER(10),
    victim_gender       CHAR(1),
    CONSTRAINT chk_trafficking_type CHECK (case_type IN ('Labor','Sexual','Organ','Forced Marriage','Child','Domestic Servitude','Debt Bondage','Other')),
    CONSTRAINT chk_trafficking_status CHECK (status IN ('Open','Under Investigation','Prosecuted','Convicted','Acquitted','Closed')),
    CONSTRAINT fk_trafficking_victim FOREIGN KEY (victim_traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_trafficking_suspect FOREIGN KEY (suspect_traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_trafficking_origin FOREIGN KEY (origin_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_trafficking_transit FOREIGN KEY (transit_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_trafficking_dest FOREIGN KEY (destination_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 16. ILLEGAL CROSSINGS
-- ============================================================
CREATE TABLE illegal_crossings (
    crossing_id         NUMBER(10) PRIMARY KEY,
    detected_date       TIMESTAMP NOT NULL,
    location_name       VARCHAR2(150),
    nearest_port_id     NUMBER(10),
    latitude            NUMBER(9,6),
    longitude           NUMBER(9,6),
    direction           VARCHAR2(10),
    detection_method    VARCHAR2(20) NOT NULL,
    group_size          NUMBER(10) DEFAULT 1,
    smuggler_linked     NUMBER(1) DEFAULT 0,
    apprehended_count   NUMBER(10) DEFAULT 0,
    outcome             VARCHAR2(20) NOT NULL,
    lead_traveler_id    NUMBER(10),
    nationality_id      NUMBER(10),
    CONSTRAINT chk_crossing_dir CHECK (direction IN ('Inbound','Outbound')),
    CONSTRAINT chk_detection CHECK (detection_method IN ('Patrol','Sensor','Tip-Off','Drone','CCTV','Informant','Checkpoint','Other')),
    CONSTRAINT chk_outcome CHECK (outcome IN ('Apprehended','Escaped','Turned Back','Partial Capture')),
    CONSTRAINT fk_crossing_port FOREIGN KEY (nearest_port_id) REFERENCES ports_of_entry(port_id),
    CONSTRAINT fk_crossing_traveler FOREIGN KEY (lead_traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_crossing_nationality FOREIGN KEY (nationality_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 17. OFFLOADING RECORDS
-- ============================================================
CREATE TABLE offloading_records (
    offload_id          NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    offload_date        DATE NOT NULL,
    port_id             NUMBER(10) NOT NULL,
    reason              VARCHAR2(30) NOT NULL,
    airline             VARCHAR2(100),
    flight_number       VARCHAR2(15),
    destination_country_id NUMBER(10),
    linked_alert_id     NUMBER(10),
    linked_ecl_id       NUMBER(10),
    CONSTRAINT chk_offload_reason CHECK (reason IN ('Invalid Documents','Watchlist Hit','ECL Match','Court Order','Suspicious Behavior','Incomplete Travel Docs','Interpol Alert','Airline Refusal','Other')),
    CONSTRAINT fk_offload_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    CONSTRAINT fk_offload_port FOREIGN KEY (port_id) REFERENCES ports_of_entry(port_id),
    CONSTRAINT fk_offload_country FOREIGN KEY (destination_country_id) REFERENCES countries(country_id),
    CONSTRAINT fk_offload_alert FOREIGN KEY (linked_alert_id) REFERENCES watchlist(alert_id),
    CONSTRAINT fk_offload_ecl FOREIGN KEY (linked_ecl_id) REFERENCES ecl_entries(ecl_id)
);

-- ============================================================
-- 18. RISK PROFILES
-- ============================================================
CREATE TABLE risk_profiles (
    profile_id          NUMBER(10) PRIMARY KEY,
    traveler_id         NUMBER(10) NOT NULL,
    risk_score          NUMBER(5,2) NOT NULL,
    risk_tier           VARCHAR2(10) NOT NULL,
    overstay_history    NUMBER(1) DEFAULT 0,
    watchlist_hits      NUMBER(10) DEFAULT 0,
    conflict_zone_travel NUMBER(1) DEFAULT 0,
    document_fraud_flag NUMBER(1) DEFAULT 0,
    trafficking_association NUMBER(1) DEFAULT 0,
    criminal_record     NUMBER(1) DEFAULT 0,
    network_membership  NUMBER(1) DEFAULT 0,
    last_updated        TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT uq_risk_traveler UNIQUE (traveler_id),
    CONSTRAINT chk_risk_score CHECK (risk_score >= 0 AND risk_score <= 100),
    CONSTRAINT chk_risk_tier CHECK (risk_tier IN ('Low','Medium','High','Critical')),
    CONSTRAINT fk_risk_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 19. SUSPECT NETWORKS
-- ============================================================
CREATE TABLE suspect_networks (
    link_id             NUMBER(10) PRIMARY KEY,
    network_id          VARCHAR2(20) NOT NULL,
    traveler_id         NUMBER(10) NOT NULL,
    role                VARCHAR2(20) NOT NULL,
    confidence_level    VARCHAR2(10),
    identified_date     DATE NOT NULL,
    is_active           NUMBER(1) DEFAULT 1,
    CONSTRAINT chk_network_role CHECK (role IN ('Organizer','Recruiter','Transporter','Financier','Document Forger','Lookout','Coordinator','Unknown')),
    CONSTRAINT chk_confidence CHECK (confidence_level IN ('Low','Medium','High','Confirmed')),
    CONSTRAINT fk_network_traveler FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 20. AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
    log_id              NUMBER(10) PRIMARY KEY,
    table_name          VARCHAR2(50) NOT NULL,
    record_id           NUMBER(10) NOT NULL,
    action              VARCHAR2(10) NOT NULL,
    action_timestamp    TIMESTAMP NOT NULL,
    officer_id          VARCHAR2(20) NOT NULL,
    officer_name        VARCHAR2(100),
    terminal_id         VARCHAR2(30),
    port_id             NUMBER(10),
    ip_address          VARCHAR2(45),
    details             VARCHAR2(500),
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT','UPDATE','DELETE','VIEW','EXPORT')),
    CONSTRAINT fk_audit_port FOREIGN KEY (port_id) REFERENCES ports_of_entry(port_id)
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_travelers_nationality ON travelers(nationality_id);
CREATE INDEX idx_travelers_dob ON travelers(date_of_birth);
CREATE INDEX idx_travel_records_traveler ON travel_records(traveler_id);
CREATE INDEX idx_travel_records_entry_date ON travel_records(entry_date);
CREATE INDEX idx_travel_records_overstay ON travel_records(overstay_flag);
CREATE INDEX idx_visa_apps_traveler ON visa_applications(traveler_id);
CREATE INDEX idx_visa_apps_status ON visa_applications(status);
CREATE INDEX idx_visa_apps_date ON visa_applications(application_date);
CREATE INDEX idx_asylum_status ON asylum_claims(status);
CREATE INDEX idx_watchlist_active ON watchlist(is_active);
CREATE INDEX idx_watchlist_type ON watchlist(alert_type);
CREATE INDEX idx_ecl_status ON ecl_entries(status);
CREATE INDEX idx_risk_tier ON risk_profiles(risk_tier);
CREATE INDEX idx_risk_score ON risk_profiles(risk_score);
CREATE INDEX idx_trafficking_status ON trafficking_cases(status);
CREATE INDEX idx_illegal_crossings_date ON illegal_crossings(detected_date);
CREATE INDEX idx_offloading_date ON offloading_records(offload_date);
CREATE INDEX idx_document_traveler ON document_registry(traveler_id);
CREATE INDEX idx_document_status ON document_registry(status);
CREATE INDEX idx_audit_timestamp ON audit_log(action_timestamp);
CREATE INDEX idx_audit_officer ON audit_log(officer_id);
CREATE INDEX idx_suspect_network_id ON suspect_networks(network_id);
