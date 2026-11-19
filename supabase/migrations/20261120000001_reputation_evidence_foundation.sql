-- Reputation Phase 2B - evidence foundation.
--
-- Scope:
--   * reputation.evidence
--   * reputation.evidence_events
--   * reputation.v_evidence_current_state
--   * canonical Vunio order-delivery evidence capture
--   * evidence conflict, resolution, revocation and supersession audit
--
-- Evidence is immutable and source-backed. Engagement state, subjects,
-- participants and Phase 2A source events are not duplicated here.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Immutable evidence records.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.evidence (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    engagement_id uuid NOT NULL,
    evidence_type text NOT NULL,
    source_system text NOT NULL,
    source_reference text NOT NULL,
    source_version text NOT NULL,
    source_occurred_at timestamptz NOT NULL,
    snapshot_version smallint NOT NULL DEFAULT 1,
    captured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    source_snapshot jsonb NOT NULL,
    source_snapshot_hash bytea NOT NULL,
    capture_method text NOT NULL,
    capture_process text NOT NULL,
    capture_actor_profile_id uuid,
    provenance jsonb NOT NULL DEFAULT '{}'::jsonb,
    supersedes_evidence_id uuid,
    CONSTRAINT reputation_evidence_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_evidence_engagement_id_fkey
        FOREIGN KEY (engagement_id) REFERENCES reputation.engagements(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_evidence_capture_actor_profile_id_fkey
        FOREIGN KEY (capture_actor_profile_id) REFERENCES users.profiles(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_evidence_supersedes_evidence_id_fkey
        FOREIGN KEY (supersedes_evidence_id) REFERENCES reputation.evidence(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_evidence_type_check
        CHECK (evidence_type = 'commerce_order_delivery'),
    CONSTRAINT reputation_evidence_source_system_check
        CHECK (source_system = 'commerce'),
    CONSTRAINT reputation_evidence_source_reference_check
        CHECK (btrim(source_reference) <> '' AND length(source_reference) <= 200),
    CONSTRAINT reputation_evidence_source_version_check
        CHECK (source_version ~ '^delivery:v[1-9][0-9]*$'),
    CONSTRAINT reputation_evidence_snapshot_version_check
        CHECK (snapshot_version = 1),
    CONSTRAINT reputation_evidence_snapshot_check
        CHECK (jsonb_typeof(source_snapshot) = 'object'),
    CONSTRAINT reputation_evidence_snapshot_hash_check
        CHECK (
            octet_length(source_snapshot_hash) = 32
            AND source_snapshot_hash = pg_catalog.sha256(
                convert_to(source_snapshot::text, 'UTF8')
            )
        ),
    CONSTRAINT reputation_evidence_capture_method_check
        CHECK (capture_method IN ('trusted_service', 'trusted_worker', 'admin_backfill')),
    CONSTRAINT reputation_evidence_capture_process_check
        CHECK (btrim(capture_process) <> '' AND length(capture_process) <= 200),
    CONSTRAINT reputation_evidence_provenance_check
        CHECK (jsonb_typeof(provenance) = 'object'),
    CONSTRAINT reputation_evidence_no_self_supersession_check
        CHECK (supersedes_evidence_id IS NULL OR supersedes_evidence_id <> id)
);

ALTER TABLE reputation.evidence OWNER TO postgres;
ALTER TABLE reputation.evidence ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_evidence_source_identity_uidx
    ON reputation.evidence (
        engagement_id,
        source_system,
        source_reference,
        source_version
    );

CREATE UNIQUE INDEX reputation_evidence_supersedes_uidx
    ON reputation.evidence (supersedes_evidence_id)
    WHERE supersedes_evidence_id IS NOT NULL;

CREATE INDEX reputation_evidence_engagement_idx
    ON reputation.evidence (engagement_id);

CREATE INDEX reputation_evidence_source_idx
    ON reputation.evidence (source_system, source_reference);

CREATE INDEX reputation_evidence_occurred_at_idx
    ON reputation.evidence (source_occurred_at DESC);

CREATE INDEX reputation_evidence_recorded_at_idx
    ON reputation.evidence (recorded_at DESC);

COMMENT ON TABLE reputation.evidence IS
    'Immutable source-backed evidence records attached to Reputation engagements.';

COMMENT ON COLUMN reputation.evidence.source_snapshot IS
    'Canonical delivery-specific snapshot; excludes payment, contact and unrelated mutable order fields.';

COMMENT ON COLUMN reputation.evidence.source_snapshot_hash IS
    'SHA-256 of the canonical snapshot text.';

COMMENT ON COLUMN reputation.evidence.supersedes_evidence_id IS
    'Explicit corrected replacement target; supersession is never a rewrite.';

-- ---------------------------------------------------------------------------
-- 2. Append-only evidence lifecycle and audit events.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.evidence_events (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    evidence_id uuid NOT NULL,
    event_type text NOT NULL,
    event_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    event_key text NOT NULL,
    event_version smallint NOT NULL DEFAULT 1,
    actor_profile_id uuid,
    actor_process text NOT NULL,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT reputation_evidence_events_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_evidence_events_evidence_id_fkey
        FOREIGN KEY (evidence_id) REFERENCES reputation.evidence(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_evidence_events_actor_profile_id_fkey
        FOREIGN KEY (actor_profile_id) REFERENCES users.profiles(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_evidence_events_type_check
        CHECK (event_type IN (
            'evidence_recorded',
            'evidence_conflict_detected',
            'evidence_conflict_resolved',
            'evidence_integrity_changed',
            'evidence_revoked',
            'evidence_superseded'
        )),
    CONSTRAINT reputation_evidence_events_key_check
        CHECK (btrim(event_key) <> ''),
    CONSTRAINT reputation_evidence_events_version_check
        CHECK (event_version = 1),
    CONSTRAINT reputation_evidence_events_actor_process_check
        CHECK (btrim(actor_process) <> '' AND length(actor_process) <= 200),
    CONSTRAINT reputation_evidence_events_details_check
        CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT reputation_evidence_events_recorded_check
        CHECK (
            event_type <> 'evidence_recorded'
            OR (
                details ? 'source_integrity_status'
                AND details->>'source_integrity_status' IN ('consistent', 'incomplete')
            )
        ),
    CONSTRAINT reputation_evidence_events_conflict_check
        CHECK (
            event_type <> 'evidence_conflict_detected'
            OR (
                details ? 'attempted_source_system'
                AND btrim(details->>'attempted_source_system') <> ''
                AND details ? 'attempted_source_reference'
                AND btrim(details->>'attempted_source_reference') <> ''
                AND details ? 'attempted_source_version'
                AND btrim(details->>'attempted_source_version') <> ''
                AND details ? 'attempted_source_snapshot'
                AND jsonb_typeof(details->'attempted_source_snapshot') = 'object'
                AND details ? 'attempted_source_snapshot_hash'
                AND details->>'attempted_source_snapshot_hash' ~ '^[0-9a-f]{64}$'
                AND details ? 'reason_code'
                AND btrim(details->>'reason_code') <> ''
            )
        ),
    CONSTRAINT reputation_evidence_events_resolution_check
        CHECK (
            event_type <> 'evidence_conflict_resolved'
            OR (
                details ? 'resolved_conflict_event_id'
                AND btrim(details->>'resolved_conflict_event_id') <> ''
                AND details ? 'resolution_code'
                AND btrim(details->>'resolution_code') <> ''
            )
        ),
    CONSTRAINT reputation_evidence_events_superseded_check
        CHECK (
            event_type <> 'evidence_superseded'
            OR (
                details ? 'superseded_by_evidence_id'
                AND btrim(details->>'superseded_by_evidence_id') <> ''
                AND details ? 'reason_code'
                AND btrim(details->>'reason_code') <> ''
            )
        ),
    CONSTRAINT reputation_evidence_events_revoked_check
        CHECK (
            event_type <> 'evidence_revoked'
            OR (
                details ? 'reason_code'
                AND btrim(details->>'reason_code') <> ''
            )
        ),
    CONSTRAINT reputation_evidence_events_integrity_check
        CHECK (
            event_type <> 'evidence_integrity_changed'
            OR (
                details ? 'source_integrity_status'
                AND details->>'source_integrity_status' IN (
                    'consistent', 'incomplete', 'conflicted'
                )
            )
        )
);

ALTER TABLE reputation.evidence_events OWNER TO postgres;
ALTER TABLE reputation.evidence_events ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_evidence_events_key_uidx
    ON reputation.evidence_events (evidence_id, event_key);

CREATE UNIQUE INDEX reputation_evidence_events_recorded_uidx
    ON reputation.evidence_events (evidence_id)
    WHERE event_type = 'evidence_recorded';

CREATE UNIQUE INDEX reputation_evidence_events_revoked_uidx
    ON reputation.evidence_events (evidence_id)
    WHERE event_type = 'evidence_revoked';

CREATE UNIQUE INDEX reputation_evidence_events_superseded_uidx
    ON reputation.evidence_events (evidence_id)
    WHERE event_type = 'evidence_superseded';

CREATE UNIQUE INDEX reputation_evidence_events_resolved_conflict_uidx
    ON reputation.evidence_events (
        evidence_id,
        (details->>'resolved_conflict_event_id')
    )
    WHERE event_type = 'evidence_conflict_resolved'
      AND details ? 'resolved_conflict_event_id';

CREATE INDEX reputation_evidence_events_effective_time_idx
    ON reputation.evidence_events (evidence_id, event_at, recorded_at, id);

CREATE INDEX reputation_evidence_events_type_idx
    ON reputation.evidence_events (event_type, recorded_at DESC);

COMMENT ON TABLE reputation.evidence_events IS
    'Append-only evidence capture, conflict, resolution, revocation and supersession audit.';

-- ---------------------------------------------------------------------------
-- 3. Derived current evidence state.
-- ---------------------------------------------------------------------------
CREATE VIEW reputation.v_evidence_current_state
WITH (security_invoker = true)
AS
WITH initial_state AS (
    SELECT
        ee.evidence_id,
        ee.details->>'source_integrity_status' AS source_integrity_status
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_recorded'
),
integrity_change_state AS (
    SELECT DISTINCT ON (ee.evidence_id)
        ee.evidence_id,
        ee.details->>'source_integrity_status' AS source_integrity_status
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_integrity_changed'
    ORDER BY ee.evidence_id, ee.event_at DESC, ee.recorded_at DESC, ee.id DESC
),
revocation_state AS (
    SELECT DISTINCT ON (ee.evidence_id)
        ee.evidence_id,
        true AS is_revoked,
        ee.details->>'reason_code' AS revocation_reason_code
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_revoked'
    ORDER BY ee.evidence_id, ee.event_at DESC, ee.recorded_at DESC, ee.id DESC
),
supersession_state AS (
    SELECT DISTINCT ON (ee.evidence_id)
        ee.evidence_id,
        true AS is_superseded,
        (ee.details->>'superseded_by_evidence_id')::uuid AS superseded_by_evidence_id
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_superseded'
    ORDER BY ee.evidence_id, ee.event_at DESC, ee.recorded_at DESC, ee.id DESC
),
conflict_counts AS (
    SELECT
        ee.evidence_id,
        count(*)::integer AS conflict_count
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_conflict_detected'
    GROUP BY ee.evidence_id
),
resolved_conflicts AS (
    SELECT
        ee.evidence_id,
        ee.details->>'resolved_conflict_event_id' AS conflict_event_id
    FROM reputation.evidence_events AS ee
    WHERE ee.event_type = 'evidence_conflict_resolved'
),
unresolved_conflicts AS (
    SELECT
        c.evidence_id,
        count(*)::integer AS unresolved_conflict_count
    FROM reputation.evidence_events AS c
    LEFT JOIN resolved_conflicts AS r
        ON r.evidence_id = c.evidence_id
       AND r.conflict_event_id = c.id::text
    WHERE c.event_type = 'evidence_conflict_detected'
      AND r.conflict_event_id IS NULL
    GROUP BY c.evidence_id
),
last_events AS (
    SELECT DISTINCT ON (ee.evidence_id)
        ee.evidence_id,
        ee.id,
        ee.event_type,
        ee.event_at,
        ee.recorded_at
    FROM reputation.evidence_events AS ee
    ORDER BY ee.evidence_id, ee.event_at DESC, ee.recorded_at DESC, ee.id DESC
)
SELECT
    e.id AS evidence_id,
    e.engagement_id,
    e.evidence_type,
    e.source_system,
    e.source_reference,
    e.source_version,
    e.source_occurred_at,
    e.snapshot_version,
    e.captured_at,
    e.recorded_at,
    e.source_snapshot_hash,
    e.capture_method,
    e.capture_process,
    e.capture_actor_profile_id,
    e.supersedes_evidence_id,
    COALESCE(ics.source_integrity_status, iis.source_integrity_status)
        AS source_integrity_status,
    CASE
        WHEN COALESCE(rs.is_revoked, false) THEN 'revoked'
        WHEN COALESCE(ss.is_superseded, false) THEN 'superseded'
        WHEN COALESCE(uc.unresolved_conflict_count, 0) > 0 THEN 'conflicted'
        ELSE 'active'
    END AS evidence_status,
    COALESCE(cc.conflict_count, 0) AS conflict_count,
    COALESCE(uc.unresolved_conflict_count, 0) AS unresolved_conflict_count,
    COALESCE(es.status, 'active') AS engagement_status,
    COALESCE(es.status = 'disputed', false) AS dispute_suspended,
    COALESCE(es.status = 'voided', false) AS engagement_voided,
    COALESCE(rs.is_revoked, false) AS is_revoked,
    COALESCE(ss.is_superseded, false) AS is_superseded,
    COALESCE(uc.unresolved_conflict_count, 0) > 0 AS is_conflicted,
    rs.revocation_reason_code,
    ss.superseded_by_evidence_id,
    le.id AS last_event_id,
    le.event_type AS last_event_type,
    le.event_at AS last_event_at,
    le.recorded_at AS last_event_recorded_at
FROM reputation.evidence AS e
LEFT JOIN initial_state AS iis
    ON iis.evidence_id = e.id
LEFT JOIN integrity_change_state AS ics
    ON ics.evidence_id = e.id
LEFT JOIN revocation_state AS rs
    ON rs.evidence_id = e.id
LEFT JOIN supersession_state AS ss
    ON ss.evidence_id = e.id
LEFT JOIN conflict_counts AS cc
    ON cc.evidence_id = e.id
LEFT JOIN unresolved_conflicts AS uc
    ON uc.evidence_id = e.id
LEFT JOIN last_events AS le
    ON le.evidence_id = e.id
LEFT JOIN reputation.v_engagement_current_state AS es
    ON es.engagement_id = e.engagement_id;

ALTER VIEW reputation.v_evidence_current_state OWNER TO postgres;

COMMENT ON VIEW reputation.v_evidence_current_state IS
    'Derived evidence state with conflict counts, revocation, supersession and Phase 2A dispute/void flags.';

-- ---------------------------------------------------------------------------
-- 4. Canonical delivery snapshot.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.canonical_order_delivery_snapshot(
    p_order_id uuid,
    p_source_version text DEFAULT 'delivery:v1'
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation', 'commerce'
AS $function$
    SELECT jsonb_build_object(
        'snapshot_schema_version', 1,
        'source_version', p_source_version,
        'evidence_type', 'commerce_order_delivery',
        'source', jsonb_build_object(
            'source_system', 'commerce',
            'source_reference', o.id::text
        ),
        'delivery', jsonb_build_object(
            'status', o.status,
            'delivered_at', to_char(
                o.delivered_at AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'delivery_confirmed_by_profile_id', o.status_changed_by_profile_id
        ),
        'order', jsonb_build_object(
            'id', o.id,
            'order_kind', o.order_kind,
            'order_date', to_char(
                o.order_date AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'buyer_id', o.buyer_id,
            'buyer_entity_id', o.buyer_entity_id,
            'seller_entity_id', o.seller_entity_id,
            'supplier_id', o.supplier_id,
            'entity_id', o.entity_id,
            'listing_id', o.listing_id,
            'currency', o.currency,
            'quantity', o.quantity::text,
            'total_amount', o.total_amount::text,
            'unit_id', o.unit_id
        ),
        'items', COALESCE(
            (
                SELECT jsonb_agg(
                    jsonb_build_object(
                        'id', oi.id,
                        'listing_id', oi.listing_id,
                        'product_id', oi.product_id,
                        'variant_id', oi.variant_id,
                        'stock_id', oi.stock_id,
                        'unit_id', oi.unit_id,
                        'unit', oi.unit,
                        'quantity', oi.quantity::text,
                        'price_per_unit', oi.price_per_unit::text,
                        'total_amount', oi.total_amount::text
                    )
                    ORDER BY oi.id
                )
                FROM commerce.order_items AS oi
                WHERE oi.order_id = o.id
            ),
            '[]'::jsonb
        )
    )
    FROM commerce.orders AS o
    WHERE o.id = p_order_id
$function$;

ALTER FUNCTION reputation.canonical_order_delivery_snapshot(uuid, text)
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.canonical_order_delivery_snapshot(uuid, text) IS
    'Builds the deterministic delivery snapshot for a given source version without payment, contact or unrelated mutable order fields.';

-- ---------------------------------------------------------------------------
-- 5. Append-only and validation triggers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.reject_evidence_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    RAISE EXCEPTION 'Reputation evidence rows are append-only: %.%',
        TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '42501';
END;
$function$;

ALTER FUNCTION reputation.reject_evidence_mutation() OWNER TO postgres;

CREATE TRIGGER reputation_evidence_append_only
    BEFORE UPDATE OR DELETE ON reputation.evidence
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_evidence_mutation();

CREATE TRIGGER reputation_evidence_no_truncate
    BEFORE TRUNCATE ON reputation.evidence
    FOR EACH STATEMENT
    EXECUTE FUNCTION reputation.reject_evidence_mutation();

CREATE TRIGGER reputation_evidence_events_append_only
    BEFORE UPDATE OR DELETE ON reputation.evidence_events
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_evidence_mutation();

CREATE TRIGGER reputation_evidence_events_no_truncate
    BEFORE TRUNCATE ON reputation.evidence_events
    FOR EACH STATEMENT
    EXECUTE FUNCTION reputation.reject_evidence_mutation();

CREATE OR REPLACE FUNCTION reputation.validate_evidence_supersession()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_old reputation.evidence%ROWTYPE;
    v_cycle_count integer;
    v_new_version integer;
    v_old_version integer;
BEGIN
    -- Serialize all evidence inserts for the engagement. Trusted functions
    -- already hold this lock; direct inserts are serialized by this guard.
    PERFORM 1
      FROM reputation.engagements AS e
     WHERE e.id = NEW.engagement_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engagement not found'
            USING ERRCODE = 'P0002';
    END IF;

    -- At most one active delivery evidence version per engagement. A
    -- replacement may only target that active version explicitly.
    IF EXISTS (
        SELECT 1
          FROM reputation.evidence AS e
         WHERE e.engagement_id = NEW.engagement_id
           AND e.evidence_type = NEW.evidence_type
           AND e.source_system = NEW.source_system
           AND e.source_reference = NEW.source_reference
           AND (
               NEW.supersedes_evidence_id IS NULL
               OR e.id <> NEW.supersedes_evidence_id
           )
           AND NOT EXISTS (
               SELECT 1
                 FROM reputation.evidence_events AS ee
                WHERE ee.evidence_id = e.id
                  AND ee.event_type IN ('evidence_revoked', 'evidence_superseded')
           )
    ) THEN
        RAISE EXCEPTION 'An active evidence version already exists; explicit supersession is required'
            USING ERRCODE = '23505';
    END IF;

    IF NEW.supersedes_evidence_id IS NULL THEN
        RETURN NEW;
    END IF;

    SELECT e.*
      INTO v_old
      FROM reputation.evidence AS e
     WHERE e.id = NEW.supersedes_evidence_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Superseded evidence not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_old.id = NEW.id THEN
        RAISE EXCEPTION 'Evidence cannot supersede itself'
            USING ERRCODE = '23514';
    END IF;

    IF v_old.engagement_id <> NEW.engagement_id
       OR v_old.evidence_type <> NEW.evidence_type
       OR v_old.source_system <> NEW.source_system
       OR v_old.source_reference <> NEW.source_reference THEN
        RAISE EXCEPTION 'Supersession must preserve evidence engagement and source identity'
            USING ERRCODE = '23514';
    END IF;

    v_new_version := substring(NEW.source_version from '^delivery:v([0-9]+)$')::integer;
    v_old_version := substring(v_old.source_version from '^delivery:v([0-9]+)$')::integer;

    IF v_new_version IS NULL
       OR v_old_version IS NULL
       OR v_new_version <= v_old_version THEN
        RAISE EXCEPTION 'Replacement source version must be numerically greater than the predecessor'
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM reputation.evidence AS e
         WHERE e.supersedes_evidence_id = v_old.id
           AND e.id <> NEW.id
    ) THEN
        RAISE EXCEPTION 'Evidence is already superseded'
            USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM reputation.evidence_events AS ee
         WHERE ee.evidence_id = v_old.id
           AND ee.event_type IN ('evidence_revoked', 'evidence_superseded')
    ) THEN
        RAISE EXCEPTION 'Revoked or superseded evidence cannot be superseded'
            USING ERRCODE = '23514';
    END IF;

    WITH RECURSIVE ancestors AS (
        SELECT e.id, e.supersedes_evidence_id, 1 AS depth
          FROM reputation.evidence AS e
         WHERE e.id = v_old.id
        UNION ALL
        SELECT e.id, e.supersedes_evidence_id, a.depth + 1
          FROM reputation.evidence AS e
          JOIN ancestors AS a ON e.id = a.supersedes_evidence_id
         WHERE a.depth < 100
    )
    SELECT count(*)
      INTO v_cycle_count
      FROM ancestors
     WHERE id = NEW.id;

    IF v_cycle_count > 0 THEN
        RAISE EXCEPTION 'Evidence supersession cycle detected'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.validate_evidence_supersession() OWNER TO postgres;

CREATE TRIGGER reputation_evidence_validate_supersession
    BEFORE INSERT ON reputation.evidence
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_evidence_supersession();

CREATE OR REPLACE FUNCTION reputation.validate_evidence_snapshot_identity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    IF NEW.source_snapshot#>>'{source,source_system}' IS DISTINCT FROM NEW.source_system
       OR NEW.source_snapshot#>>'{source,source_reference}' IS DISTINCT FROM NEW.source_reference
       OR NEW.source_snapshot->>'source_version' IS DISTINCT FROM NEW.source_version
       OR NEW.source_snapshot->>'evidence_type' IS DISTINCT FROM NEW.evidence_type
       OR NEW.source_snapshot->>'snapshot_schema_version'
          IS DISTINCT FROM NEW.snapshot_version::text THEN
        RAISE EXCEPTION 'Evidence snapshot source identity does not match evidence row'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.validate_evidence_snapshot_identity() OWNER TO postgres;

CREATE TRIGGER reputation_evidence_validate_snapshot_identity
    BEFORE INSERT ON reputation.evidence
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_evidence_snapshot_identity();

CREATE OR REPLACE FUNCTION reputation.validate_evidence_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_conflict_id uuid;
    v_conflict_id_text text;
    v_superseding_id uuid;
    v_superseding_id_text text;
BEGIN
    IF NEW.event_type = 'evidence_conflict_resolved' THEN
        v_conflict_id_text := NULLIF(btrim(COALESCE(NEW.details->>'resolved_conflict_event_id', '')), '');

        IF v_conflict_id_text IS NULL THEN
            RAISE EXCEPTION 'Conflict resolution requires resolved_conflict_event_id'
                USING ERRCODE = '23514';
        END IF;

        BEGIN
            v_conflict_id := v_conflict_id_text::uuid;
        EXCEPTION WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'Invalid resolved_conflict_event_id'
                USING ERRCODE = '22023';
        END;

        IF NOT EXISTS (
            SELECT 1
              FROM reputation.evidence_events AS ee
             WHERE ee.id = v_conflict_id
               AND ee.evidence_id = NEW.evidence_id
               AND ee.event_type = 'evidence_conflict_detected'
        ) THEN
            RAISE EXCEPTION 'Resolution must reference a conflict on the same evidence'
                USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM reputation.evidence_events AS ee
             WHERE ee.evidence_id = NEW.evidence_id
               AND ee.event_type = 'evidence_conflict_resolved'
               AND ee.details->>'resolved_conflict_event_id' = v_conflict_id_text
        ) THEN
            RAISE EXCEPTION 'Conflict has already been resolved'
                USING ERRCODE = '23505';
        END IF;
    ELSIF NEW.event_type = 'evidence_superseded' THEN
        v_superseding_id_text := NULLIF(btrim(COALESCE(NEW.details->>'superseded_by_evidence_id', '')), '');

        IF v_superseding_id_text IS NULL THEN
            RAISE EXCEPTION 'Supersession requires superseded_by_evidence_id'
                USING ERRCODE = '23514';
        END IF;

        BEGIN
            v_superseding_id := v_superseding_id_text::uuid;
        EXCEPTION WHEN invalid_text_representation THEN
            RAISE EXCEPTION 'Invalid superseded_by_evidence_id'
                USING ERRCODE = '22023';
        END;

        IF NOT EXISTS (
            SELECT 1
              FROM reputation.evidence AS e
             WHERE e.id = v_superseding_id
               AND e.supersedes_evidence_id = NEW.evidence_id
        ) THEN
            RAISE EXCEPTION 'Supersession event must reference the replacement evidence'
                USING ERRCODE = '23514';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM reputation.evidence_events AS ee
             WHERE ee.evidence_id = NEW.evidence_id
               AND ee.event_type = 'evidence_superseded'
        ) THEN
            RAISE EXCEPTION 'Evidence is already superseded'
                USING ERRCODE = '23505';
        END IF;
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.validate_evidence_event() OWNER TO postgres;

CREATE TRIGGER reputation_evidence_events_validate
    BEFORE INSERT ON reputation.evidence_events
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_evidence_event();

CREATE OR REPLACE FUNCTION reputation.validate_evidence_events_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_evidence_id uuid;
    v_recorded_count integer;
BEGIN
    IF TG_TABLE_NAME = 'evidence' THEN
        v_evidence_id := NEW.id;
    ELSE
        v_evidence_id := NEW.evidence_id;
    END IF;

    SELECT count(*)
      INTO v_recorded_count
      FROM reputation.evidence_events AS ee
     WHERE ee.evidence_id = v_evidence_id
       AND ee.event_type = 'evidence_recorded';

    IF v_recorded_count <> 1 THEN
        RAISE EXCEPTION 'Evidence requires exactly one evidence_recorded event'
            USING ERRCODE = '23514';
    END IF;

    RETURN NULL;
END;
$function$;

ALTER FUNCTION reputation.validate_evidence_events_complete() OWNER TO postgres;

CREATE CONSTRAINT TRIGGER reputation_evidence_initial_event_complete
    AFTER INSERT ON reputation.evidence
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_evidence_events_complete();

CREATE CONSTRAINT TRIGGER reputation_evidence_events_complete
    AFTER INSERT ON reputation.evidence_events
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_evidence_events_complete();

-- ---------------------------------------------------------------------------
-- 6. Trusted capture, conflict, revocation and supersession functions.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.capture_order_delivery_evidence(
    p_engagement_id uuid,
    p_capture_method text DEFAULT 'trusted_service',
    p_capture_process text DEFAULT 'system.capture_reputation_order_evidence',
    p_capture_actor_profile_id uuid DEFAULT NULL,
    p_provenance jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    evidence_id uuid,
    outcome text,
    evidence_status text,
    conflict_event_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'commerce', 'core', 'users'
AS $function$
DECLARE
    v_engagement reputation.engagements%ROWTYPE;
    v_order commerce.orders%ROWTYPE;
    v_snapshot jsonb;
    v_hash bytea;
    v_existing reputation.evidence%ROWTYPE;
    v_conflict_id uuid;
    v_event_key text;
    v_status text;
    v_item_count integer;
    v_evidence_id uuid;
    v_voided boolean;
BEGIN
    IF p_engagement_id IS NULL THEN
        RAISE EXCEPTION 'engagement_id is required'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_capture_method, '')) NOT IN (
        'trusted_service', 'trusted_worker', 'admin_backfill'
    ) THEN
        RAISE EXCEPTION 'Invalid capture method'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_capture_process, '')) = ''
       OR length(p_capture_process) > 200 THEN
        RAISE EXCEPTION 'capture_process is required and must be at most 200 characters'
            USING ERRCODE = '22023';
    END IF;

    IF p_provenance IS NULL OR jsonb_typeof(p_provenance) <> 'object' THEN
        RAISE EXCEPTION 'provenance must be a JSON object'
            USING ERRCODE = '22023';
    END IF;

    IF p_capture_actor_profile_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
             FROM users.profiles AS p
            WHERE p.id = p_capture_actor_profile_id
              AND p.deleted_at IS NULL
              AND p.is_active = true
              AND p.account_status = 'active'
       ) THEN
        RAISE EXCEPTION 'Capture actor profile is not active'
            USING ERRCODE = '42501';
    END IF;

    SELECT e.*
      INTO v_engagement
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engagement not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_engagement.engagement_kind <> 'vunio_order'
       OR v_engagement.commerce_order_id IS NULL THEN
        RAISE EXCEPTION 'Evidence capture requires a Vunio order engagement'
            USING ERRCODE = '23514';
    END IF;

    SELECT EXISTS (
        SELECT 1
          FROM reputation.engagement_events AS ee
         WHERE ee.engagement_id = p_engagement_id
           AND ee.event_type = 'engagement_voided'
    ) INTO v_voided;

    IF v_voided THEN
        RAISE EXCEPTION 'Evidence cannot be captured after engagement void'
            USING ERRCODE = '23514';
    END IF;

    SELECT o.*
      INTO v_order
      FROM commerce.orders AS o
     WHERE o.id = v_engagement.commerce_order_id
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commerce order not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_order.status IS DISTINCT FROM 'delivered' THEN
        RAISE EXCEPTION 'Commerce order is not delivered'
            USING ERRCODE = '22023';
    END IF;

    IF v_order.delivered_at IS NULL THEN
        RAISE EXCEPTION 'Commerce order has no delivered_at'
            USING ERRCODE = '23514';
    END IF;

    IF v_order.order_kind IS DISTINCT FROM 'stock' THEN
        RAISE EXCEPTION 'Evidence capture requires a stock order'
            USING ERRCODE = '23514';
    END IF;

    IF v_order.buyer_id IS NULL
       OR v_order.buyer_entity_id IS NULL
       OR v_order.seller_entity_id IS NULL
       OR v_order.supplier_id IS NULL THEN
        RAISE EXCEPTION 'Delivered order participant information is incomplete'
            USING ERRCODE = '23514';
    END IF;

    -- Order items are treated as immutable business facts. Lock the existing
    -- item rows so a future mutation cannot race snapshot construction.
    PERFORM 1
      FROM commerce.order_items AS oi
     WHERE oi.order_id = v_order.id
     FOR SHARE;

    SELECT count(*)
      INTO v_item_count
      FROM commerce.order_items AS oi
     WHERE oi.order_id = v_order.id;

    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Delivered order has no items'
            USING ERRCODE = '23514';
    END IF;

    v_snapshot := reputation.canonical_order_delivery_snapshot(v_order.id);

    IF v_snapshot IS NULL THEN
        RAISE EXCEPTION 'Could not build delivery snapshot'
            USING ERRCODE = 'P0001';
    END IF;

    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));

    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'reputation.evidence:'
            || p_engagement_id::text
            || ':commerce:'
            || v_order.id::text
            || ':delivery:v1',
            0
        )
    );

    SELECT e.*
      INTO v_existing
      FROM reputation.evidence AS e
     WHERE e.engagement_id = p_engagement_id
       AND e.source_system = 'commerce'
       AND e.source_reference = v_order.id::text
       AND e.source_version = 'delivery:v1'
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing.source_snapshot_hash IS NOT DISTINCT FROM v_hash THEN
            SELECT v.evidence_status
              INTO v_status
              FROM reputation.v_evidence_current_state AS v
             WHERE v.evidence_id = v_existing.id;

            RETURN QUERY SELECT
                v_existing.id,
                'already_recorded'::text,
                COALESCE(v_status, 'active'),
                NULL::uuid;
            RETURN;
        END IF;

        v_event_key := 'conflict:delivery:v1:'
            || encode(v_hash, 'hex')
            || ':source_snapshot_mismatch';

        SELECT ee.id
          INTO v_conflict_id
          FROM reputation.evidence_events AS ee
         WHERE ee.evidence_id = v_existing.id
           AND ee.event_type = 'evidence_conflict_detected'
           AND ee.event_key = v_event_key;

        IF v_conflict_id IS NULL THEN
            INSERT INTO reputation.evidence_events (
                evidence_id,
                event_type,
                event_at,
                event_key,
                event_version,
                actor_profile_id,
                actor_process,
                details
            ) VALUES (
                v_existing.id,
                'evidence_conflict_detected',
                clock_timestamp(),
                v_event_key,
                1,
                p_capture_actor_profile_id,
                p_capture_process,
                jsonb_build_object(
                    'attempted_source_system', 'commerce',
                    'attempted_source_reference', v_order.id::text,
                    'attempted_source_version', 'delivery:v1',
                    'attempted_source_snapshot', v_snapshot,
                    'attempted_source_snapshot_hash', encode(v_hash, 'hex'),
                    'attempted_order_id', v_order.id,
                    'attempted_delivered_at', to_char(
                        v_order.delivered_at AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                    ),
                    'reason_code', 'source_snapshot_mismatch',
                    'capture_method', p_capture_method,
                    'capture_process', p_capture_process,
                    'provenance', p_provenance,
                    'detected_at', to_char(
                        clock_timestamp() AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                    )
                )
            )
            RETURNING id INTO v_conflict_id;
        END IF;

        SELECT v.evidence_status
          INTO v_status
          FROM reputation.v_evidence_current_state AS v
         WHERE v.evidence_id = v_existing.id;

        RETURN QUERY SELECT
            v_existing.id,
            'conflict_recorded'::text,
            COALESCE(v_status, 'conflicted'),
            v_conflict_id;
        RETURN;
    END IF;

    INSERT INTO reputation.evidence (
        engagement_id,
        evidence_type,
        source_system,
        source_reference,
        source_version,
        source_occurred_at,
        snapshot_version,
        captured_at,
        source_snapshot,
        source_snapshot_hash,
        capture_method,
        capture_process,
        capture_actor_profile_id,
        provenance
    ) VALUES (
        p_engagement_id,
        'commerce_order_delivery',
        'commerce',
        v_order.id::text,
        'delivery:v1',
        v_order.delivered_at,
        1,
        clock_timestamp(),
        v_snapshot,
        v_hash,
        p_capture_method,
        p_capture_process,
        p_capture_actor_profile_id,
        p_provenance
    )
    RETURNING id INTO v_evidence_id;

    INSERT INTO reputation.evidence_events (
        evidence_id,
        event_type,
        event_at,
        event_key,
        event_version,
        actor_profile_id,
        actor_process,
        details
    ) VALUES (
        v_evidence_id,
        'evidence_recorded',
        clock_timestamp(),
        'evidence-recorded',
        1,
        p_capture_actor_profile_id,
        p_capture_process,
        jsonb_build_object(
            'source_integrity_status', 'consistent',
            'snapshot_version', 1,
            'source_occurred_at', to_char(
                v_order.delivered_at AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'source_snapshot_hash', encode(v_hash, 'hex'),
            'capture_method', p_capture_method,
            'capture_process', p_capture_process,
            'provenance', p_provenance
        )
    );

    SELECT v.evidence_status
      INTO v_status
      FROM reputation.v_evidence_current_state AS v
     WHERE v.evidence_id = v_evidence_id;

    RETURN QUERY SELECT
        v_evidence_id,
        'recorded'::text,
        COALESCE(v_status, 'active'),
        NULL::uuid;
END;
$function$;

ALTER FUNCTION reputation.capture_order_delivery_evidence(
    uuid, text, text, uuid, jsonb
) OWNER TO postgres;

COMMENT ON FUNCTION reputation.capture_order_delivery_evidence(
    uuid, text, text, uuid, jsonb
) IS
    'Captures immutable delivery:v1 evidence for a delivered Vunio order engagement.';

CREATE OR REPLACE FUNCTION reputation.capture_order_delivery_evidence_correction(
    p_engagement_id uuid,
    p_supersedes_evidence_id uuid,
    p_source_version text,
    p_capture_method text DEFAULT 'trusted_service',
    p_capture_process text DEFAULT 'system.supersede_reputation_order_evidence',
    p_capture_actor_profile_id uuid DEFAULT NULL,
    p_provenance jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE (
    evidence_id uuid,
    superseded_evidence_id uuid,
    outcome text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'commerce', 'core', 'users'
AS $function$
DECLARE
    v_engagement reputation.engagements%ROWTYPE;
    v_order commerce.orders%ROWTYPE;
    v_old reputation.evidence%ROWTYPE;
    v_existing reputation.evidence%ROWTYPE;
    v_snapshot jsonb;
    v_hash bytea;
    v_evidence_id uuid;
    v_item_count integer;
    v_voided boolean;
    v_new_version integer;
    v_old_version integer;
    v_conflict_id uuid;
    v_event_key text;
BEGIN
    IF p_engagement_id IS NULL OR p_supersedes_evidence_id IS NULL THEN
        RAISE EXCEPTION 'engagement_id and supersedes_evidence_id are required'
            USING ERRCODE = '22023';
    END IF;

    IF p_source_version IS NULL
       OR p_source_version !~ '^delivery:v[1-9][0-9]*$'
       OR p_source_version = 'delivery:v1' THEN
        RAISE EXCEPTION 'Correction requires a new delivery source version'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_capture_method, '')) NOT IN (
        'trusted_service', 'trusted_worker', 'admin_backfill'
    ) THEN
        RAISE EXCEPTION 'Invalid capture method'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_capture_process, '')) = ''
       OR length(p_capture_process) > 200 THEN
        RAISE EXCEPTION 'capture_process is required and must be at most 200 characters'
            USING ERRCODE = '22023';
    END IF;

    IF p_provenance IS NULL OR jsonb_typeof(p_provenance) <> 'object' THEN
        RAISE EXCEPTION 'provenance must be a JSON object'
            USING ERRCODE = '22023';
    END IF;

    IF p_capture_actor_profile_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
             FROM users.profiles AS p
            WHERE p.id = p_capture_actor_profile_id
              AND p.deleted_at IS NULL
              AND p.is_active = true
              AND p.account_status = 'active'
       ) THEN
        RAISE EXCEPTION 'Capture actor profile is not active'
            USING ERRCODE = '42501';
    END IF;

    SELECT e.*
      INTO v_engagement
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engagement not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_engagement.engagement_kind <> 'vunio_order'
       OR v_engagement.commerce_order_id IS NULL THEN
        RAISE EXCEPTION 'Evidence correction requires a Vunio order engagement'
            USING ERRCODE = '23514';
    END IF;

    SELECT EXISTS (
        SELECT 1
          FROM reputation.engagement_events AS ee
         WHERE ee.engagement_id = p_engagement_id
           AND ee.event_type = 'engagement_voided'
    ) INTO v_voided;

    IF v_voided THEN
        RAISE EXCEPTION 'Evidence cannot be corrected after engagement void'
            USING ERRCODE = '23514';
    END IF;

    SELECT e.*
      INTO v_old
      FROM reputation.evidence AS e
     WHERE e.id = p_supersedes_evidence_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Superseded evidence not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_old.engagement_id <> p_engagement_id
       OR v_old.evidence_type <> 'commerce_order_delivery'
       OR v_old.source_system <> 'commerce'
       OR v_old.source_reference <> v_engagement.commerce_order_id::text THEN
        RAISE EXCEPTION 'Superseded evidence does not match the engagement source'
            USING ERRCODE = '23514';
    END IF;

    v_new_version := substring(p_source_version from '^delivery:v([0-9]+)$')::integer;
    v_old_version := substring(v_old.source_version from '^delivery:v([0-9]+)$')::integer;

    IF v_new_version IS NULL
       OR v_old_version IS NULL
       OR v_new_version <= v_old_version THEN
        RAISE EXCEPTION 'Replacement source version must be numerically greater than the predecessor'
            USING ERRCODE = '23514';
    END IF;

    SELECT o.*
      INTO v_order
      FROM commerce.orders AS o
     WHERE o.id = v_engagement.commerce_order_id
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commerce order not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_order.status IS DISTINCT FROM 'delivered' THEN
        RAISE EXCEPTION 'Commerce order is not delivered'
            USING ERRCODE = '22023';
    END IF;

    IF v_order.delivered_at IS NULL THEN
        RAISE EXCEPTION 'Commerce order has no delivered_at'
            USING ERRCODE = '23514';
    END IF;

    IF v_order.order_kind IS DISTINCT FROM 'stock' THEN
        RAISE EXCEPTION 'Evidence correction requires a stock order'
            USING ERRCODE = '23514';
    END IF;

    IF v_order.buyer_id IS NULL
       OR v_order.buyer_entity_id IS NULL
       OR v_order.seller_entity_id IS NULL
       OR v_order.supplier_id IS NULL THEN
        RAISE EXCEPTION 'Delivered order participant information is incomplete'
            USING ERRCODE = '23514';
    END IF;

    -- Order items are treated as immutable business facts. Lock the existing
    -- item rows so a future mutation cannot race snapshot construction.
    PERFORM 1
      FROM commerce.order_items AS oi
     WHERE oi.order_id = v_order.id
     FOR SHARE;

    SELECT count(*)
      INTO v_item_count
      FROM commerce.order_items AS oi
     WHERE oi.order_id = v_order.id;

    IF v_item_count = 0 THEN
        RAISE EXCEPTION 'Delivered order has no items'
            USING ERRCODE = '23514';
    END IF;

    v_snapshot := reputation.canonical_order_delivery_snapshot(
        v_order.id,
        p_source_version
    );

    IF v_snapshot IS NULL THEN
        RAISE EXCEPTION 'Could not build delivery snapshot'
            USING ERRCODE = 'P0001';
    END IF;

    v_hash := pg_catalog.sha256(convert_to(v_snapshot::text, 'UTF8'));

    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'reputation.evidence:'
            || p_engagement_id::text
            || ':commerce:'
            || v_order.id::text
            || ':'
            || p_source_version,
            0
        )
    );

    SELECT e.*
      INTO v_existing
      FROM reputation.evidence AS e
     WHERE e.engagement_id = p_engagement_id
       AND e.source_system = 'commerce'
       AND e.source_reference = v_order.id::text
       AND e.source_version = p_source_version
     FOR UPDATE;

    IF FOUND THEN
        IF v_existing.supersedes_evidence_id = v_old.id THEN
            IF EXISTS (
                SELECT 1
                  FROM reputation.evidence_events AS ee
                 WHERE ee.evidence_id = v_old.id
                   AND ee.event_type = 'evidence_superseded'
                   AND ee.details->>'superseded_by_evidence_id' = v_existing.id::text
            ) THEN
                IF v_existing.source_snapshot_hash IS NOT DISTINCT FROM v_hash THEN
                    RETURN QUERY SELECT
                        v_existing.id,
                        v_old.id,
                        'already_recorded'::text;
                    RETURN;
                END IF;

                v_event_key := 'conflict:correction:'
                    || p_source_version
                    || ':'
                    || encode(v_hash, 'hex')
                    || ':source_snapshot_mismatch';

                SELECT ee.id
                  INTO v_conflict_id
                  FROM reputation.evidence_events AS ee
                 WHERE ee.evidence_id = v_existing.id
                   AND ee.event_type = 'evidence_conflict_detected'
                   AND ee.event_key = v_event_key;

                IF v_conflict_id IS NULL THEN
                    INSERT INTO reputation.evidence_events (
                        evidence_id,
                        event_type,
                        event_at,
                        event_key,
                        event_version,
                        actor_profile_id,
                        actor_process,
                        details
                    ) VALUES (
                        v_existing.id,
                        'evidence_conflict_detected',
                        clock_timestamp(),
                        v_event_key,
                        1,
                        p_capture_actor_profile_id,
                        p_capture_process,
                        jsonb_build_object(
                            'attempted_source_system', 'commerce',
                            'attempted_source_reference', v_order.id::text,
                            'attempted_source_version', p_source_version,
                            'attempted_source_snapshot', v_snapshot,
                            'attempted_source_snapshot_hash', encode(v_hash, 'hex'),
                            'attempted_order_id', v_order.id,
                            'attempted_delivered_at', to_char(
                                v_order.delivered_at AT TIME ZONE 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                            ),
                            'reason_code', 'source_snapshot_mismatch',
                            'capture_method', p_capture_method,
                            'capture_process', p_capture_process,
                            'provenance', p_provenance,
                            'detected_at', to_char(
                                clock_timestamp() AT TIME ZONE 'UTC',
                                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                            )
                        )
                    );
                END IF;

                RETURN QUERY SELECT
                    v_existing.id,
                    v_old.id,
                    'conflict_recorded'::text;
                RETURN;
            END IF;

            RAISE EXCEPTION 'Replacement evidence exists but the supersession link is inconsistent'
                USING ERRCODE = '23514';
        END IF;

        RAISE EXCEPTION 'Replacement evidence identity already exists'
            USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM reputation.evidence_events AS ee
         WHERE ee.evidence_id = v_old.id
           AND ee.event_type IN ('evidence_revoked', 'evidence_superseded')
    ) THEN
        RAISE EXCEPTION 'Revoked or superseded evidence cannot be superseded'
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO reputation.evidence (
        engagement_id,
        evidence_type,
        source_system,
        source_reference,
        source_version,
        source_occurred_at,
        snapshot_version,
        captured_at,
        source_snapshot,
        source_snapshot_hash,
        capture_method,
        capture_process,
        capture_actor_profile_id,
        provenance,
        supersedes_evidence_id
    ) VALUES (
        p_engagement_id,
        'commerce_order_delivery',
        'commerce',
        v_order.id::text,
        p_source_version,
        v_order.delivered_at,
        1,
        clock_timestamp(),
        v_snapshot,
        v_hash,
        p_capture_method,
        p_capture_process,
        p_capture_actor_profile_id,
        p_provenance,
        v_old.id
    )
    RETURNING id INTO v_evidence_id;

    INSERT INTO reputation.evidence_events (
        evidence_id,
        event_type,
        event_at,
        event_key,
        event_version,
        actor_profile_id,
        actor_process,
        details
    ) VALUES (
        v_evidence_id,
        'evidence_recorded',
        clock_timestamp(),
        'evidence-recorded',
        1,
        p_capture_actor_profile_id,
        p_capture_process,
        jsonb_build_object(
            'source_integrity_status', 'consistent',
            'snapshot_version', 1,
            'source_occurred_at', to_char(
                v_order.delivered_at AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'source_snapshot_hash', encode(v_hash, 'hex'),
            'capture_method', p_capture_method,
            'capture_process', p_capture_process,
            'provenance', p_provenance
        )
    );

    INSERT INTO reputation.evidence_events (
        evidence_id,
        event_type,
        event_at,
        event_key,
        event_version,
        actor_profile_id,
        actor_process,
        details
    ) VALUES (
        v_old.id,
        'evidence_superseded',
        clock_timestamp(),
        'superseded:' || v_evidence_id::text,
        1,
        p_capture_actor_profile_id,
        p_capture_process,
        jsonb_build_object(
            'superseded_by_evidence_id', v_evidence_id,
            'reason_code', 'corrected_replacement',
            'replacement_source_version', p_source_version,
            'capture_method', p_capture_method,
            'capture_process', p_capture_process,
            'provenance', p_provenance
        )
    );

    RETURN QUERY SELECT
        v_evidence_id,
        v_old.id,
        'superseded'::text;
END;
$function$;

ALTER FUNCTION reputation.capture_order_delivery_evidence_correction(
    uuid, uuid, text, text, text, uuid, jsonb
) OWNER TO postgres;

COMMENT ON FUNCTION reputation.capture_order_delivery_evidence_correction(
    uuid, uuid, text, text, text, uuid, jsonb
) IS
    'Atomically inserts corrected replacement evidence and marks the original superseded.';

CREATE OR REPLACE FUNCTION reputation.revoke_evidence(
    p_evidence_id uuid,
    p_reason_code text,
    p_reason text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL,
    p_actor_process text DEFAULT 'system.revoke_reputation_evidence'
)
RETURNS TABLE (
    evidence_id uuid,
    outcome text,
    evidence_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_engagement_id uuid;
    v_evidence reputation.evidence%ROWTYPE;
    v_status text;
BEGIN
    IF p_evidence_id IS NULL
       OR btrim(COALESCE(p_reason_code, '')) = ''
       OR length(p_reason_code) > 100
       OR length(COALESCE(p_reason, '')) > 2000 THEN
        RAISE EXCEPTION 'evidence_id and a bounded reason_code are required'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_actor_process, '')) = ''
       OR length(p_actor_process) > 200 THEN
        RAISE EXCEPTION 'actor_process is required and must be at most 200 characters'
            USING ERRCODE = '22023';
    END IF;

    IF p_actor_profile_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
             FROM users.profiles AS p
            WHERE p.id = p_actor_profile_id
              AND p.deleted_at IS NULL
              AND p.is_active = true
              AND p.account_status = 'active'
       ) THEN
        RAISE EXCEPTION 'Revocation actor profile is not active'
            USING ERRCODE = '42501';
    END IF;

    SELECT e.engagement_id
      INTO v_engagement_id
      FROM reputation.evidence AS e
     WHERE e.id = p_evidence_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Evidence not found'
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM 1
      FROM reputation.engagements AS e
     WHERE e.id = v_engagement_id
     FOR UPDATE;

    SELECT e.*
      INTO v_evidence
      FROM reputation.evidence AS e
     WHERE e.id = p_evidence_id
     FOR UPDATE;

    IF EXISTS (
        SELECT 1
          FROM reputation.evidence_events AS ee
         WHERE ee.evidence_id = p_evidence_id
           AND ee.event_type = 'evidence_superseded'
    ) THEN
        RAISE EXCEPTION 'Superseded evidence cannot be revoked'
            USING ERRCODE = '23514';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM reputation.evidence_events AS ee
         WHERE ee.evidence_id = p_evidence_id
           AND ee.event_type = 'evidence_revoked'
    ) THEN
        SELECT v.evidence_status
          INTO v_status
          FROM reputation.v_evidence_current_state AS v
         WHERE v.evidence_id = p_evidence_id;

        RETURN QUERY SELECT
            p_evidence_id,
            'already_revoked'::text,
            COALESCE(v_status, 'revoked');
        RETURN;
    END IF;

    INSERT INTO reputation.evidence_events (
        evidence_id,
        event_type,
        event_at,
        event_key,
        event_version,
        actor_profile_id,
        actor_process,
        details
    ) VALUES (
        p_evidence_id,
        'evidence_revoked',
        clock_timestamp(),
        'revoked',
        1,
        p_actor_profile_id,
        p_actor_process,
        jsonb_build_object(
            'reason_code', p_reason_code,
            'reason', p_reason
        )
    );

    SELECT v.evidence_status
      INTO v_status
      FROM reputation.v_evidence_current_state AS v
     WHERE v.evidence_id = p_evidence_id;

    RETURN QUERY SELECT
        p_evidence_id,
        'revoked'::text,
        COALESCE(v_status, 'revoked');
END;
$function$;

ALTER FUNCTION reputation.revoke_evidence(uuid, text, text, uuid, text)
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.revoke_evidence(uuid, text, text, uuid, text) IS
    'Appends a terminal evidence revocation event without deleting historical data.';

CREATE OR REPLACE FUNCTION reputation.resolve_evidence_conflict(
    p_conflict_event_id uuid,
    p_resolution_code text,
    p_reason text DEFAULT NULL,
    p_actor_profile_id uuid DEFAULT NULL,
    p_actor_process text DEFAULT 'system.resolve_reputation_evidence_conflict'
)
RETURNS TABLE (
    conflict_event_id uuid,
    outcome text,
    evidence_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'core', 'users'
AS $function$
DECLARE
    v_conflict reputation.evidence_events%ROWTYPE;
    v_evidence_id uuid;
    v_engagement_id uuid;
    v_status text;
    v_existing_resolution uuid;
BEGIN
    IF p_conflict_event_id IS NULL
       OR btrim(COALESCE(p_resolution_code, '')) = ''
       OR length(p_resolution_code) > 100
       OR length(COALESCE(p_reason, '')) > 2000 THEN
        RAISE EXCEPTION 'conflict_event_id and a bounded resolution_code are required'
            USING ERRCODE = '22023';
    END IF;

    IF btrim(COALESCE(p_actor_process, '')) = ''
       OR length(p_actor_process) > 200 THEN
        RAISE EXCEPTION 'actor_process is required and must be at most 200 characters'
            USING ERRCODE = '22023';
    END IF;

    IF p_actor_profile_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1
             FROM users.profiles AS p
            WHERE p.id = p_actor_profile_id
              AND p.deleted_at IS NULL
              AND p.is_active = true
              AND p.account_status = 'active'
       ) THEN
        RAISE EXCEPTION 'Resolution actor profile is not active'
            USING ERRCODE = '42501';
    END IF;

    SELECT ee.*
      INTO v_conflict
      FROM reputation.evidence_events AS ee
     WHERE ee.id = p_conflict_event_id
       AND ee.event_type = 'evidence_conflict_detected';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conflict event not found'
            USING ERRCODE = 'P0002';
    END IF;

    v_evidence_id := v_conflict.evidence_id;

    SELECT e.engagement_id
      INTO v_engagement_id
      FROM reputation.evidence AS e
     WHERE e.id = v_evidence_id;

    PERFORM 1
      FROM reputation.engagements AS e
     WHERE e.id = v_engagement_id
     FOR UPDATE;

    PERFORM 1
      FROM reputation.evidence AS e
     WHERE e.id = v_evidence_id
     FOR UPDATE;

    SELECT ee.id
      INTO v_existing_resolution
      FROM reputation.evidence_events AS ee
     WHERE ee.evidence_id = v_evidence_id
       AND ee.event_type = 'evidence_conflict_resolved'
       AND ee.details->>'resolved_conflict_event_id' = p_conflict_event_id::text;

    IF FOUND THEN
        SELECT v.evidence_status
          INTO v_status
          FROM reputation.v_evidence_current_state AS v
         WHERE v.evidence_id = v_evidence_id;

        RETURN QUERY SELECT
            p_conflict_event_id,
            'already_resolved'::text,
            COALESCE(v_status, 'active');
        RETURN;
    END IF;

    INSERT INTO reputation.evidence_events (
        evidence_id,
        event_type,
        event_at,
        event_key,
        event_version,
        actor_profile_id,
        actor_process,
        details
    ) VALUES (
        v_evidence_id,
        'evidence_conflict_resolved',
        clock_timestamp(),
        'conflict-resolved:' || p_conflict_event_id::text,
        1,
        p_actor_profile_id,
        p_actor_process,
        jsonb_build_object(
            'resolved_conflict_event_id', p_conflict_event_id,
            'resolution_code', p_resolution_code,
            'reason', p_reason
        )
    );

    SELECT v.evidence_status
      INTO v_status
      FROM reputation.v_evidence_current_state AS v
     WHERE v.evidence_id = v_evidence_id;

    RETURN QUERY SELECT
        p_conflict_event_id,
        'resolved'::text,
        COALESCE(v_status, 'active');
END;
$function$;

ALTER FUNCTION reputation.resolve_evidence_conflict(uuid, text, text, uuid, text)
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.resolve_evidence_conflict(uuid, text, text, uuid, text) IS
    'Resolves exactly one conflict event while preserving every conflict and resolution in history.';

-- ---------------------------------------------------------------------------
-- 7. Privileges. No browser or service-role table DML. No public view access.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE reputation.evidence
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.evidence_events
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.v_evidence_current_state
    FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION reputation.canonical_order_delivery_snapshot(uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.reject_evidence_mutation()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_evidence_supersession()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_evidence_snapshot_identity()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_evidence_event()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_evidence_events_complete()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.capture_order_delivery_evidence(
    uuid, text, text, uuid, jsonb
)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.capture_order_delivery_evidence_correction(
    uuid, uuid, text, text, text, uuid, jsonb
)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.revoke_evidence(uuid, text, text, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.resolve_evidence_conflict(uuid, text, text, uuid, text)
    FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION reputation.capture_order_delivery_evidence(
    uuid, text, text, uuid, jsonb
) IS
    'Internal trusted delivery evidence capture. Service-role gateways live in system.';
COMMENT ON FUNCTION reputation.revoke_evidence(uuid, text, text, uuid, text) IS
    'Internal trusted evidence revocation. Service-role gateways live in system.';
COMMENT ON FUNCTION reputation.resolve_evidence_conflict(uuid, text, text, uuid, text) IS
    'Internal trusted conflict resolution. Service-role gateways live in system.';

COMMIT;
