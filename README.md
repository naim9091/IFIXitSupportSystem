# IFIXitSupportSystem
# IFixIT — Oracle APEX Database & CRUD API Reference



---

## 1. Entity Relationship Overview

```
IFIX_DEPARTMENTS ──< IFIX_USERS >──────────── IFIX_TECHNICIANS
                                   │                │
                              IFIX_TICKETS ──────────┤
                                   │                │
                          IFIX_TICKET_HISTORY   IFIX_APPOINTMENTS
                                   │                │
                              IFIX_ASSETS <──── IFIX_ASSET_ASSIGNMENTS
                                                     │
                                              IFIX_REQUISITIONS
```

---

## 2. Tables

### `IFIX_DEPARTMENTS`
| Column | Type | Notes |
|---|---|---|
| dept_id | NUMBER (PK) | identity |
| dept_name | VARCHAR2(120) | e.g. UBS Software |
| dept_code | VARCHAR2(20) | unique short code e.g. UBS |
| location | VARCHAR2(200) | floor / building |
| is_active | CHAR(1) | Y/N |

---

### `IFIX_USERS`
| Column | Type | Notes |
|---|---|---|
| user_id | NUMBER (PK) | identity |
| username | VARCHAR2(60) | unique login name |
| full_name | VARCHAR2(200) | |
| email | VARCHAR2(200) | unique |
| phone | VARCHAR2(30) | |
| pabx_ext | VARCHAR2(20) | e.g. 1000 |
| role | VARCHAR2(20) | USER / TECHNICIAN / ADMIN |
| dept_id | NUMBER (FK) | → departments |
| password_hash | VARCHAR2(256) | SHA-256 hash |
| is_active | CHAR(1) | Y/N |

---

### `IFIX_TECHNICIANS`
| Column | Type | Notes |
|---|---|---|
| tech_id | NUMBER (PK) | identity |
| user_id | NUMBER (FK, unique) | → users |
| expertise | VARCHAR2(500) | pipe-separated: hardware\|networking\|software\|graphics\|peripheral |
| max_tickets | NUMBER(3) | workload cap |
| is_available | CHAR(1) | Y/N |

---

### `IFIX_ASSETS`
| Column | Type | Notes |
|---|---|---|
| asset_id | NUMBER (PK) | identity |
| asset_tag | VARCHAR2(50) | unique e.g. PC 140 |
| asset_name | VARCHAR2(200) | e.g. Dell Latitude 3420 |
| brand / model / serial_no | VARCHAR2 | |
| ip_address | VARCHAR2(45) | last known IP |
| asset_type | VARCHAR2(50) | LAPTOP / DESKTOP / MONITOR / PERIPHERAL / NETWORK / SERVER / PRINTER / OTHER |
| purchase_date / warranty_end | DATE | |
| status | VARCHAR2(30) | ACTIVE / UNDER_REPAIR / RETIRED / LOST |
| dept_id | NUMBER (FK) | → departments |

---

### `IFIX_ASSET_ASSIGNMENTS`
| Column | Type | Notes |
|---|---|---|
| assignment_id | NUMBER (PK) | identity |
| asset_id | NUMBER (FK) | → assets |
| user_id | NUMBER (FK) | → users |
| assigned_date | DATE | |
| returned_date | DATE | null if current |
| assigned_by | NUMBER (FK) | → users (admin) |
| is_current | CHAR(1) | Y = active assignment |

---

### `IFIX_TICKETS`
| Column | Type | Notes |
|---|---|---|
| ticket_id | NUMBER (PK) | identity |
| ticket_no | VARCHAR2(20) | auto T{seq} e.g. T234 |
| problem_desc | VARCHAR2(1000) | |
| asset_id | NUMBER (FK) | → assets |
| requester_id | NUMBER (FK) | → users |
| assigned_to | NUMBER (FK) | → technicians |
| expertise_tag | VARCHAR2(100) | power supply / networking / software / graphics / peripheral |
| priority | VARCHAR2(20) | LOW / MEDIUM / HIGH / CRITICAL |
| status | VARCHAR2(30) | OPEN → ASSIGNED → IN_PROGRESS → PENDING_PART → RESOLVED → CLOSED |
| sla_hours | NUMBER(5) | auto-set: CRITICAL=2, HIGH=4, MEDIUM=8, LOW=24 |
| opened_at / assigned_at / resolved_at / closed_at | TIMESTAMP | auto-set by triggers |

---

### `IFIX_TICKET_HISTORY`
| Column | Type | Notes |
|---|---|---|
| history_id | NUMBER (PK) | identity |
| ticket_id | NUMBER (FK) | → tickets |
| changed_by | NUMBER (FK) | → users |
| old_status / new_status | VARCHAR2(30) | |
| note | VARCHAR2(2000) | free text update |
| changed_at | TIMESTAMP | auto |

---

### `IFIX_APPOINTMENTS`
| Column | Type | Notes |
|---|---|---|
| appt_id | NUMBER (PK) | identity |
| ticket_id | NUMBER (FK) | → tickets |
| tech_id | NUMBER (FK) | → technicians |
| requester_id | NUMBER (FK) | → users |
| appt_date | DATE | |
| time_slot_from / time_slot_to | VARCHAR2(8) | HH24:MI e.g. 10:30 |
| status | VARCHAR2(20) | SCHEDULED / CONFIRMED / IN_PROGRESS / COMPLETED / CANCELLED / NO_SHOW |
| reminder_sent | CHAR(1) | Y/N |

---

### `IFIX_REQUISITIONS`
| Column | Type | Notes |
|---|---|---|
| req_id | NUMBER (PK) | identity |
| req_no | VARCHAR2(20) | auto REQ-0001 |
| item_desc | VARCHAR2(300) | e.g. MacBook replacement |
| requester_id | NUMBER (FK) | → users |
| approved_by | NUMBER (FK) | → users (admin) |
| status | VARCHAR2(30) | PENDING / APPROVED / REJECTED / ORDERED / DELIVERED / CANCELLED |
| priority | VARCHAR2(20) | LOW / MEDIUM / HIGH |
| estimated_eta | DATE | ETA from admin |

---

## 3. REST API Endpoints

Base URL: `https://oracleapex.com/ords/space_test/ifixit/v1`


### Tickets
| Method | Path | Description |
|---|---|---|
| GET | `/tickets` | List — filter by `?status=OPEN&requester_id=5` |
| POST | `/tickets` | Create ticket |
| GET | `/tickets/:id` | Get single ticket |
| PUT | `/tickets/:id` | Full update |
| PATCH | `/tickets/:id` | Status/assignment change |
| DELETE | `/tickets/:id` | Soft-cancel |
| GET | `/tickets/:id/history` | Audit trail |

### Appointments
| Method | Path | Description |
|---|---|---|
| GET | `/appointments` | List — filter by `?requester_id=&appt_date=&status=` |
| POST | `/appointments` | Book (double-booking check included) |
| GET | `/appointments/:id` | Get single |
| PUT | `/appointments/:id` | Update slot / technician |
| DELETE | `/appointments/:id` | Cancel |

### Users
| Method | Path | Description |
|---|---|---|
| GET | `/users` | List — filter `?role=TECHNICIAN` |
| POST | `/users` | Create (password auto-hashed SHA-256) |
| GET | `/users/:id` | Get single |
| PUT | `/users/:id` | Update |
| DELETE | `/users/:id` | Deactivate |

### Assets
| Method | Path | Description |
|---|---|---|
| GET | `/assets` | List — filter `?asset_type=LAPTOP&status=ACTIVE` |
| POST | `/assets` | Create |
| GET | `/assets/:id` | Get single |
| PUT | `/assets/:id` | Update |
| DELETE | `/assets/:id` | Retire |
| POST | `/assets/:id/assign` | Assign to user |

### Requisitions
| Method | Path | Description |
|---|---|---|
| GET | `/requisitions` | List |
| POST | `/requisitions` | Submit request |
| GET | `/requisitions/:id` | Get single |
| PATCH | `/requisitions/:id` | Approve / reject / update ETA |

### KPI
| Method | Path | Description |
|---|---|---|
| GET | `/kpi/summary` | Admin dashboard counts + resolution % + avg hours |

---

## 4. Ticket Status Flow

```
OPEN → ASSIGNED → IN_PROGRESS → RESOLVED → CLOSED
              ↓               ↓
         PENDING_PART      CANCELLED
```

Every status transition is recorded automatically in `IFIX_TICKET_HISTORY` — this drives the **real-time track** feature shown in Frame 3 of the mockup.




