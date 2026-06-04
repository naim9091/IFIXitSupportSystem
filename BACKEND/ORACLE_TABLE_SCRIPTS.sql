-- =============================================================
--  IFixIT · IT Support System
--  Oracle APEX Database Schema (DDL)
--  Generated from mockup: deepseek_html_20260303
--  Tables: USERS, DEPARTMENTS, ASSETS, TICKETS,
--          APPOINTMENTS, TECHNICIANS, REQUISITIONS,
--          ASSET_ASSIGNMENTS, TICKET_HISTORY
-- =============================================================

-- ─────────────────────────────────────────────
-- 1. DEPARTMENTS
-- ─────────────────────────────────────────────
CREATE TABLE ifix_departments (
    dept_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dept_name      VARCHAR2(120)  NOT NULL,
    dept_code      VARCHAR2(20)   UNIQUE NOT NULL,
    location       VARCHAR2(200),
    is_active      CHAR(1)        DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y','N')),
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_departments              IS 'Company departments / business units';
COMMENT ON COLUMN ifix_departments.dept_code    IS 'Short identifier e.g. UBS, IT, HR';


-- ─────────────────────────────────────────────
-- 2. USERS  (end-users and admins)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_users (
    user_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username       VARCHAR2(60)   UNIQUE NOT NULL,
    full_name      VARCHAR2(200)  NOT NULL,
    email          VARCHAR2(200)  UNIQUE NOT NULL,
    phone          VARCHAR2(30),
    pabx_ext       VARCHAR2(20),
    role           VARCHAR2(20)   DEFAULT 'USER' NOT NULL
                       CHECK (role IN ('USER','TECHNICIAN','ADMIN')),
    dept_id        NUMBER         REFERENCES ifix_departments(dept_id),
    password_hash  VARCHAR2(256)  NOT NULL,   -- store hashed password only
    is_active      CHAR(1)        DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y','N')),
    last_login     TIMESTAMP,
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_users           IS 'All system users: end-users, technicians, admins';
COMMENT ON COLUMN ifix_users.role      IS 'USER = regular staff, TECHNICIAN = IT staff, ADMIN = admin';
COMMENT ON COLUMN ifix_users.pabx_ext  IS 'Internal PABX/phone extension e.g. 1000';


-- ─────────────────────────────────────────────
-- 3. TECHNICIANS  (expertise profile for IT staff)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_technicians (
    tech_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        NUMBER         NOT NULL UNIQUE REFERENCES ifix_users(user_id),
    expertise      VARCHAR2(500)  NOT NULL,   -- comma-separated e.g. 'hardware,networking,software'
    max_tickets    NUMBER(3)      DEFAULT 10,
    is_available   CHAR(1)        DEFAULT 'Y' NOT NULL CHECK (is_available IN ('Y','N')),
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_technicians           IS 'IT technician expertise profiles';
COMMENT ON COLUMN ifix_technicians.expertise IS 'Pipe or comma separated expertise tags: hardware|networking|software|graphics|peripheral|power supply';


-- ─────────────────────────────────────────────
-- 4. ASSETS  (IT equipment inventory)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_assets (
    asset_id       NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_tag      VARCHAR2(50)   UNIQUE NOT NULL,   -- e.g. PC 140
    asset_name     VARCHAR2(200)  NOT NULL,           -- e.g. Dell Latitude 3420
    brand          VARCHAR2(100),
    model          VARCHAR2(100),
    serial_no      VARCHAR2(100),
    ip_address     VARCHAR2(45),                      -- IPv4 or IPv6
    asset_type     VARCHAR2(50)   NOT NULL
                       CHECK (asset_type IN ('LAPTOP','DESKTOP','MONITOR','PERIPHERAL',
                                             'NETWORK','SERVER','PRINTER','OTHER')),
    purchase_date  DATE,
    warranty_end   DATE,
    status         VARCHAR2(30)   DEFAULT 'ACTIVE' NOT NULL
                       CHECK (status IN ('ACTIVE','UNDER_REPAIR','RETIRED','LOST')),
    dept_id        NUMBER         REFERENCES ifix_departments(dept_id),
    notes          CLOB,
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_assets            IS 'IT equipment / asset inventory';
COMMENT ON COLUMN ifix_assets.asset_tag  IS 'Unique short label printed on device e.g. PC 102';
COMMENT ON COLUMN ifix_assets.ip_address IS 'Last known IP e.g. 103.30.190.27';


-- ─────────────────────────────────────────────
-- 5. ASSET_ASSIGNMENTS  (who holds which asset)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_asset_assignments (
    assignment_id  NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    asset_id       NUMBER         NOT NULL REFERENCES ifix_assets(asset_id),
    user_id        NUMBER         NOT NULL REFERENCES ifix_users(user_id),
    assigned_date  DATE           DEFAULT SYSDATE NOT NULL,
    returned_date  DATE,
    assigned_by    NUMBER         REFERENCES ifix_users(user_id),
    notes          VARCHAR2(500),
    is_current     CHAR(1)        DEFAULT 'Y' NOT NULL CHECK (is_current IN ('Y','N')),
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_asset_assignments IS 'History of asset assignments to users';


-- ─────────────────────────────────────────────
-- 6. TICKETS  (support tickets)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_tickets (
    ticket_id      NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_no      VARCHAR2(20)   UNIQUE NOT NULL,   -- e.g. T234
    problem_desc   VARCHAR2(1000) NOT NULL,
    asset_id       NUMBER         REFERENCES ifix_assets(asset_id),
    requester_id   NUMBER         NOT NULL REFERENCES ifix_users(user_id),
    assigned_to    NUMBER         REFERENCES ifix_technicians(tech_id),
    expertise_tag  VARCHAR2(100),   -- power supply, networking, software, graphics, peripheral
    priority       VARCHAR2(20)   DEFAULT 'MEDIUM' NOT NULL
                       CHECK (priority IN ('LOW','MEDIUM','HIGH','CRITICAL')),
    status         VARCHAR2(30)   DEFAULT 'OPEN' NOT NULL
                       CHECK (status IN ('OPEN','ASSIGNED','IN_PROGRESS','PENDING_PART',
                                         'RESOLVED','CLOSED','CANCELLED')),
    sla_hours      NUMBER(5),       -- SLA target hours based on priority
    opened_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    assigned_at    TIMESTAMP,
    resolved_at    TIMESTAMP,
    closed_at      TIMESTAMP,
    resolution     CLOB,
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_tickets               IS 'IT support tickets';
COMMENT ON COLUMN ifix_tickets.ticket_no     IS 'Human-readable ID e.g. T234 – auto-generated via trigger';
COMMENT ON COLUMN ifix_tickets.expertise_tag IS 'Maps to technician expertise for smart assignment';
COMMENT ON COLUMN ifix_tickets.sla_hours     IS '4 = High, 8 = Medium, 24 = Low (customisable)';


-- ─────────────────────────────────────────────
-- 7. TICKET_HISTORY  (audit trail / real-time track)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_ticket_history (
    history_id     NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id      NUMBER         NOT NULL REFERENCES ifix_tickets(ticket_id),
    changed_by     NUMBER         NOT NULL REFERENCES ifix_users(user_id),
    old_status     VARCHAR2(30),
    new_status     VARCHAR2(30),
    note           VARCHAR2(2000),
    changed_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE ifix_ticket_history IS 'Every status change on a ticket – drives real-time tracking';


-- ─────────────────────────────────────────────
-- 8. APPOINTMENTS  (schedule support visits)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_appointments (
    appt_id        NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ticket_id      NUMBER         NOT NULL REFERENCES ifix_tickets(ticket_id),
    tech_id        NUMBER         REFERENCES ifix_technicians(tech_id),
    requester_id   NUMBER         NOT NULL REFERENCES ifix_users(user_id),
    appt_date      DATE           NOT NULL,
    time_slot_from VARCHAR2(8)    NOT NULL,  -- e.g. 10:30
    time_slot_to   VARCHAR2(8)    NOT NULL,  -- e.g. 11:30
    status         VARCHAR2(20)   DEFAULT 'SCHEDULED' NOT NULL
                       CHECK (status IN ('SCHEDULED','CONFIRMED','IN_PROGRESS',
                                         'COMPLETED','CANCELLED','NO_SHOW')),
    location_notes VARCHAR2(500),
    reminder_sent  CHAR(1)        DEFAULT 'N' NOT NULL CHECK (reminder_sent IN ('Y','N')),
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE  ifix_appointments            IS 'Appointment scheduler: links ticket to tech and time slot';
COMMENT ON COLUMN ifix_appointments.time_slot_from IS 'Start time HH24:MI';
COMMENT ON COLUMN ifix_appointments.time_slot_to   IS 'End time HH24:MI';


-- ─────────────────────────────────────────────
-- 9. REQUISITIONS  (asset / hardware requests)
-- ─────────────────────────────────────────────
CREATE TABLE ifix_requisitions (
    req_id         NUMBER         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    req_no         VARCHAR2(20)   UNIQUE NOT NULL,  -- e.g. REQ-001
    item_desc      VARCHAR2(300)  NOT NULL,          -- e.g. MacBook replacement
    requester_id   NUMBER         NOT NULL REFERENCES ifix_users(user_id),
    approved_by    NUMBER         REFERENCES ifix_users(user_id),
    status         VARCHAR2(30)   DEFAULT 'PENDING' NOT NULL
                       CHECK (status IN ('PENDING','APPROVED','REJECTED',
                                         'ORDERED','DELIVERED','CANCELLED')),
    priority       VARCHAR2(20)   DEFAULT 'MEDIUM'
                       CHECK (priority IN ('LOW','MEDIUM','HIGH')),
    estimated_eta  DATE,
    admin_notes    VARCHAR2(1000),
    created_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at     TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL
);

COMMENT ON TABLE ifix_requisitions IS 'Hardware/asset purchase requests from users';


-- =============================================================
--  INDEXES  (performance)
-- =============================================================
CREATE INDEX idx_tickets_status       ON ifix_tickets(status);
CREATE INDEX idx_tickets_requester    ON ifix_tickets(requester_id);
CREATE INDEX idx_tickets_assigned     ON ifix_tickets(assigned_to);
CREATE INDEX idx_tickets_opened       ON ifix_tickets(opened_at);
CREATE INDEX idx_appts_date           ON ifix_appointments(appt_date);
CREATE INDEX idx_appts_ticket         ON ifix_appointments(ticket_id);
CREATE INDEX idx_history_ticket       ON ifix_ticket_history(ticket_id);
CREATE INDEX idx_assets_tag           ON ifix_assets(asset_tag);
CREATE INDEX idx_assignments_user     ON ifix_asset_assignments(user_id);
CREATE INDEX idx_assignments_asset    ON ifix_asset_assignments(asset_id);


-- =============================================================
--  SEQUENCES  (for ticket_no / req_no generation)
-- =============================================================
CREATE SEQUENCE seq_ticket_no START WITH 200 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_req_no    START WITH 1   INCREMENT BY 1 NOCACHE;


-- =============================================================
--  TRIGGERS
-- =============================================================

-- Auto-generate ticket_no  e.g. T234
CREATE OR REPLACE TRIGGER trg_ticket_no
BEFORE INSERT ON ifix_tickets
FOR EACH ROW
BEGIN
    IF :NEW.ticket_no IS NULL THEN
        :NEW.ticket_no := 'T' || TO_CHAR(seq_ticket_no.NEXTVAL);
    END IF;
    :NEW.created_at := SYSTIMESTAMP;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- Auto-update updated_at on tickets
CREATE OR REPLACE TRIGGER trg_ticket_upd
BEFORE UPDATE ON ifix_tickets
FOR EACH ROW
BEGIN
    :NEW.updated_at := SYSTIMESTAMP;
    -- capture assigned_at / resolved_at timestamps automatically
    IF :OLD.status != 'ASSIGNED' AND :NEW.status = 'ASSIGNED' THEN
        :NEW.assigned_at := SYSTIMESTAMP;
    END IF;
    IF :OLD.status NOT IN ('RESOLVED','CLOSED') AND :NEW.status = 'RESOLVED' THEN
        :NEW.resolved_at := SYSTIMESTAMP;
    END IF;
END;
/

-- Auto-generate req_no  e.g. REQ-001
CREATE OR REPLACE TRIGGER trg_req_no
BEFORE INSERT ON ifix_requisitions
FOR EACH ROW
BEGIN
    IF :NEW.req_no IS NULL THEN
        :NEW.req_no := 'REQ-' || LPAD(seq_req_no.NEXTVAL, 4, '0');
    END IF;
    :NEW.created_at := SYSTIMESTAMP;
    :NEW.updated_at := SYSTIMESTAMP;
END;
/

-- updated_at auto-refresh helpers
CREATE OR REPLACE TRIGGER trg_users_upd       BEFORE UPDATE ON ifix_users        FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /
CREATE OR REPLACE TRIGGER trg_assets_upd      BEFORE UPDATE ON ifix_assets       FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /
CREATE OR REPLACE TRIGGER trg_appts_upd       BEFORE UPDATE ON ifix_appointments FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /
CREATE OR REPLACE TRIGGER trg_reqs_upd        BEFORE UPDATE ON ifix_requisitions FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /
CREATE OR REPLACE TRIGGER trg_tech_upd        BEFORE UPDATE ON ifix_technicians  FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /
CREATE OR REPLACE TRIGGER trg_dept_upd        BEFORE UPDATE ON ifix_departments  FOR EACH ROW BEGIN :NEW.updated_at := SYSTIMESTAMP; END; /


-- =============================================================
--  SEED DATA  (reference / demo)
-- =============================================================

-- Departments
INSERT INTO ifix_departments (dept_name, dept_code, location) VALUES ('Information Technology', 'IT',  'Floor 3');
INSERT INTO ifix_departments (dept_name, dept_code, location) VALUES ('UBS Software',           'UBS', 'Floor 2');
INSERT INTO ifix_departments (dept_name, dept_code, location) VALUES ('Human Resources',        'HR',  'Floor 1');
INSERT INTO ifix_departments (dept_name, dept_code, location) VALUES ('Finance',                'FIN', 'Floor 1');

COMMIT;
