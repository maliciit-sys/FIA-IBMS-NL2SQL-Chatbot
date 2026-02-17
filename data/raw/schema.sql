
-- ============================================================
-- Immigration Database Schema (PostgreSQL)
-- 20 Tables | Oracle 19c Compatible Naming Conventions
-- Generated for: Jan 2025 - Dec 2025
-- ============================================================

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS audit_log CASCADE;
DROP TABLE IF EXISTS suspect_networks CASCADE;
DROP TABLE IF EXISTS risk_profiles CASCADE;
DROP TABLE IF EXISTS offloading_records CASCADE;
DROP TABLE IF EXISTS illegal_crossings CASCADE;
DROP TABLE IF EXISTS trafficking_cases CASCADE;
DROP TABLE IF EXISTS ecl_entries CASCADE;
DROP TABLE IF EXISTS watchlist CASCADE;
DROP TABLE IF EXISTS family_relationships CASCADE;
DROP TABLE IF EXISTS detention_records CASCADE;
DROP TABLE IF EXISTS removal_orders CASCADE;
DROP TABLE IF EXISTS asylum_claims CASCADE;
DROP TABLE IF EXISTS travel_records CASCADE;
DROP TABLE IF EXISTS visa_applications CASCADE;
DROP TABLE IF EXISTS document_registry CASCADE;
DROP TABLE IF EXISTS sponsors CASCADE;
DROP TABLE IF EXISTS travelers CASCADE;
DROP TABLE IF EXISTS visa_categories CASCADE;
DROP TABLE IF EXISTS ports_of_entry CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

-- ============================================================
-- 1. COUNTRIES
-- ============================================================
CREATE TABLE countries (
    country_id          INTEGER PRIMARY KEY,
    country_name        VARCHAR(100) NOT NULL,
    iso3_code           VARCHAR(3) UNIQUE NOT NULL,
    region              VARCHAR(50) NOT NULL,
    sub_region          VARCHAR(50),
    income_group        VARCHAR(30),
    is_conflict_zone    SMALLINT DEFAULT 0
);

-- ============================================================
-- 2. PORTS OF ENTRY
-- ============================================================
CREATE TABLE ports_of_entry (
    port_id             INTEGER PRIMARY KEY,
    port_name           VARCHAR(150) NOT NULL,
    port_type           VARCHAR(20) NOT NULL CHECK (port_type IN ('Airport','Land Border','Seaport')),
    city                VARCHAR(100),
    country_id          INTEGER NOT NULL,
    iata_code           VARCHAR(10),
    latitude            NUMERIC(9,6),
    longitude           NUMERIC(9,6),
    is_active           SMALLINT DEFAULT 1,
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 3. VISA CATEGORIES
-- ============================================================
CREATE TABLE visa_categories (
    visa_code           VARCHAR(5) PRIMARY KEY,
    visa_name           VARCHAR(100) NOT NULL,
    visa_class          VARCHAR(20) NOT NULL CHECK (visa_class IN ('Immigrant','Non-Immigrant','Refugee','Transit','Diplomatic')),
    max_duration_days   INTEGER,
    allows_work         SMALLINT DEFAULT 0,
    allows_study        SMALLINT DEFAULT 0,
    requires_sponsor    SMALLINT DEFAULT 0,
    description         VARCHAR(255)
);

-- ============================================================
-- 4. TRAVELERS
-- ============================================================
CREATE TABLE travelers (
    traveler_id         INTEGER PRIMARY KEY,
    passport_number     VARCHAR(20) UNIQUE NOT NULL,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    date_of_birth       DATE NOT NULL,
    gender              CHAR(1) CHECK (gender IN ('M','F','X')),
    nationality_id      INTEGER NOT NULL,
    birth_country_id    INTEGER NOT NULL,
    occupation          VARCHAR(100),
    education_level     VARCHAR(20) CHECK (education_level IN ('None','Primary','Secondary','Bachelors','Masters','Doctorate','Professional')),
    marital_status      VARCHAR(10) CHECK (marital_status IN ('Single','Married','Divorced','Widowed')),
    phone_number        VARCHAR(20),
    email               VARCHAR(150),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (nationality_id) REFERENCES countries(country_id),
    FOREIGN KEY (birth_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 5. SPONSORS
-- ============================================================
CREATE TABLE sponsors (
    sponsor_id          INTEGER PRIMARY KEY,
    sponsor_type        VARCHAR(20) NOT NULL CHECK (sponsor_type IN ('Employer','Family','Institution','Government','Self')),
    sponsor_name        VARCHAR(200) NOT NULL,
    country_id          INTEGER NOT NULL,
    city                VARCHAR(100),
    industry            VARCHAR(100),
    registration_number VARCHAR(50),
    is_verified         SMALLINT DEFAULT 0,
    FOREIGN KEY (country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 6. DOCUMENT REGISTRY
-- ============================================================
CREATE TABLE document_registry (
    document_id         INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    document_type       VARCHAR(30) NOT NULL CHECK (document_type IN ('Passport','CNIC','NICOP','Travel Document','Refugee Card','Laissez-Passer')),
    document_number     VARCHAR(50) NOT NULL,
    issuing_country_id  INTEGER NOT NULL,
    issue_date          DATE NOT NULL,
    expiry_date         DATE,
    status              VARCHAR(20) NOT NULL CHECK (status IN ('Valid','Expired','Cancelled','Reported Stolen','Suspended','Under Review')),
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (issuing_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 7. VISA APPLICATIONS
-- ============================================================
CREATE TABLE visa_applications (
    application_id      INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    visa_code           VARCHAR(5) NOT NULL,
    sponsor_id          INTEGER,
    application_date    DATE NOT NULL,
    decision_date       DATE,
    status              VARCHAR(15) NOT NULL CHECK (status IN ('Pending','Approved','Denied','Revoked','Expired','Withdrawn')),
    denial_reason       VARCHAR(255),
    processing_office   VARCHAR(100),
    fee_amount          NUMERIC(10,2),
    fee_currency        VARCHAR(3) DEFAULT 'PKR',
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (visa_code) REFERENCES visa_categories(visa_code),
    FOREIGN KEY (sponsor_id) REFERENCES sponsors(sponsor_id)
);

-- ============================================================
-- 8. TRAVEL RECORDS
-- ============================================================
CREATE TABLE travel_records (
    record_id           INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    application_id      INTEGER,
    entry_port_id       INTEGER,
    exit_port_id        INTEGER,
    entry_date          TIMESTAMP,
    exit_date           TIMESTAMP,
    travel_direction    VARCHAR(10) NOT NULL CHECK (travel_direction IN ('Inbound','Outbound','Transit')),
    travel_purpose      VARCHAR(30),
    flight_number       VARCHAR(15),
    carrier             VARCHAR(100),
    declared_stay_days  INTEGER,
    actual_stay_days    INTEGER,
    overstay_flag       SMALLINT DEFAULT 0,
    flagged_suspicious  SMALLINT DEFAULT 0,
    referral_to_investigation SMALLINT DEFAULT 0,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (application_id) REFERENCES visa_applications(application_id),
    FOREIGN KEY (entry_port_id) REFERENCES ports_of_entry(port_id),
    FOREIGN KEY (exit_port_id) REFERENCES ports_of_entry(port_id)
);

-- ============================================================
-- 9. ASYLUM CLAIMS
-- ============================================================
CREATE TABLE asylum_claims (
    claim_id            INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    filing_date         DATE NOT NULL,
    claim_basis         VARCHAR(20) NOT NULL CHECK (claim_basis IN ('Persecution','War','Political','Religious','Ethnic','Gender-Based','Other')),
    origin_country_id   INTEGER NOT NULL,
    status              VARCHAR(25) NOT NULL CHECK (status IN ('Filed','Under Review','Interview Scheduled','Approved','Denied','Appealed','Withdrawn')),
    decision_date       DATE,
    assigned_officer    VARCHAR(100),
    dependents_count    INTEGER DEFAULT 0,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (origin_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 10. REMOVAL ORDERS
-- ============================================================
CREATE TABLE removal_orders (
    order_id            INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    order_date          DATE NOT NULL,
    reason              VARCHAR(30) NOT NULL CHECK (reason IN ('Visa Overstay','Criminal Offense','Security Threat','Fraudulent Documents','Unauthorized Work','Failed Asylum','Trafficking Involvement','Other')),
    destination_country_id INTEGER NOT NULL,
    execution_date      DATE,
    status              VARCHAR(15) NOT NULL CHECK (status IN ('Issued','Appealed','Executed','Stayed','Cancelled')),
    voluntary_departure SMALLINT DEFAULT 0,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (destination_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 11. DETENTION RECORDS
-- ============================================================
CREATE TABLE detention_records (
    detention_id        INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    facility_name       VARCHAR(150) NOT NULL,
    facility_country_id INTEGER NOT NULL,
    intake_date         DATE NOT NULL,
    release_date        DATE,
    reason              VARCHAR(255),
    removal_order_id    INTEGER,
    status              VARCHAR(15) CHECK (status IN ('Active','Released','Transferred','Deported')),
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (facility_country_id) REFERENCES countries(country_id),
    FOREIGN KEY (removal_order_id) REFERENCES removal_orders(order_id)
);

-- ============================================================
-- 12. FAMILY RELATIONSHIPS
-- ============================================================
CREATE TABLE family_relationships (
    relationship_id     INTEGER PRIMARY KEY,
    traveler_id_1       INTEGER NOT NULL,
    traveler_id_2       INTEGER NOT NULL,
    relationship_type   VARCHAR(15) NOT NULL CHECK (relationship_type IN ('Spouse','Parent','Child','Sibling','Grandparent','Grandchild','Other')),
    verified            SMALLINT DEFAULT 0,
    FOREIGN KEY (traveler_id_1) REFERENCES travelers(traveler_id),
    FOREIGN KEY (traveler_id_2) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 13. WATCHLIST
-- ============================================================
CREATE TABLE watchlist (
    alert_id            INTEGER PRIMARY KEY,
    traveler_id         INTEGER,
    passport_number     VARCHAR(20),
    alert_type          VARCHAR(25) NOT NULL CHECK (alert_type IN ('Security','Criminal','Immigration Violation','Interpol','Lost Document','Fraud','Trafficking','Smuggling','ECL')),
    severity            VARCHAR(10) CHECK (severity IN ('Low','Medium','High','Critical')),
    issued_by           VARCHAR(100),
    issued_date         DATE NOT NULL,
    expiry_date         DATE,
    is_active           SMALLINT DEFAULT 1,
    notes               VARCHAR(500),
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 14. ECL ENTRIES (Exit Control List)
-- ============================================================
CREATE TABLE ecl_entries (
    ecl_id              INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    reason              VARCHAR(30) NOT NULL CHECK (reason IN ('Financial Crime','Court Order','National Security','Terrorism','Tax Evasion','Money Laundering','Pending Investigation','Other')),
    issuing_authority   VARCHAR(100) NOT NULL,
    issued_date         DATE NOT NULL,
    expiry_date         DATE,
    status              VARCHAR(10) NOT NULL CHECK (status IN ('Active','Lifted','Expired','Under Review')),
    case_reference      VARCHAR(50),
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 15. TRAFFICKING CASES
-- ============================================================
CREATE TABLE trafficking_cases (
    case_id             INTEGER PRIMARY KEY,
    case_type           VARCHAR(20) NOT NULL CHECK (case_type IN ('Labor','Sexual','Organ','Forced Marriage','Child','Domestic Servitude','Debt Bondage','Other')),
    victim_traveler_id  INTEGER,
    suspect_traveler_id INTEGER,
    origin_country_id   INTEGER NOT NULL,
    transit_country_id  INTEGER,
    destination_country_id INTEGER NOT NULL,
    reported_date       DATE NOT NULL,
    status              VARCHAR(25) NOT NULL CHECK (status IN ('Open','Under Investigation','Prosecuted','Convicted','Acquitted','Closed')),
    victim_age_at_time  INTEGER,
    victim_gender       CHAR(1),
    FOREIGN KEY (victim_traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (suspect_traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (origin_country_id) REFERENCES countries(country_id),
    FOREIGN KEY (transit_country_id) REFERENCES countries(country_id),
    FOREIGN KEY (destination_country_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 16. ILLEGAL CROSSINGS
-- ============================================================
CREATE TABLE illegal_crossings (
    crossing_id         INTEGER PRIMARY KEY,
    detected_date       TIMESTAMP NOT NULL,
    location_name       VARCHAR(150),
    nearest_port_id     INTEGER,
    latitude            NUMERIC(9,6),
    longitude           NUMERIC(9,6),
    direction           VARCHAR(10) CHECK (direction IN ('Inbound','Outbound')),
    detection_method    VARCHAR(20) NOT NULL CHECK (detection_method IN ('Patrol','Sensor','Tip-Off','Drone','CCTV','Informant','Checkpoint','Other')),
    group_size          INTEGER DEFAULT 1,
    smuggler_linked     SMALLINT DEFAULT 0,
    apprehended_count   INTEGER DEFAULT 0,
    outcome             VARCHAR(20) NOT NULL CHECK (outcome IN ('Apprehended','Escaped','Turned Back','Partial Capture')),
    lead_traveler_id    INTEGER,
    nationality_id      INTEGER,
    FOREIGN KEY (nearest_port_id) REFERENCES ports_of_entry(port_id),
    FOREIGN KEY (lead_traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (nationality_id) REFERENCES countries(country_id)
);

-- ============================================================
-- 17. OFFLOADING RECORDS
-- ============================================================
CREATE TABLE offloading_records (
    offload_id          INTEGER PRIMARY KEY,
    traveler_id         INTEGER NOT NULL,
    offload_date        DATE NOT NULL,
    port_id             INTEGER NOT NULL,
    reason              VARCHAR(30) NOT NULL CHECK (reason IN ('Invalid Documents','Watchlist Hit','ECL Match','Court Order','Suspicious Behavior','Incomplete Travel Docs','Interpol Alert','Airline Refusal','Other')),
    airline             VARCHAR(100),
    flight_number       VARCHAR(15),
    destination_country_id INTEGER,
    linked_alert_id     INTEGER,
    linked_ecl_id       INTEGER,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id),
    FOREIGN KEY (port_id) REFERENCES ports_of_entry(port_id),
    FOREIGN KEY (destination_country_id) REFERENCES countries(country_id),
    FOREIGN KEY (linked_alert_id) REFERENCES watchlist(alert_id),
    FOREIGN KEY (linked_ecl_id) REFERENCES ecl_entries(ecl_id)
);

-- ============================================================
-- 18. RISK PROFILES
-- ============================================================
CREATE TABLE risk_profiles (
    profile_id          INTEGER PRIMARY KEY,
    traveler_id         INTEGER UNIQUE NOT NULL,
    risk_score          NUMERIC(5,2) NOT NULL CHECK (risk_score >= 0 AND risk_score <= 100),
    risk_tier           VARCHAR(10) NOT NULL CHECK (risk_tier IN ('Low','Medium','High','Critical')),
    overstay_history    SMALLINT DEFAULT 0,
    watchlist_hits      INTEGER DEFAULT 0,
    conflict_zone_travel SMALLINT DEFAULT 0,
    document_fraud_flag SMALLINT DEFAULT 0,
    trafficking_association SMALLINT DEFAULT 0,
    criminal_record     SMALLINT DEFAULT 0,
    network_membership  SMALLINT DEFAULT 0,
    last_updated        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 19. SUSPECT NETWORKS
-- ============================================================
CREATE TABLE suspect_networks (
    link_id             INTEGER PRIMARY KEY,
    network_id          VARCHAR(20) NOT NULL,
    traveler_id         INTEGER NOT NULL,
    role                VARCHAR(20) NOT NULL CHECK (role IN ('Organizer','Recruiter','Transporter','Financier','Document Forger','Lookout','Coordinator','Unknown')),
    confidence_level    VARCHAR(10) CHECK (confidence_level IN ('Low','Medium','High','Confirmed')),
    identified_date     DATE NOT NULL,
    is_active           SMALLINT DEFAULT 1,
    FOREIGN KEY (traveler_id) REFERENCES travelers(traveler_id)
);

-- ============================================================
-- 20. AUDIT LOG
-- ============================================================
CREATE TABLE audit_log (
    log_id              INTEGER PRIMARY KEY,
    table_name          VARCHAR(50) NOT NULL,
    record_id           INTEGER NOT NULL,
    action              VARCHAR(10) NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE','VIEW','EXPORT')),
    action_timestamp    TIMESTAMP NOT NULL,
    officer_id          VARCHAR(20) NOT NULL,
    officer_name        VARCHAR(100),
    terminal_id         VARCHAR(30),
    port_id             INTEGER,
    ip_address          VARCHAR(45),
    details             VARCHAR(500),
    FOREIGN KEY (port_id) REFERENCES ports_of_entry(port_id)
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
