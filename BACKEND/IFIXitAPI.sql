-- =============================================================
--  IFixIT · IT Support System
--  Oracle APEX / ORDS  –  CRUD REST API  (PL/SQL handler bodies)
--  Enable via: APEX > SQL Workshop > RESTful Services
--              OR use ORDS auto-REST (see Section A below)
-- =============================================================

-- =============================================================
-- SECTION A – AUTO-REST  (quickest option in APEX/ORDS)
-- Run these statements to instantly expose every table as REST.
-- Endpoints: GET /ords/<schema>/ifix_tickets/
--            GET /ords/<schema>/ifix_tickets/:id
--            POST / PUT / DELETE automatically available.
-- =============================================================

BEGIN
    ORDS.ENABLE_OBJECT(
        p_enabled      => TRUE,
        p_schema       => SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),
        p_object       => 'IFIX_TICKETS',
        p_object_type  => 'TABLE',
        p_object_alias => 'ifix_tickets',
        p_auto_rest_auth => FALSE
    );
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_USERS',          p_object_type=>'TABLE',p_object_alias=>'ifix_users',          p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_ASSETS',         p_object_type=>'TABLE',p_object_alias=>'ifix_assets',         p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_APPOINTMENTS',   p_object_type=>'TABLE',p_object_alias=>'ifix_appointments',   p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_REQUISITIONS',   p_object_type=>'TABLE',p_object_alias=>'ifix_requisitions',   p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_DEPARTMENTS',    p_object_type=>'TABLE',p_object_alias=>'ifix_departments',    p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_TECHNICIANS',    p_object_type=>'TABLE',p_object_alias=>'ifix_technicians',    p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_TICKET_HISTORY', p_object_type=>'TABLE',p_object_alias=>'ifix_ticket_history', p_auto_rest_auth=>FALSE);
    ORDS.ENABLE_OBJECT(p_enabled=>TRUE,p_schema=>SYS_CONTEXT('USERENV','CURRENT_SCHEMA'),p_object=>'IFIX_ASSET_ASSIGNMENTS',p_object_type=>'TABLE',p_object_alias=>'ifix_asset_assignments',p_auto_rest_auth=>FALSE);
    COMMIT;
END;
/


-- =============================================================
-- SECTION B – CUSTOM ORDS MODULE  (fine-grained REST handlers)
-- Module base path: /ifixit/v1/
-- =============================================================

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name    => 'ifixit.v1',
        p_base_path      => '/ifixit/v1/',
        p_items_per_page => 25,
        p_status         => 'PUBLISHED',
        p_comments       => 'IFixIT REST API v1'
    );
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: TICKETS
--  GET    /ifixit/v1/tickets          – list all tickets
--  GET    /ifixit/v1/tickets/:id      – get single ticket
--  POST   /ifixit/v1/tickets          – create ticket
--  PUT    /ifixit/v1/tickets/:id      – full update
--  PATCH  /ifixit/v1/tickets/:id      – partial update (status)
--  DELETE /ifixit/v1/tickets/:id      – soft-delete (cancel)
-- ══════════════════════════════════════════════════════════════

-- GET /tickets  (list with optional filters: status, requester_id, assigned_to)
BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'tickets');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_collection_feed,
        p_source         => q'[
            SELECT
                t.ticket_id,
                t.ticket_no,
                t.problem_desc,
                t.expertise_tag,
                t.priority,
                t.status,
                t.sla_hours,
                t.opened_at,
                t.assigned_at,
                t.resolved_at,
                u.full_name        AS requester_name,
                u.email            AS requester_email,
                tu.full_name       AS technician_name,
                a.asset_tag,
                a.asset_name,
                a.ip_address
            FROM   ifix_tickets       t
            JOIN   ifix_users         u  ON u.user_id  = t.requester_id
            LEFT   JOIN ifix_technicians tc ON tc.tech_id  = t.assigned_to
            LEFT   JOIN ifix_users    tu ON tu.user_id  = tc.user_id
            LEFT   JOIN ifix_assets   a  ON a.asset_id  = t.asset_id
            WHERE  (:status       IS NULL OR t.status       = :status)
            AND    (:requester_id IS NULL OR t.requester_id = :requester_id)
            AND    (:assigned_to  IS NULL OR t.assigned_to  = :assigned_to)
            ORDER  BY t.opened_at DESC
        ]',
        p_comments => 'List tickets with optional filters'
    );
    COMMIT;
END;
/

-- POST /tickets  (create new ticket)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets',
        p_method         => 'POST',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            DECLARE
                v_id   NUMBER;
            BEGIN
                INSERT INTO ifix_tickets (
                    problem_desc, asset_id, requester_id, expertise_tag,
                    priority, status, sla_hours
                ) VALUES (
                    :problem_desc,
                    :asset_id,
                    :requester_id,
                    :expertise_tag,
                    NVL(:priority, 'MEDIUM'),
                    'OPEN',
                    CASE NVL(:priority,'MEDIUM')
                        WHEN 'CRITICAL' THEN 2
                        WHEN 'HIGH'     THEN 4
                        WHEN 'MEDIUM'   THEN 8
                        ELSE 24
                    END
                )
                RETURNING ticket_id INTO v_id;

                -- log history
                INSERT INTO ifix_ticket_history (ticket_id, changed_by, old_status, new_status, note)
                VALUES (v_id, :requester_id, NULL, 'OPEN', 'Ticket created');

                :status_code := 201;
                :location    := '/ifixit/v1/tickets/' || v_id;
                COMMIT;
            END;
        ]',
        p_comments => 'Create a new support ticket'
    );
    COMMIT;
END;
/

-- GET /tickets/:id
BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'tickets/:id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets/:id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_collection_item,
        p_source         => q'[
            SELECT
                t.*,
                u.full_name  AS requester_name,
                u.email      AS requester_email,
                u.phone      AS requester_phone,
                tu.full_name AS technician_name,
                a.asset_tag, a.asset_name, a.ip_address, a.brand, a.model
            FROM   ifix_tickets       t
            JOIN   ifix_users         u  ON u.user_id = t.requester_id
            LEFT   JOIN ifix_technicians tc ON tc.tech_id  = t.assigned_to
            LEFT   JOIN ifix_users    tu ON tu.user_id = tc.user_id
            LEFT   JOIN ifix_assets   a  ON a.asset_id = t.asset_id
            WHERE  t.ticket_id = :id
        ]',
        p_comments => 'Get single ticket by ID'
    );
    COMMIT;
END;
/

-- PUT /tickets/:id  (full update)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets/:id',
        p_method         => 'PUT',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            DECLARE
                v_old_status  ifix_tickets.status%TYPE;
            BEGIN
                SELECT status INTO v_old_status FROM ifix_tickets WHERE ticket_id = :id;

                UPDATE ifix_tickets SET
                    problem_desc  = :problem_desc,
                    asset_id      = :asset_id,
                    assigned_to   = :assigned_to,
                    expertise_tag = :expertise_tag,
                    priority      = :priority,
                    status        = :status,
                    resolution    = :resolution
                WHERE ticket_id   = :id;

                IF v_old_status != :status THEN
                    INSERT INTO ifix_ticket_history (ticket_id, changed_by, old_status, new_status, note)
                    VALUES (:id, :changed_by, v_old_status, :status, :history_note);
                END IF;

                :status_code := 200;
                COMMIT;
            END;
        ]',
        p_comments => 'Full update of a ticket'
    );
    COMMIT;
END;
/

-- PATCH /tickets/:id  (status-only update – used by real-time tracker)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets/:id',
        p_method         => 'PATCH',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            DECLARE
                v_old_status  ifix_tickets.status%TYPE;
            BEGIN
                SELECT status INTO v_old_status FROM ifix_tickets WHERE ticket_id = :id FOR UPDATE;

                UPDATE ifix_tickets
                SET    status     = NVL(:status,     status),
                       assigned_to= NVL(:assigned_to, assigned_to),
                       resolution  = NVL(:resolution,  resolution)
                WHERE  ticket_id  = :id;

                IF v_old_status != NVL(:status, v_old_status) THEN
                    INSERT INTO ifix_ticket_history (ticket_id, changed_by, old_status, new_status, note)
                    VALUES (:id, :changed_by, v_old_status, :status, :note);
                END IF;

                :status_code := 200;
                COMMIT;
            END;
        ]',
        p_comments => 'Partial update – status change, assignment'
    );
    COMMIT;
END;
/

-- DELETE /tickets/:id  (soft-delete → status = CANCELLED)
BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'tickets/:id',
        p_method         => 'DELETE',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            BEGIN
                UPDATE ifix_tickets SET status = 'CANCELLED' WHERE ticket_id = :id;
                INSERT INTO ifix_ticket_history (ticket_id, changed_by, old_status, new_status, note)
                SELECT :id, :changed_by, status, 'CANCELLED', 'Ticket cancelled'
                FROM   ifix_tickets WHERE ticket_id = :id;
                :status_code := 204;
                COMMIT;
            END;
        ]',
        p_comments => 'Soft-delete: cancels ticket'
    );
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: APPOINTMENTS
--  GET    /ifixit/v1/appointments
--  GET    /ifixit/v1/appointments/:id
--  POST   /ifixit/v1/appointments
--  PUT    /ifixit/v1/appointments/:id
--  DELETE /ifixit/v1/appointments/:id
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'appointments');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'appointments',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_collection_feed,
        p_source         => q'[
            SELECT
                ap.appt_id,
                ap.appt_date,
                ap.time_slot_from,
                ap.time_slot_to,
                ap.status,
                ap.location_notes,
                t.ticket_no,
                t.problem_desc,
                t.priority,
                u.full_name   AS requester_name,
                tu.full_name  AS technician_name
            FROM   ifix_appointments ap
            JOIN   ifix_tickets      t  ON t.ticket_id = ap.ticket_id
            JOIN   ifix_users        u  ON u.user_id   = ap.requester_id
            LEFT   JOIN ifix_technicians tc ON tc.tech_id = ap.tech_id
            LEFT   JOIN ifix_users   tu ON tu.user_id  = tc.user_id
            WHERE  (:requester_id IS NULL OR ap.requester_id = :requester_id)
            AND    (:appt_date    IS NULL OR ap.appt_date    = TO_DATE(:appt_date,'YYYY-MM-DD'))
            AND    (:status       IS NULL OR ap.status       = :status)
            ORDER  BY ap.appt_date, ap.time_slot_from
        ]',
        p_comments => 'List appointments'
    );

    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'appointments',
        p_method         => 'POST',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            DECLARE
                v_id NUMBER;
            BEGIN
                -- prevent double-booking same technician + slot
                SELECT COUNT(*) INTO v_id
                FROM   ifix_appointments
                WHERE  tech_id        = :tech_id
                AND    appt_date      = TO_DATE(:appt_date,'YYYY-MM-DD')
                AND    time_slot_from = :time_slot_from
                AND    status NOT IN ('CANCELLED','NO_SHOW');

                IF v_id > 0 THEN
                    :status_code := 409;   -- Conflict
                    RETURN;
                END IF;

                INSERT INTO ifix_appointments (
                    ticket_id, tech_id, requester_id,
                    appt_date, time_slot_from, time_slot_to,
                    status, location_notes
                ) VALUES (
                    :ticket_id, :tech_id, :requester_id,
                    TO_DATE(:appt_date,'YYYY-MM-DD'),
                    :time_slot_from, :time_slot_to,
                    'SCHEDULED', :location_notes
                )
                RETURNING appt_id INTO v_id;

                :status_code := 201;
                :location    := '/ifixit/v1/appointments/' || v_id;
                COMMIT;
            END;
        ]',
        p_comments => 'Create appointment (prevents double-booking)'
    );
    COMMIT;
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'appointments/:id');
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'appointments/:id',
        p_method         => 'GET',
        p_source_type    => ORDS.source_type_collection_item,
        p_source         => 'SELECT * FROM ifix_appointments WHERE appt_id = :id',
        p_comments       => 'Get appointment by ID'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'appointments/:id',
        p_method         => 'PUT',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            BEGIN
                UPDATE ifix_appointments SET
                    tech_id        = NVL(:tech_id, tech_id),
                    appt_date      = NVL(TO_DATE(:appt_date,'YYYY-MM-DD'), appt_date),
                    time_slot_from = NVL(:time_slot_from, time_slot_from),
                    time_slot_to   = NVL(:time_slot_to,   time_slot_to),
                    status         = NVL(:status,         status),
                    location_notes = NVL(:location_notes, location_notes)
                WHERE  appt_id = :id;
                :status_code := 200;
                COMMIT;
            END;
        ]',
        p_comments => 'Update appointment'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name    => 'ifixit.v1',
        p_pattern        => 'appointments/:id',
        p_method         => 'DELETE',
        p_source_type    => ORDS.source_type_plsql,
        p_source         => q'[
            BEGIN
                UPDATE ifix_appointments SET status = 'CANCELLED' WHERE appt_id = :id;
                :status_code := 204;
                COMMIT;
            END;
        ]',
        p_comments => 'Cancel appointment (soft delete)'
    );
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: USERS
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'users');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'users', p_method => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source => q'[
            SELECT u.user_id, u.username, u.full_name, u.email, u.phone,
                   u.pabx_ext, u.role, u.is_active,
                   d.dept_name, d.dept_code
            FROM   ifix_users u
            LEFT JOIN ifix_departments d ON d.dept_id = u.dept_id
            WHERE  (:role     IS NULL OR u.role     = :role)
            AND    (:dept_id  IS NULL OR u.dept_id  = :dept_id)
            ORDER  BY u.full_name
        ]',
        p_comments => 'List users'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'users', p_method => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source => q'[
            DECLARE v_id NUMBER;
            BEGIN
                INSERT INTO ifix_users (username, full_name, email, phone, pabx_ext,
                                        role, dept_id, password_hash)
                VALUES (:username, :full_name, :email, :phone, :pabx_ext,
                        NVL(:role,'USER'), :dept_id,
                        STANDARD_HASH(:password,'SHA256'))
                RETURNING user_id INTO v_id;
                :status_code := 201;
                :location := '/ifixit/v1/users/' || v_id;
                COMMIT;
            END;
        ]',
        p_comments => 'Create user'
    );
    COMMIT;
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'users/:id');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'users/:id', p_method => 'GET',
        p_source_type => ORDS.source_type_collection_item,
        p_source => q'[
            SELECT u.*, d.dept_name, d.dept_code
            FROM   ifix_users u LEFT JOIN ifix_departments d ON d.dept_id = u.dept_id
            WHERE  u.user_id = :id
        ]',
        p_comments => 'Get user by ID'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'users/:id', p_method => 'PUT',
        p_source_type => ORDS.source_type_plsql,
        p_source => q'[
            BEGIN
                UPDATE ifix_users SET
                    full_name = NVL(:full_name, full_name),
                    email     = NVL(:email,     email),
                    phone     = NVL(:phone,     phone),
                    pabx_ext  = NVL(:pabx_ext,  pabx_ext),
                    role      = NVL(:role,       role),
                    dept_id   = NVL(:dept_id,    dept_id),
                    is_active = NVL(:is_active,  is_active)
                WHERE user_id = :id;
                :status_code := 200;
                COMMIT;
            END;
        ]',
        p_comments => 'Update user'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'users/:id', p_method => 'DELETE',
        p_source_type => ORDS.source_type_plsql,
        p_source => q'[
            BEGIN
                UPDATE ifix_users SET is_active = 'N' WHERE user_id = :id;
                :status_code := 204;
                COMMIT;
            END;
        ]',
        p_comments => 'Deactivate user (soft delete)'
    );
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: ASSETS
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'assets');
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'assets', p_method => 'GET',
        p_source_type => ORDS.source_type_collection_feed,
        p_source => q'[
            SELECT a.*, d.dept_name,
                   u.full_name AS assigned_to_user
            FROM   ifix_assets a
            LEFT JOIN ifix_departments d ON d.dept_id = a.dept_id
            LEFT JOIN ifix_asset_assignments aa ON aa.asset_id = a.asset_id AND aa.is_current = 'Y'
            LEFT JOIN ifix_users u ON u.user_id = aa.user_id
            WHERE  (:asset_type IS NULL OR a.asset_type = :asset_type)
            AND    (:status     IS NULL OR a.status     = :status)
            ORDER  BY a.asset_tag
        ]',
        p_comments => 'List assets'
    );
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ifixit.v1', p_pattern => 'assets', p_method => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_source => q'[
            DECLARE v_id NUMBER;
            BEGIN
                INSERT INTO ifix_assets (asset_tag, asset_name, brand, model, serial_no,
                                         ip_address, asset_type, purchase_date, warranty_end, dept_id)
                VALUES (:asset_tag, :asset_name, :brand, :model, :serial_no,
                        :ip_address, :asset_type,
                        TO_DATE(:purchase_date,'YYYY-MM-DD'),
                        TO_DATE(:warranty_end, 'YYYY-MM-DD'), :dept_id)
                RETURNING asset_id INTO v_id;
                :status_code := 201;
                :location    := '/ifixit/v1/assets/' || v_id;
                COMMIT;
            END;
        ]',
        p_comments => 'Create asset'
    );
    COMMIT;
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'assets/:id');
    ORDS.DEFINE_HANDLER(p_module_name=>'ifixit.v1',p_pattern=>'assets/:id',p_method=>'GET',
        p_source_type=>ORDS.source_type_collection_item,
        p_source=>'SELECT * FROM ifix_assets WHERE asset_id = :id',
        p_comments=>'Get asset by ID');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'assets/:id', p_method=>'PUT',
        p_source_type=>ORDS.source_type_plsql,
        p_source=>q'[
            BEGIN
                UPDATE ifix_assets SET
                    asset_name  = NVL(:asset_name,  asset_name),
                    brand       = NVL(:brand,        brand),
                    model       = NVL(:model,        model),
                    ip_address  = NVL(:ip_address,   ip_address),
                    status      = NVL(:status,        status),
                    notes       = NVL(:notes,         notes)
                WHERE asset_id  = :id;
                :status_code := 200; COMMIT;
            END;
        ]',
        p_comments=>'Update asset');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'assets/:id', p_method=>'DELETE',
        p_source_type=>ORDS.source_type_plsql,
        p_source=>q'[BEGIN UPDATE ifix_assets SET status='RETIRED' WHERE asset_id=:id; :status_code:=204; COMMIT; END;]',
        p_comments=>'Retire asset');
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: REQUISITIONS
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'requisitions');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'requisitions', p_method=>'GET',
        p_source_type=>ORDS.source_type_collection_feed,
        p_source=>q'[
            SELECT r.*, u.full_name AS requester_name, a.full_name AS approver_name
            FROM   ifix_requisitions r
            JOIN   ifix_users u ON u.user_id = r.requester_id
            LEFT JOIN ifix_users a ON a.user_id = r.approved_by
            WHERE  (:status       IS NULL OR r.status       = :status)
            AND    (:requester_id IS NULL OR r.requester_id = :requester_id)
            ORDER  BY r.created_at DESC
        ]',
        p_comments=>'List requisitions');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'requisitions', p_method=>'POST',
        p_source_type=>ORDS.source_type_plsql,
        p_source=>q'[
            DECLARE v_id NUMBER;
            BEGIN
                INSERT INTO ifix_requisitions (item_desc, requester_id, priority)
                VALUES (:item_desc, :requester_id, NVL(:priority,'MEDIUM'))
                RETURNING req_id INTO v_id;
                :status_code:=201; :location:='/ifixit/v1/requisitions/'||v_id; COMMIT;
            END;
        ]',
        p_comments=>'Create requisition');
    COMMIT;
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'requisitions/:id');
    ORDS.DEFINE_HANDLER(p_module_name=>'ifixit.v1',p_pattern=>'requisitions/:id',p_method=>'GET',
        p_source_type=>ORDS.source_type_collection_item,
        p_source=>'SELECT * FROM ifix_requisitions WHERE req_id=:id', p_comments=>'Get req by ID');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'requisitions/:id', p_method=>'PATCH',
        p_source_type=>ORDS.source_type_plsql,
        p_source=>q'[
            BEGIN
                UPDATE ifix_requisitions SET
                    status        = NVL(:status,       status),
                    approved_by   = NVL(:approved_by,  approved_by),
                    estimated_eta = NVL(TO_DATE(:estimated_eta,'YYYY-MM-DD'), estimated_eta),
                    admin_notes   = NVL(:admin_notes,  admin_notes)
                WHERE req_id = :id;
                :status_code:=200; COMMIT;
            END;
        ]',
        p_comments=>'Approve/reject/update requisition');
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: TICKET HISTORY  (read-only)
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'tickets/:id/history');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'tickets/:id/history', p_method=>'GET',
        p_source_type=>ORDS.source_type_collection_feed,
        p_source=>q'[
            SELECT h.history_id, h.old_status, h.new_status, h.note, h.changed_at,
                   u.full_name AS changed_by_name
            FROM   ifix_ticket_history h
            JOIN   ifix_users u ON u.user_id = h.changed_by
            WHERE  h.ticket_id = :id
            ORDER  BY h.changed_at
        ]',
        p_comments=>'Get ticket audit trail / status timeline');
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: KPI SUMMARY  (admin dashboard)
--  GET  /ifixit/v1/kpi/summary
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'kpi/summary');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'kpi/summary', p_method=>'GET',
        p_source_type=>ORDS.source_type_collection_feed,
        p_source=>q'[
            SELECT
                COUNT(*)                                                      AS total_tickets,
                COUNT(CASE WHEN status = 'OPEN'        THEN 1 END)           AS open_tickets,
                COUNT(CASE WHEN status = 'ASSIGNED'    THEN 1 END)           AS assigned_tickets,
                COUNT(CASE WHEN status = 'IN_PROGRESS' THEN 1 END)           AS in_progress_tickets,
                COUNT(CASE WHEN status = 'RESOLVED'    THEN 1 END)           AS resolved_tickets,
                COUNT(CASE WHEN status = 'CLOSED'      THEN 1 END)           AS closed_tickets,
                ROUND(
                    COUNT(CASE WHEN status IN ('RESOLVED','CLOSED') THEN 1 END)
                    / NULLIF(COUNT(*),0) * 100, 1
                )                                                             AS resolution_pct,
                ROUND(AVG(
                    CASE WHEN resolved_at IS NOT NULL
                    THEN (resolved_at - opened_at) * 24 END
                ), 2)                                                         AS avg_resolve_hours,
                COUNT(CASE WHEN TRUNC(opened_at) = TRUNC(SYSDATE) THEN 1 END) AS tickets_today,
                COUNT(CASE WHEN opened_at >= TRUNC(SYSDATE,'IW')  THEN 1 END) AS tickets_this_week
            FROM ifix_tickets
        ]',
        p_comments=>'KPI summary for admin dashboard');
    COMMIT;
END;
/


-- ══════════════════════════════════════════════════════════════
--  RESOURCE: ASSET ASSIGNMENTS
-- ══════════════════════════════════════════════════════════════

BEGIN
    ORDS.DEFINE_TEMPLATE(p_module_name=>'ifixit.v1', p_pattern=>'assets/:id/assign');
    ORDS.DEFINE_HANDLER(
        p_module_name=>'ifixit.v1', p_pattern=>'assets/:id/assign', p_method=>'POST',
        p_source_type=>ORDS.source_type_plsql,
        p_source=>q'[
            DECLARE v_aid NUMBER;
            BEGIN
                -- close previous assignment
                UPDATE ifix_asset_assignments
                SET    is_current = 'N', returned_date = SYSDATE
                WHERE  asset_id = :id AND is_current = 'Y';

                INSERT INTO ifix_asset_assignments (asset_id, user_id, assigned_by, notes)
                VALUES (:id, :user_id, :assigned_by, :notes)
                RETURNING assignment_id INTO v_aid;

                :status_code := 201;
                :location := '/ifixit/v1/assets/' || :id;
                COMMIT;
            END;
        ]',
        p_comments=>'Assign asset to user');
    COMMIT;
END;
/


-- =============================================================
--  END OF CRUD API DEFINITION
-- =============================================================
--
--  ENDPOINT SUMMARY
--  ─────────────────────────────────────────────────────────
--  GET    /ifixit/v1/tickets                  List tickets
--  POST   /ifixit/v1/tickets                  Create ticket
--  GET    /ifixit/v1/tickets/:id              Get ticket
--  PUT    /ifixit/v1/tickets/:id              Update ticket
--  PATCH  /ifixit/v1/tickets/:id              Change status
--  DELETE /ifixit/v1/tickets/:id              Cancel ticket
--  GET    /ifixit/v1/tickets/:id/history      Audit trail
--
--  GET    /ifixit/v1/appointments             List appointments
--  POST   /ifixit/v1/appointments             Book appointment
--  GET    /ifixit/v1/appointments/:id         Get appointment
--  PUT    /ifixit/v1/appointments/:id         Update appointment
--  DELETE /ifixit/v1/appointments/:id         Cancel appointment
--
--  GET    /ifixit/v1/users                    List users
--  POST   /ifixit/v1/users                    Create user
--  GET    /ifixit/v1/users/:id                Get user
--  PUT    /ifixit/v1/users/:id                Update user
--  DELETE /ifixit/v1/users/:id                Deactivate user
--
--  GET    /ifixit/v1/assets                   List assets
--  POST   /ifixit/v1/assets                   Create asset
--  GET    /ifixit/v1/assets/:id               Get asset
--  PUT    /ifixit/v1/assets/:id               Update asset
--  DELETE /ifixit/v1/assets/:id               Retire asset
--  POST   /ifixit/v1/assets/:id/assign        Assign asset to user
--
--  GET    /ifixit/v1/requisitions             List requisitions
--  POST   /ifixit/v1/requisitions             Create requisition
--  GET    /ifixit/v1/requisitions/:id         Get requisition
--  PATCH  /ifixit/v1/requisitions/:id         Approve/update
--
--  GET    /ifixit/v1/kpi/summary              KPI dashboard data
-- =============================================================
