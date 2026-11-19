-- Reputation Phase 2A - engagement foundation.
--
-- Scope:
--   * reputation.engagements
--   * reputation.engagement_participants
--   * reputation.engagement_subjects
--   * reputation.engagement_events
--   * reputation.v_engagement_current_state
--
-- Events are the only mutable input. Engagement state is derived from the
-- append-only event stream; there are no mutable summary columns.
--
-- Source identity for Vunio orders:
--   engagement_kind = 'vunio_order'
--   source_system   = 'vunio'
--   source_reference = commerce.orders.id::text

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Immutable engagement identity and snapshot.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.engagements (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    engagement_kind text NOT NULL,
    source_system text NOT NULL,
    source_reference text NOT NULL,
    commerce_order_id uuid,
    source_snapshot jsonb NOT NULL,
    source_snapshot_hash bytea NOT NULL,
    source_occurred_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    currency text,
    gross_amount numeric,
    created_by_profile_id uuid,
    CONSTRAINT reputation_engagements_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_engagements_commerce_order_id_fkey
        FOREIGN KEY (commerce_order_id) REFERENCES commerce.orders(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagements_created_by_profile_id_fkey
        FOREIGN KEY (created_by_profile_id) REFERENCES users.profiles(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagements_kind_check
        CHECK (engagement_kind IN (
            'vunio_order',
            'external_transaction',
            'service_engagement'
        )),
    CONSTRAINT reputation_engagements_source_system_check
        CHECK (btrim(source_system) <> '' AND length(source_system) <= 64),
    CONSTRAINT reputation_engagements_source_reference_check
        CHECK (btrim(source_reference) <> '' AND length(source_reference) <= 200),
    CONSTRAINT reputation_engagements_snapshot_check
        CHECK (jsonb_typeof(source_snapshot) = 'object'),
    CONSTRAINT reputation_engagements_snapshot_hash_check
        CHECK (
            octet_length(source_snapshot_hash) = 32
            AND source_snapshot_hash = pg_catalog.sha256(
                convert_to(source_snapshot::text, 'UTF8')
            )
        ),
    CONSTRAINT reputation_engagements_source_identity_check
        CHECK (
            engagement_kind <> 'vunio_order'
            OR commerce_order_id IS NOT NULL
        ),
    CONSTRAINT reputation_engagements_non_order_source_check
        CHECK (
            engagement_kind = 'vunio_order'
            OR commerce_order_id IS NULL
        ),
    CONSTRAINT reputation_engagements_vunio_source_check
        CHECK (
            engagement_kind <> 'vunio_order'
            OR (
                source_system = 'vunio'
                AND source_reference = commerce_order_id::text
            )
        ),
    CONSTRAINT reputation_engagements_vunio_money_check
        CHECK (
            engagement_kind <> 'vunio_order'
            OR (currency IS NOT NULL AND gross_amount IS NOT NULL)
        )
);

ALTER TABLE reputation.engagements OWNER TO postgres;
ALTER TABLE reputation.engagements ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_engagements_source_uidx
    ON reputation.engagements (engagement_kind, source_system, source_reference);

CREATE UNIQUE INDEX reputation_engagements_order_uidx
    ON reputation.engagements (commerce_order_id)
    WHERE commerce_order_id IS NOT NULL;

CREATE INDEX reputation_engagements_occurred_at_idx
    ON reputation.engagements (source_occurred_at DESC);

CREATE INDEX reputation_engagements_recorded_at_idx
    ON reputation.engagements (recorded_at DESC);

COMMENT ON TABLE reputation.engagements IS
    'Immutable Reputation engagement identity. Current state is derived from append-only events.';

-- ---------------------------------------------------------------------------
-- 2. Historical participants.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.engagement_participants (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    engagement_id uuid NOT NULL,
    party_role text NOT NULL,
    profile_id uuid,
    entity_id uuid,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reputation_engagement_participants_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_engagement_participants_engagement_id_fkey
        FOREIGN KEY (engagement_id) REFERENCES reputation.engagements(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_participants_profile_id_fkey
        FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_participants_entity_id_fkey
        FOREIGN KEY (entity_id) REFERENCES core.entities(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_participants_role_check
        CHECK (party_role IN ('buyer', 'seller')),
    CONSTRAINT reputation_engagement_participants_identity_check
        CHECK (profile_id IS NOT NULL OR entity_id IS NOT NULL),
    CONSTRAINT reputation_engagement_participants_buyer_check
        CHECK (party_role <> 'buyer' OR profile_id IS NOT NULL),
    CONSTRAINT reputation_engagement_participants_seller_check
        CHECK (party_role <> 'seller' OR entity_id IS NOT NULL)
);

ALTER TABLE reputation.engagement_participants OWNER TO postgres;
ALTER TABLE reputation.engagement_participants ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_engagement_participants_profile_uidx
    ON reputation.engagement_participants (engagement_id, party_role, profile_id)
    WHERE profile_id IS NOT NULL;

CREATE UNIQUE INDEX reputation_engagement_participants_entity_uidx
    ON reputation.engagement_participants (engagement_id, party_role, entity_id)
    WHERE entity_id IS NOT NULL;

CREATE UNIQUE INDEX reputation_engagement_participants_role_uidx
    ON reputation.engagement_participants (engagement_id, party_role)
    WHERE party_role IN ('buyer', 'seller');

CREATE INDEX reputation_engagement_participants_engagement_idx
    ON reputation.engagement_participants (engagement_id);

COMMENT ON TABLE reputation.engagement_participants IS
    'Immutable historical participant snapshot. Entity membership does not create additional participants.';

-- ---------------------------------------------------------------------------
-- 3. Canonical subject associations.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.engagement_subjects (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    engagement_id uuid NOT NULL,
    subject_id uuid NOT NULL,
    relationship text NOT NULL,
    source_fact jsonb NOT NULL,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT reputation_engagement_subjects_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_engagement_subjects_engagement_id_fkey
        FOREIGN KEY (engagement_id) REFERENCES reputation.engagements(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_subjects_subject_id_fkey
        FOREIGN KEY (subject_id) REFERENCES reputation.subjects(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_subjects_relationship_check
        CHECK (relationship IN ('seller_entity', 'listing', 'product', 'variant')),
    CONSTRAINT reputation_engagement_subjects_source_fact_check
        CHECK (jsonb_typeof(source_fact) = 'object')
);

ALTER TABLE reputation.engagement_subjects OWNER TO postgres;
ALTER TABLE reputation.engagement_subjects ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_engagement_subjects_uidx
    ON reputation.engagement_subjects (engagement_id, subject_id);

CREATE INDEX reputation_engagement_subjects_subject_idx
    ON reputation.engagement_subjects (subject_id);

COMMENT ON TABLE reputation.engagement_subjects IS
    'Immutable evidence-supported subject associations. Does not create subjects.';

-- ---------------------------------------------------------------------------
-- 4. Append-only event stream.
-- ---------------------------------------------------------------------------
CREATE TABLE reputation.engagement_events (
    id uuid NOT NULL DEFAULT public.uuid_generate_v7(),
    engagement_id uuid NOT NULL,
    event_origin text NOT NULL,
    event_type text NOT NULL,
    event_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    event_key text NOT NULL,
    source_namespace text,
    source_event_reference text,
    payload_hash bytea,
    event_version smallint NOT NULL DEFAULT 1,
    actor_profile_id uuid,
    details jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT reputation_engagement_events_pkey PRIMARY KEY (id),
    CONSTRAINT reputation_engagement_events_engagement_id_fkey
        FOREIGN KEY (engagement_id) REFERENCES reputation.engagements(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_events_actor_profile_id_fkey
        FOREIGN KEY (actor_profile_id) REFERENCES users.profiles(id)
        ON DELETE RESTRICT,
    CONSTRAINT reputation_engagement_events_origin_check
        CHECK (event_origin IN ('source', 'reputation')),
    CONSTRAINT reputation_engagement_events_key_check
        CHECK (btrim(event_key) <> ''),
    CONSTRAINT reputation_engagement_events_version_check
        CHECK (event_version = 1),
    CONSTRAINT reputation_engagement_events_details_check
        CHECK (jsonb_typeof(details) = 'object'),
    CONSTRAINT reputation_engagement_events_source_identity_check
        CHECK (
            (event_origin = 'source'
                AND source_namespace IS NOT NULL
                AND btrim(source_namespace) <> ''
                AND source_event_reference IS NOT NULL
                AND btrim(source_event_reference) <> ''
                AND payload_hash IS NOT NULL
                AND octet_length(payload_hash) = 32)
            OR
            (event_origin = 'reputation'
                AND source_namespace IS NULL
                AND source_event_reference IS NULL
                AND payload_hash IS NULL)
        ),
    CONSTRAINT reputation_engagement_events_recorded_integrity_check
        CHECK (
            event_type <> 'engagement_recorded'
            OR (
                details ? 'source_integrity_status'
                AND details->>'source_integrity_status' IN (
                    'consistent',
                    'incomplete',
                    'conflicted'
                )
            )
        ),
    CONSTRAINT reputation_engagement_events_integrity_change_check
        CHECK (
            event_type <> 'source_integrity_changed'
            OR (
                details ? 'source_integrity_status'
                AND details->>'source_integrity_status' IN (
                    'consistent',
                    'incomplete',
                    'conflicted'
                )
            )
        ),
    CONSTRAINT reputation_engagement_events_void_check
        CHECK (
            event_type <> 'engagement_voided'
            OR (
                details ? 'invalidity_code'
                AND btrim(details->>'invalidity_code') <> ''
            )
        ),
    CONSTRAINT reputation_engagement_events_type_check
        CHECK (
            (event_origin = 'source' AND event_type IN (
                'order_delivered',
                'order_cancelled',
                'order_returned',
                'order_refunded',
                'order_partially_refunded',
                'order_reversed',
                'source_synchronized',
                'source_integrity_changed',
                'source_correction_recorded'
            ))
            OR
            (event_origin = 'reputation' AND event_type IN (
                'engagement_recorded',
                'dispute_opened',
                'dispute_dismissed',
                'dispute_upheld',
                'engagement_voided',
                'source_event_conflict'
            ))
        )
);

ALTER TABLE reputation.engagement_events OWNER TO postgres;
ALTER TABLE reputation.engagement_events ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX reputation_engagement_events_key_uidx
    ON reputation.engagement_events (engagement_id, event_key);

CREATE UNIQUE INDEX reputation_engagement_events_source_uidx
    ON reputation.engagement_events (
        engagement_id,
        source_namespace,
        source_event_reference
    )
    WHERE event_origin = 'source';

CREATE UNIQUE INDEX reputation_engagement_events_recorded_uidx
    ON reputation.engagement_events (engagement_id)
    WHERE event_type = 'engagement_recorded';

CREATE UNIQUE INDEX reputation_engagement_events_delivered_uidx
    ON reputation.engagement_events (engagement_id)
    WHERE event_type = 'order_delivered';

CREATE UNIQUE INDEX reputation_engagement_events_void_uidx
    ON reputation.engagement_events (engagement_id)
    WHERE event_type = 'engagement_voided';

CREATE INDEX reputation_engagement_events_effective_time_idx
    ON reputation.engagement_events (engagement_id, event_at, recorded_at, id);

CREATE INDEX reputation_engagement_events_origin_type_idx
    ON reputation.engagement_events (event_origin, event_type);

CREATE INDEX reputation_engagement_events_source_lookup_idx
    ON reputation.engagement_events (
        engagement_id,
        source_namespace,
        source_event_reference
    )
    WHERE event_origin = 'source';

COMMENT ON TABLE reputation.engagement_events IS
    'Append-only source and Reputation workflow event stream. Source identity is namespaced.';

-- ---------------------------------------------------------------------------
-- 5. Derived current state. No mutable summary columns exist.
-- ---------------------------------------------------------------------------
CREATE VIEW reputation.v_engagement_current_state
WITH (security_invoker = true)
AS
WITH ranked_events AS (
    SELECT
        e.id,
        e.engagement_id,
        e.event_origin,
        e.event_type,
        e.event_at,
        e.recorded_at,
        row_number() OVER (
            PARTITION BY e.engagement_id
            ORDER BY e.event_at DESC, e.recorded_at DESC, e.id DESC
        ) AS rn
    FROM reputation.engagement_events AS e
),
last_events AS (
    SELECT engagement_id, id, event_type, event_at, recorded_at
    FROM ranked_events
    WHERE rn = 1
),
void_state AS (
    SELECT engagement_id, true AS is_voided
    FROM reputation.engagement_events
    WHERE event_type = 'engagement_voided'
),
dispute_state AS (
    SELECT DISTINCT ON (engagement_id)
        engagement_id,
        CASE event_type
            WHEN 'dispute_opened' THEN 'disputed'
            ELSE 'active'
        END AS status
    FROM reputation.engagement_events
    WHERE event_type IN (
        'dispute_opened',
        'dispute_dismissed',
        'dispute_upheld'
    )
    ORDER BY engagement_id, event_at DESC, recorded_at DESC, id DESC
),
outcome_state AS (
    SELECT DISTINCT ON (engagement_id)
        engagement_id,
        CASE event_type
            WHEN 'order_delivered' THEN 'completed'
            WHEN 'order_cancelled' THEN 'cancelled'
            WHEN 'order_returned' THEN 'returned'
            WHEN 'order_refunded' THEN 'refunded'
            WHEN 'order_partially_refunded' THEN 'partially_refunded'
            WHEN 'order_reversed' THEN 'reversed'
        END AS source_outcome
    FROM reputation.engagement_events
    WHERE event_type IN (
        'order_delivered',
        'order_cancelled',
        'order_returned',
        'order_refunded',
        'order_partially_refunded',
        'order_reversed'
    )
    ORDER BY engagement_id, event_at DESC, recorded_at DESC, id DESC
),
integrity_change_state AS (
    SELECT DISTINCT ON (engagement_id)
        engagement_id,
        details->>'source_integrity_status' AS source_integrity_status
    FROM reputation.engagement_events
    WHERE event_type = 'source_integrity_changed'
    ORDER BY engagement_id, event_at DESC, recorded_at DESC, id DESC
),
integrity_initial_state AS (
    SELECT
        engagement_id,
        details->>'source_integrity_status' AS source_integrity_status
    FROM reputation.engagement_events
    WHERE event_type = 'engagement_recorded'
)
SELECT
    e.id AS engagement_id,
    CASE
        WHEN vs.is_voided THEN 'voided'
        ELSE COALESCE(ds.status, 'active')
    END AS status,
    COALESCE(os.source_outcome, 'completed') AS source_outcome,
    COALESCE(
        ics.source_integrity_status,
        iis.source_integrity_status
    ) AS source_integrity_status,
    le.id AS last_event_id,
    le.event_at AS last_event_at,
    le.recorded_at AS last_event_recorded_at,
    le.event_type AS last_event_type
FROM reputation.engagements AS e
LEFT JOIN void_state AS vs
    ON vs.engagement_id = e.id
LEFT JOIN dispute_state AS ds
    ON ds.engagement_id = e.id
LEFT JOIN outcome_state AS os
    ON os.engagement_id = e.id
LEFT JOIN integrity_change_state AS ics
    ON ics.engagement_id = e.id
LEFT JOIN integrity_initial_state AS iis
    ON iis.engagement_id = e.id
LEFT JOIN last_events AS le
    ON le.engagement_id = e.id;

ALTER VIEW reputation.v_engagement_current_state OWNER TO postgres;

COMMENT ON VIEW reputation.v_engagement_current_state IS
    'Derived engagement state from append-only events using effective time and deterministic tie-breakers.';

-- ---------------------------------------------------------------------------
-- 6. Append-only and validation triggers.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reputation.reject_history_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
BEGIN
    RAISE EXCEPTION 'Reputation historical rows are append-only: %.%',
        TG_TABLE_SCHEMA, TG_TABLE_NAME
        USING ERRCODE = '42501';
END;
$function$;

ALTER FUNCTION reputation.reject_history_mutation() OWNER TO postgres;

CREATE TRIGGER reputation_engagements_append_only
    BEFORE UPDATE OR DELETE ON reputation.engagements
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_history_mutation();

CREATE TRIGGER reputation_engagement_participants_append_only
    BEFORE UPDATE OR DELETE ON reputation.engagement_participants
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_history_mutation();

CREATE TRIGGER reputation_engagement_subjects_append_only
    BEFORE UPDATE OR DELETE ON reputation.engagement_subjects
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_history_mutation();

CREATE TRIGGER reputation_engagement_events_append_only
    BEFORE UPDATE OR DELETE ON reputation.engagement_events
    FOR EACH ROW
    EXECUTE FUNCTION reputation.reject_history_mutation();

-- Subject validation locks the Phase 1 subject row FOR SHARE. The existing
-- reputation.retire_subject(uuid) uses FOR UPDATE on the same row, so a link
-- and retirement serialize. The lock is held through the inserting transaction.
CREATE OR REPLACE FUNCTION reputation.validate_engagement_subject()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_subject reputation.subjects%ROWTYPE;
BEGIN
    SELECT s.*
      INTO v_subject
      FROM reputation.subjects AS s
     WHERE s.id = NEW.subject_id
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reputation subject not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF v_subject.status <> 'active' THEN
        RAISE EXCEPTION 'Reputation subject is not active'
            USING ERRCODE = '23514';
    END IF;

    IF NOT (
        (NEW.relationship = 'seller_entity'
            AND v_subject.subject_type = 'entity'
            AND v_subject.subject_role = 'seller')
        OR (NEW.relationship = 'listing'
            AND v_subject.subject_type = 'listing'
            AND v_subject.subject_role = 'listing')
        OR (NEW.relationship = 'product'
            AND v_subject.subject_type = 'item'
            AND v_subject.subject_role = 'product')
        OR (NEW.relationship = 'variant'
            AND v_subject.subject_type = 'variant'
            AND v_subject.subject_role = 'product_variant')
    ) THEN
        RAISE EXCEPTION 'Reputation subject type/role does not match relationship %',
            NEW.relationship
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.validate_engagement_subject() OWNER TO postgres;

CREATE TRIGGER reputation_engagement_subjects_validate
    BEFORE INSERT ON reputation.engagement_subjects
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_engagement_subject();

-- Validate the complete effective-time event sequence, including NEW.
-- This rejects invalid historical sequences caused by late-arriving events.
CREATE OR REPLACE FUNCTION reputation.validate_engagement_event()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_engagement_kind text;
    v_existing reputation.engagement_events%ROWTYPE;
    v_rec record;
    v_recorded_count integer := 0;
    v_delivered_count integer := 0;
    v_void_count integer := 0;
    v_delivered_seen boolean := false;
    v_void_seen boolean := false;
    v_full_refund_seen boolean := false;
    v_reversed_seen boolean := false;
    v_open_disputes integer := 0;
    v_integrity_initialized boolean := false;
    v_integrity_status text;
    v_new_integrity_status text;
    v_expected_payload_hash bytea;
BEGIN
    SELECT e.engagement_kind
      INTO v_engagement_kind
      FROM reputation.engagements AS e
     WHERE e.id = NEW.engagement_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engagement not found'
            USING ERRCODE = 'P0002';
    END IF;

    IF NEW.event_origin = 'source' THEN
        v_expected_payload_hash := pg_catalog.sha256(
            convert_to(
                jsonb_build_object(
                    'event_version', NEW.event_version,
                    'event_type', NEW.event_type,
                    'event_at', to_char(
                        NEW.event_at AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                    ),
                    'source_namespace', NEW.source_namespace,
                    'source_event_reference', NEW.source_event_reference,
                    'actor_profile_id', NEW.actor_profile_id::text,
                    'details', NEW.details
                )::text,
                'UTF8'
            )
        );

        IF NEW.payload_hash IS DISTINCT FROM v_expected_payload_hash THEN
            RAISE EXCEPTION 'Source event payload hash does not match payload'
                USING ERRCODE = '23514';
        END IF;
    END IF;

    -- Source identity idempotency. Identical retries are a no-op. Conflicting
    -- duplicates are rejected; the adapter must record source_event_conflict
    -- through reputation.record_source_event_conflict() in a separate
    -- transaction.
    IF NEW.event_origin = 'source' THEN
        SELECT e.*
          INTO v_existing
          FROM reputation.engagement_events AS e
         WHERE e.engagement_id = NEW.engagement_id
           AND e.source_namespace = NEW.source_namespace
           AND e.source_event_reference = NEW.source_event_reference;

        IF FOUND THEN
            IF v_existing.payload_hash IS NOT DISTINCT FROM NEW.payload_hash THEN
                RETURN NULL;
            END IF;

            RAISE EXCEPTION 'Conflicting source event identity: %/%',
                NEW.source_namespace, NEW.source_event_reference
                USING ERRCODE = '23505';
        END IF;
    END IF;

    FOR v_rec IN
        WITH combined AS (
            SELECT
                e.id,
                e.event_origin,
                e.event_type,
                e.event_at,
                e.recorded_at,
                e.details
            FROM reputation.engagement_events AS e
            WHERE e.engagement_id = NEW.engagement_id
            UNION ALL
            SELECT
                NEW.id,
                NEW.event_origin,
                NEW.event_type,
                NEW.event_at,
                NEW.recorded_at,
                NEW.details
        )
        SELECT *
        FROM combined
        ORDER BY event_at, recorded_at, id
    LOOP
        IF v_void_seen THEN
            -- Void is terminal for source-origin and state-changing events.
            -- Reputation-origin conflict audit records are the only exception;
            -- they preserve rejected-source evidence without changing state.
            IF v_rec.event_origin = 'reputation'
               AND v_rec.event_type = 'source_event_conflict' THEN
                CONTINUE;
            END IF;

            RAISE EXCEPTION 'Event % occurs after engagement void', v_rec.event_type
                USING ERRCODE = '23514';
        END IF;

        IF v_rec.event_type = 'engagement_recorded' THEN
            v_recorded_count := v_recorded_count + 1;
            IF v_recorded_count > 1 THEN
                RAISE EXCEPTION 'Multiple engagement_recorded events'
                    USING ERRCODE = '23514';
            END IF;
            v_integrity_status := v_rec.details->>'source_integrity_status';
            IF v_integrity_status NOT IN ('consistent', 'incomplete', 'conflicted') THEN
                RAISE EXCEPTION 'Invalid initial source_integrity_status %', v_integrity_status
                    USING ERRCODE = '23514';
            END IF;
            v_integrity_initialized := true;
        ELSIF v_rec.event_type = 'order_delivered' THEN
            v_delivered_count := v_delivered_count + 1;
            IF v_delivered_count > 1 THEN
                RAISE EXCEPTION 'Multiple order_delivered events'
                    USING ERRCODE = '23514';
            END IF;
            v_delivered_seen := true;
        ELSIF v_rec.event_type IN (
            'order_cancelled',
            'order_returned',
            'order_refunded',
            'order_partially_refunded',
            'order_reversed'
        ) THEN
            IF v_engagement_kind = 'vunio_order' AND NOT v_delivered_seen THEN
                RAISE EXCEPTION 'Source outcome event % precedes delivery',
                    v_rec.event_type
                    USING ERRCODE = '23514';
            END IF;

            IF v_reversed_seen THEN
                RAISE EXCEPTION 'Source outcome event % follows reversal',
                    v_rec.event_type
                    USING ERRCODE = '23514';
            END IF;

            IF v_rec.event_type = 'order_partially_refunded'
               AND v_full_refund_seen THEN
                RAISE EXCEPTION 'Partial refund follows a full refund'
                    USING ERRCODE = '23514';
            END IF;

            IF v_rec.event_type = 'order_refunded' THEN
                v_full_refund_seen := true;
            ELSIF v_rec.event_type = 'order_reversed' THEN
                v_reversed_seen := true;
            END IF;
        ELSIF v_rec.event_type = 'dispute_opened' THEN
            IF v_open_disputes <> 0 THEN
                RAISE EXCEPTION 'Dispute opened while another dispute is open'
                    USING ERRCODE = '23514';
            END IF;
            v_open_disputes := 1;
        ELSIF v_rec.event_type IN ('dispute_dismissed', 'dispute_upheld') THEN
            IF v_open_disputes <> 1 THEN
                RAISE EXCEPTION 'Dispute resolution without an open dispute'
                    USING ERRCODE = '23514';
            END IF;
            v_open_disputes := 0;
        ELSIF v_rec.event_type = 'source_integrity_changed' THEN
            IF NOT v_integrity_initialized THEN
                RAISE EXCEPTION 'Integrity change precedes engagement_recorded'
                    USING ERRCODE = '23514';
            END IF;

            v_new_integrity_status := v_rec.details->>'source_integrity_status';
            IF v_new_integrity_status NOT IN ('consistent', 'incomplete', 'conflicted') THEN
                RAISE EXCEPTION 'Invalid source_integrity_status %', v_new_integrity_status
                    USING ERRCODE = '23514';
            END IF;

            IF NOT (
                v_integrity_status = v_new_integrity_status
                OR (v_integrity_status = 'consistent'
                    AND v_new_integrity_status IN ('incomplete', 'conflicted'))
                OR (v_integrity_status = 'incomplete'
                    AND v_new_integrity_status IN ('consistent', 'conflicted'))
                OR (v_integrity_status = 'conflicted'
                    AND v_new_integrity_status IN ('consistent', 'incomplete'))
            ) THEN
                RAISE EXCEPTION 'Invalid source_integrity_status transition % -> %',
                    v_integrity_status, v_new_integrity_status
                    USING ERRCODE = '23514';
            END IF;

            v_integrity_status := v_new_integrity_status;
        ELSIF v_rec.event_type = 'engagement_voided' THEN
            v_void_count := v_void_count + 1;
            IF v_void_count > 1 THEN
                RAISE EXCEPTION 'Multiple engagement_voided events'
                    USING ERRCODE = '23514';
            END IF;
            IF btrim(coalesce(v_rec.details->>'invalidity_code', '')) = '' THEN
                RAISE EXCEPTION 'engagement_voided requires invalidity_code'
                    USING ERRCODE = '23514';
            END IF;
            v_void_seen := true;
        END IF;
    END LOOP;

    IF v_void_count > 1 THEN
        RAISE EXCEPTION 'Engagement has multiple void events'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$function$;

ALTER FUNCTION reputation.validate_engagement_event() OWNER TO postgres;

CREATE TRIGGER reputation_engagement_events_validate
    BEFORE INSERT ON reputation.engagement_events
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_engagement_event();

-- Initial event completeness is checked at the end of the transaction so an
-- engagement and its initial events can be inserted in one atomic operation.
CREATE OR REPLACE FUNCTION reputation.validate_engagement_events_complete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_engagement_id uuid;
    v_engagement_kind text;
    v_recorded_count integer;
    v_delivered_count integer;
BEGIN
    IF TG_TABLE_NAME = 'engagements' THEN
        v_engagement_id := NEW.id;
    ELSE
        v_engagement_id := NEW.engagement_id;
    END IF;

    SELECT e.engagement_kind
      INTO v_engagement_kind
      FROM reputation.engagements AS e
     WHERE e.id = v_engagement_id;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT
        count(*) FILTER (WHERE event_type = 'engagement_recorded'),
        count(*) FILTER (WHERE event_type = 'order_delivered')
      INTO v_recorded_count, v_delivered_count
      FROM reputation.engagement_events
     WHERE engagement_id = v_engagement_id;

    IF v_recorded_count <> 1 THEN
        RAISE EXCEPTION 'Engagement requires exactly one engagement_recorded event'
            USING ERRCODE = '23514';
    END IF;

    IF v_engagement_kind = 'vunio_order' AND v_delivered_count <> 1 THEN
        RAISE EXCEPTION 'Vunio order engagement requires exactly one order_delivered event'
            USING ERRCODE = '23514';
    END IF;

    RETURN NULL;
END;
$function$;

ALTER FUNCTION reputation.validate_engagement_events_complete() OWNER TO postgres;

CREATE CONSTRAINT TRIGGER reputation_engagements_initial_events_complete
    AFTER INSERT ON reputation.engagements
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_engagement_events_complete();

CREATE CONSTRAINT TRIGGER reputation_engagement_events_complete
    AFTER INSERT ON reputation.engagement_events
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION reputation.validate_engagement_events_complete();

-- Internal audit helper for conflicting source-event identity. It must be
-- called by a future trusted adapter in a separate transaction after the
-- source-event insert is rejected. The validation trigger validates this
-- Reputation-origin event; after void it remains permitted only as an
-- audit-only record that cannot change derived state.
CREATE OR REPLACE FUNCTION reputation.record_source_event_conflict(
    p_engagement_id uuid,
    p_source_namespace text,
    p_source_event_reference text,
    p_attempted_event_type text,
    p_attempted_event_at timestamptz,
    p_attempted_payload_hash bytea,
    p_reason text DEFAULT 'conflicting_duplicate'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path TO 'pg_catalog', 'reputation'
AS $function$
DECLARE
    v_event_key text;
    v_event_id uuid;
BEGIN
    IF p_engagement_id IS NULL
       OR btrim(coalesce(p_source_namespace, '')) = ''
       OR btrim(coalesce(p_source_event_reference, '')) = ''
       OR btrim(coalesce(p_attempted_event_type, '')) = ''
       OR p_attempted_event_at IS NULL
       OR p_attempted_payload_hash IS NULL
       OR octet_length(p_attempted_payload_hash) <> 32 THEN
        RAISE EXCEPTION 'Invalid source event conflict audit arguments'
            USING ERRCODE = '22023';
    END IF;

    PERFORM 1
      FROM reputation.engagements AS e
     WHERE e.id = p_engagement_id
     FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Engagement not found'
            USING ERRCODE = 'P0002';
    END IF;

    v_event_key := 'source-conflict:'
        || p_source_namespace || ':'
        || p_source_event_reference || ':'
        || encode(p_attempted_payload_hash, 'hex');

    INSERT INTO reputation.engagement_events (
        engagement_id,
        event_origin,
        event_type,
        event_at,
        event_key,
        source_namespace,
        source_event_reference,
        payload_hash,
        event_version,
        details
    ) VALUES (
        p_engagement_id,
        'reputation',
        'source_event_conflict',
        clock_timestamp(),
        v_event_key,
        NULL,
        NULL,
        NULL,
        1,
        jsonb_build_object(
            'attempted_source_namespace', p_source_namespace,
            'attempted_source_event_reference', p_source_event_reference,
            'attempted_event_type', p_attempted_event_type,
            'attempted_event_at', to_char(
                p_attempted_event_at AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'attempted_payload_hash', encode(p_attempted_payload_hash, 'hex'),
            'reason', p_reason
        )
    )
    RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$function$;

ALTER FUNCTION reputation.record_source_event_conflict(
    uuid, text, text, text, timestamptz, bytea, text
) OWNER TO postgres;

-- ---------------------------------------------------------------------------
-- 7. Privileges. No browser or service-role table DML. No public view access.
-- ---------------------------------------------------------------------------
REVOKE ALL ON TABLE reputation.engagements
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.engagement_participants
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.engagement_subjects
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.engagement_events
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON TABLE reputation.v_engagement_current_state
    FROM PUBLIC, anon, authenticated, service_role;

REVOKE ALL ON FUNCTION reputation.reject_history_mutation()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_engagement_subject()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_engagement_event()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.validate_engagement_events_complete()
    FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL ON FUNCTION reputation.record_source_event_conflict(
    uuid, text, text, text, timestamptz, bytea, text
)
    FROM PUBLIC, anon, authenticated, service_role;

COMMENT ON FUNCTION reputation.validate_engagement_event() IS
    'Validates the complete effective-time event sequence including the proposed event.';
COMMENT ON FUNCTION reputation.validate_engagement_subject() IS
    'Locks the Phase 1 subject FOR SHARE and requires active exact type/role.';
COMMENT ON FUNCTION reputation.record_source_event_conflict(
    uuid, text, text, text, timestamptz, bytea, text
) IS
    'Internal audit helper for conflicting source event identity. Call after a rejected source event.';

COMMIT;
