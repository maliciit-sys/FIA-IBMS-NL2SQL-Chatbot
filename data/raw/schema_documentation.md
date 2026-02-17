# Immigration Database - Schema Documentation

## Overview
- **Tables:** 20
- **Total rows:** ~1.56 million
- **Time period:** January 1, 2025 - December 31, 2025
- **Primary schema:** PostgreSQL (see `schema.sql`)
- **Oracle 19c compatible:** Column names, data types, and constraints designed for easy migration

---

## Table Summary

| # | Table | ~Rows | Type | Description |
|---|-------|-------|------|-------------|
| 1 | countries | 50 | Reference | Country master with ISO codes, regions, income groups |
| 2 | ports_of_entry | 39 | Reference | Airports, land borders, seaports with coordinates |
| 3 | visa_categories | 20 | Reference | All visa types with permissions and constraints |
| 4 | sponsors | 100 | Reference | Employers, families, institutions, government bodies |
| 5 | travelers | 150,000 | Core Entity | Person records with demographics |
| 6 | document_registry | ~200,000 | Core Entity | Passports, CNICs, NICOPs, refugee cards |
| 7 | visa_applications | 250,000 | Transaction | Application lifecycle with fees and decisions |
| 8 | travel_records | 500,000 | Transaction | Entry/exit movements with carrier and flags |
| 9 | asylum_claims | 30,000 | Transaction | Refugee/asylum case pipeline |
| 10 | removal_orders | 15,000 | Transaction | Deportation and removal proceedings |
| 11 | detention_records | 12,000 | Transaction | Facility detention with hold durations |
| 12 | family_relationships | 50,000 | Relationship | Traveler-to-traveler family links |
| 13 | watchlist | 8,000 | Flag | Security/criminal/immigration alerts |
| 14 | ecl_entries | 3,000 | Flag | Exit Control List entries |
| 15 | trafficking_cases | 5,000 | Investigation | Human trafficking case records |
| 16 | illegal_crossings | 25,000 | Investigation | Unauthorized border crossing events |
| 17 | offloading_records | 10,000 | Enforcement | Airport offloading with linked alerts |
| 18 | risk_profiles | 150,000 | Analytics | Composite risk scores per traveler |
| 19 | suspect_networks | 5,000 | Investigation | Smuggling/trafficking network links |
| 20 | audit_log | 100,000 | System | Officer access and modification trail |

---

## Foreign Key Map
```
countries (country_id) <--+-- ports_of_entry.country_id
                          +-- travelers.nationality_id
                          +-- travelers.birth_country_id
                          +-- sponsors.country_id
                          +-- document_registry.issuing_country_id
                          +-- asylum_claims.origin_country_id
                          +-- removal_orders.destination_country_id
                          +-- detention_records.facility_country_id
                          +-- trafficking_cases.origin_country_id
                          +-- trafficking_cases.transit_country_id
                          +-- trafficking_cases.destination_country_id
                          +-- illegal_crossings.nationality_id
                          +-- offloading_records.destination_country_id

ports_of_entry (port_id) <--+-- travel_records.entry_port_id
                            +-- travel_records.exit_port_id
                            +-- illegal_crossings.nearest_port_id
                            +-- offloading_records.port_id
                            +-- audit_log.port_id

visa_categories (visa_code) <-- visa_applications.visa_code

travelers (traveler_id) <--+-- document_registry.traveler_id
                           +-- visa_applications.traveler_id
                           +-- travel_records.traveler_id
                           +-- asylum_claims.traveler_id
                           +-- removal_orders.traveler_id
                           +-- detention_records.traveler_id
                           +-- family_relationships.traveler_id_1
                           +-- family_relationships.traveler_id_2
                           +-- watchlist.traveler_id
                           +-- ecl_entries.traveler_id
                           +-- trafficking_cases.victim_traveler_id
                           +-- trafficking_cases.suspect_traveler_id
                           +-- illegal_crossings.lead_traveler_id
                           +-- offloading_records.traveler_id
                           +-- risk_profiles.traveler_id
                           +-- suspect_networks.traveler_id

sponsors (sponsor_id) <-- visa_applications.sponsor_id

visa_applications (application_id) <-- travel_records.application_id

removal_orders (order_id) <-- detention_records.removal_order_id

watchlist (alert_id) <-- offloading_records.linked_alert_id

ecl_entries (ecl_id) <-- offloading_records.linked_ecl_id
```

---

## Oracle 19c Conversion Notes

### Data Type Mapping
| PostgreSQL | Oracle 19c |
|-----------|------------|
| INTEGER | NUMBER(10) |
| SMALLINT | NUMBER(1) |
| VARCHAR(n) | VARCHAR2(n) |
| CHAR(1) | CHAR(1) |
| NUMERIC(p,s) | NUMBER(p,s) |
| DATE | DATE |
| TIMESTAMP | TIMESTAMP |
| TEXT | VARCHAR2(4000) or CLOB |

### Key Differences
1. **Sequences:** Replace PostgreSQL SERIAL with Oracle SEQUENCE + TRIGGER or IDENTITY columns (12c+)
2. **CHECK constraints:** Fully supported in Oracle, no changes needed
3. **DEFAULT CURRENT_TIMESTAMP:** Use `DEFAULT SYSTIMESTAMP` in Oracle
4. **Boolean columns:** Already using SMALLINT (0/1), compatible with Oracle NUMBER(1)
5. **CASCADE drops:** `DROP TABLE ... CASCADE CONSTRAINTS` in Oracle
6. **Index naming:** Oracle has 30-char limit (pre-12.2) or 128-char (12.2+), current names are fine
7. **NULL handling:** Oracle treats empty string as NULL; CSV empty fields will load as NULL automatically

### Recommended Load Order (respects FK dependencies)
1. countries
2. ports_of_entry
3. visa_categories
4. sponsors
5. travelers
6. document_registry
7. visa_applications
8. travel_records
9. asylum_claims
10. removal_orders
11. detention_records
12. family_relationships
13. watchlist
14. ecl_entries
15. trafficking_cases
16. illegal_crossings
17. offloading_records
18. risk_profiles
19. suspect_networks
20. audit_log

### CSV Loading with Oracle SQL*Loader
```
-- Example control file for travelers
LOAD DATA
INFILE 'travelers.csv'
INTO TABLE travelers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
  traveler_id,
  passport_number,
  first_name,
  last_name,
  date_of_birth DATE "YYYY-MM-DD",
  gender,
  nationality_id,
  birth_country_id,
  occupation,
  education_level,
  marital_status,
  phone_number,
  email,
  created_at TIMESTAMP "YYYY-MM-DD HH24:MI:SS"
)
```

---

## Dirty Data Intentionally Included
- **~2-3% misspelled names** in travelers (swapped chars, doubled letters, dropped letters)
- **~15% missing phone numbers** in travelers
- **~40% missing emails** in travelers
- **~1% missing decision_date** on decided visa applications
- **~3% missing sponsor_id** where one should exist
- **~8% missing exit_date** on inbound travel records
- **~5% missing passport_number** on watchlist entries (name-only alerts)
- **~30% unidentified victims** in trafficking cases
- **~40% unidentified suspects** in trafficking cases
- **~60% unidentified lead travelers** in illegal crossings
