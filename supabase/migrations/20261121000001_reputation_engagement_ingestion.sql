-- Reputation Phase 2C-1 - trusted stock-order engagement ingestion.
--
-- Scope:
--   * private trusted implementation only;
--   * creates or repairs a Vunio stock-order engagement;
--   * does not capture evidence, process queues, or modify Commerce.
--
-- The service-role gateway lives in the system schema migration that follows.

BEGIN;

CREATE OR REPLACE FUNCTION reputation.ingest_stock_order_engagement(
    p_order_id uuid
)
RETURNS TABLE (
    engagement_id uuid,
    outcome text,
    reason_code text,
    details jsonb,
    source_event_id uuid,
    participant_count integer,
    subject_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'reputation', 'commerce', 'core', 'users'
AS $function$
DECLARE
    v_existing reputation.engagements%ROWTYPE;
    v_order commerce.orders%ROWTYPE;
    v_snapshot jsonb;
    v_snapshot_hash bytea;
    v_event_hash bytea;
    v_event_ref text;
    v_engagement_id uuid;
    v_return_engagement_id uuid;
    v_source_event_id uuid;
    v_recorded_event_id uuid;
    v_existing_source_event reputation.engagement_events%ROWTYPE;
    v_existing_participant reputation.engagement_participants%ROWTYPE;
    v_subject record;
    v_subject_id uuid;
    v_subject_relationship text;
    v_item_count integer;
    v_participant_count integer;
    v_subject_count integer;
    v_created boolean := false;
    v_repaired boolean := false;
    v_outcome text;
    v_reason text;
    v_details jsonb := '{}'::jsonb;
    v_voided boolean;
BEGIN
    IF p_order_id IS NULL THEN
        RAISE EXCEPTION 'order_id is required'
            USING ERRCODE = '22023';
    END IF;

    -- Serialize all ingestion for the canonical order identity.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(
            'reputation.engagement.ingest:' || p_order_id::text,
            0
        )
    );

    -- Engagement before order, matching Phase 2B engagement-first locking.
    SELECT e.*
      INTO v_existing
      FROM reputation.engagements AS e
     WHERE e.commerce_order_id = p_order_id
     FOR UPDATE;

    v_return_engagement_id := v_existing.id;

    SELECT o.*
      INTO v_order
      FROM commerce.orders AS o
     WHERE o.id = p_order_id
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Commerce order not found'
            USING ERRCODE = 'P0002';
    END IF;

    PERFORM 1
      FROM commerce.order_items AS oi
     WHERE oi.order_id = p_order_id
     FOR SHARE;

    SELECT count(*)
      INTO v_item_count
      FROM commerce.order_items AS oi
     WHERE oi.order_id = p_order_id;

    IF v_order.status IS DISTINCT FROM 'delivered' THEN
        v_outcome := 'ineligible';
        v_reason := 'not_delivered';
        v_details := jsonb_build_object('order_status', v_order.status);
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.order_kind IS DISTINCT FROM 'stock' THEN
        v_outcome := 'ineligible';
        v_reason := 'not_stock_order';
        v_details := jsonb_build_object('order_kind', v_order.order_kind);
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.delivered_at IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_delivered_at';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.buyer_id IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_buyer_profile';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.buyer_entity_id IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_buyer_entity';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.seller_entity_id IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_seller_entity';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.supplier_id IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_supplier';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.listing_id IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_listing';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_order.currency IS NULL
       OR v_order.quantity IS NULL
       OR v_order.total_amount IS NULL
       OR v_order.order_date IS NULL THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_order_facts';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_item_count = 0 THEN
        v_outcome := 'ineligible';
        v_reason := 'missing_order_items';
        RETURN QUERY SELECT
            v_return_engagement_id, v_outcome, v_reason, v_details,
            NULL::uuid, 0, 0;
        RETURN;
    END IF;

    IF v_existing.id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
              FROM reputation.engagement_events AS ee
             WHERE ee.engagement_id = v_existing.id
               AND ee.event_type = 'engagement_voided'
        ) INTO v_voided;

        IF v_voided THEN
            v_outcome := 'ineligible';
            v_reason := 'engagement_voided';
            v_details := jsonb_build_object('engagement_id', v_existing.id);
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;
    END IF;

    v_snapshot := jsonb_build_object(
        'snapshot_schema_version', 1,
        'engagement_kind', 'vunio_order',
        'source', jsonb_build_object(
            'source_system', 'vunio',
            'source_reference', v_order.id::text
        ),
        'order', jsonb_build_object(
            'id', v_order.id,
            'order_kind', v_order.order_kind,
            'order_date', to_char(
                v_order.order_date AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
            ),
            'buyer_id', v_order.buyer_id,
            'buyer_entity_id', v_order.buyer_entity_id,
            'seller_entity_id', v_order.seller_entity_id,
            'supplier_id', v_order.supplier_id,
            'listing_id', v_order.listing_id,
            'currency', v_order.currency,
            'quantity', v_order.quantity::text,
            'total_amount', v_order.total_amount::text,
            'unit_id', v_order.unit_id
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
                        'quantity', oi.quantity::text,
                        'unit', oi.unit,
                        'unit_id', oi.unit_id,
                        'price_per_unit', oi.price_per_unit::text
                    )
                    ORDER BY oi.id
                )
                FROM commerce.order_items AS oi
                WHERE oi.order_id = p_order_id
            ),
            '[]'::jsonb
        )
    );

    v_snapshot_hash := pg_catalog.sha256(
        convert_to(v_snapshot::text, 'UTF8')
    );

    v_event_ref := 'order:' || v_order.id::text || ':delivered';

    v_event_hash := pg_catalog.sha256(
        convert_to(
            jsonb_build_object(
                'event_version', 1,
                'event_type', 'order_delivered',
                'event_at', to_char(
                    v_order.delivered_at AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'
                ),
                'source_namespace', 'vunio',
                'source_event_reference', v_event_ref,
                'actor_profile_id', NULL::text,
                'details', '{}'::jsonb
            )::text,
            'UTF8'
        )
    );

    IF v_existing.id IS NOT NULL THEN
        IF v_existing.engagement_kind <> 'vunio_order'
           OR v_existing.source_system <> 'vunio'
           OR v_existing.source_reference <> v_order.id::text
           OR v_existing.commerce_order_id IS DISTINCT FROM v_order.id THEN
            v_outcome := 'source_conflict';
            v_reason := 'engagement_identity_conflict';
            v_details := jsonb_build_object(
                'existing_kind', v_existing.engagement_kind,
                'existing_source_system', v_existing.source_system,
                'existing_source_reference', v_existing.source_reference
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        IF v_existing.source_snapshot_hash IS DISTINCT FROM v_snapshot_hash THEN
            v_outcome := 'source_conflict';
            v_reason := 'engagement_snapshot_conflict';
            v_details := jsonb_build_object(
                'existing_snapshot_hash', encode(v_existing.source_snapshot_hash, 'hex'),
                'authoritative_snapshot_hash', encode(v_snapshot_hash, 'hex')
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        IF v_existing.currency IS DISTINCT FROM v_order.currency
           OR v_existing.gross_amount IS DISTINCT FROM v_order.total_amount THEN
            v_outcome := 'source_conflict';
            v_reason := 'engagement_money_conflict';
            v_details := jsonb_build_object(
                'existing_currency', v_existing.currency,
                'authoritative_currency', v_order.currency,
                'existing_gross_amount', v_existing.gross_amount,
                'authoritative_gross_amount', v_order.total_amount
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        SELECT * INTO v_existing_participant
          FROM reputation.engagement_participants AS ep
         WHERE ep.engagement_id = v_existing.id
           AND ep.party_role = 'buyer';

        IF FOUND
           AND (
               v_existing_participant.profile_id IS DISTINCT FROM v_order.buyer_id
               OR v_existing_participant.entity_id IS DISTINCT FROM v_order.buyer_entity_id
           ) THEN
            v_outcome := 'source_conflict';
            v_reason := 'buyer_participant_conflict';
            v_details := jsonb_build_object(
                'existing_profile_id', v_existing_participant.profile_id,
                'authoritative_profile_id', v_order.buyer_id,
                'existing_entity_id', v_existing_participant.entity_id,
                'authoritative_entity_id', v_order.buyer_entity_id
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        SELECT * INTO v_existing_participant
          FROM reputation.engagement_participants AS ep
         WHERE ep.engagement_id = v_existing.id
           AND ep.party_role = 'seller';

        IF FOUND
           AND v_existing_participant.entity_id IS DISTINCT FROM v_order.seller_entity_id THEN
            v_outcome := 'source_conflict';
            v_reason := 'seller_participant_conflict';
            v_details := jsonb_build_object(
                'existing_entity_id', v_existing_participant.entity_id,
                'authoritative_entity_id', v_order.seller_entity_id
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        IF EXISTS (
            SELECT 1
              FROM reputation.engagement_subjects AS es
              JOIN reputation.subjects AS s ON s.id = es.subject_id
             WHERE es.engagement_id = v_existing.id
               AND NOT (
                   (
                       s.subject_type = 'entity'
                       AND s.subject_role = 'seller'
                       AND s.entity_id = v_order.seller_entity_id
                       AND es.relationship = 'seller_entity'
                   )
                   OR (
                       s.subject_type = 'listing'
                       AND s.subject_role = 'listing'
                       AND s.listing_id = v_order.listing_id
                       AND es.relationship = 'listing'
                   )
                   OR (
                       s.subject_type = 'item'
                       AND s.subject_role = 'product'
                       AND es.relationship = 'product'
                       AND EXISTS (
                           SELECT 1
                             FROM commerce.order_items AS oi
                            WHERE oi.order_id = p_order_id
                              AND oi.product_id = s.item_id
                       )
                   )
                   OR (
                       s.subject_type = 'variant'
                       AND s.subject_role = 'product_variant'
                       AND es.relationship = 'variant'
                       AND EXISTS (
                           SELECT 1
                             FROM commerce.order_items AS oi
                            WHERE oi.order_id = p_order_id
                              AND oi.variant_id = s.variant_id
                       )
                   )
               )
        ) THEN
            v_outcome := 'source_conflict';
            v_reason := 'subject_association_conflict';
            v_details := jsonb_build_object('engagement_id', v_existing.id);
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;

        SELECT ee.*
          INTO v_existing_source_event
          FROM reputation.engagement_events AS ee
         WHERE ee.engagement_id = v_existing.id
           AND ee.event_type = 'order_delivered';

        IF FOUND THEN
            IF v_existing_source_event.source_namespace IS DISTINCT FROM 'vunio'
               OR v_existing_source_event.source_event_reference IS DISTINCT FROM v_event_ref
               OR v_existing_source_event.event_at IS DISTINCT FROM v_order.delivered_at
               OR v_existing_source_event.payload_hash IS DISTINCT FROM v_event_hash THEN
                IF NOT EXISTS (
                    SELECT 1
                      FROM reputation.engagement_events AS ee
                     WHERE ee.engagement_id = v_existing.id
                       AND ee.event_type = 'source_event_conflict'
                       AND ee.event_key = 'source-conflict:vunio:'
                           || v_event_ref || ':'
                           || encode(v_event_hash, 'hex')
                ) THEN
                    PERFORM reputation.record_source_event_conflict(
                        v_existing.id,
                        'vunio',
                        v_event_ref,
                        'order_delivered',
                        v_order.delivered_at,
                        v_event_hash,
                        'source_event_identity_conflict'
                    );
                END IF;

                v_outcome := 'source_conflict';
                v_reason := 'source_event_conflict';
                v_details := jsonb_build_object(
                    'existing_event_at', v_existing_source_event.event_at,
                    'authoritative_event_at', v_order.delivered_at,
                    'existing_payload_hash', encode(v_existing_source_event.payload_hash, 'hex'),
                    'authoritative_payload_hash', encode(v_event_hash, 'hex')
                );
                RETURN QUERY SELECT
                    v_existing.id, v_outcome, v_reason, v_details,
                    v_existing_source_event.id, 0, 0;
                RETURN;
            END IF;
        END IF;

        IF v_existing.source_occurred_at IS DISTINCT FROM v_order.delivered_at THEN
            v_outcome := 'source_conflict';
            v_reason := 'source_occurred_at_conflict';
            v_details := jsonb_build_object(
                'existing_source_occurred_at', v_existing.source_occurred_at,
                'authoritative_delivered_at', v_order.delivered_at
            );
            RETURN QUERY SELECT
                v_existing.id, v_outcome, v_reason, v_details,
                NULL::uuid, 0, 0;
            RETURN;
        END IF;
    END IF;

    BEGIN
        IF v_existing.id IS NULL THEN
            INSERT INTO reputation.engagements (
                engagement_kind,
                source_system,
                source_reference,
                commerce_order_id,
                source_snapshot,
                source_snapshot_hash,
                source_occurred_at,
                currency,
                gross_amount
            ) VALUES (
                'vunio_order',
                'vunio',
                v_order.id::text,
                v_order.id,
                v_snapshot,
                v_snapshot_hash,
                v_order.delivered_at,
                v_order.currency,
                v_order.total_amount
            )
            RETURNING id INTO v_engagement_id;

            v_created := true;
        ELSE
            v_engagement_id := v_existing.id;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM reputation.engagement_participants AS ep
             WHERE ep.engagement_id = v_engagement_id
               AND ep.party_role = 'buyer'
        ) THEN
            INSERT INTO reputation.engagement_participants (
                engagement_id,
                party_role,
                profile_id,
                entity_id
            ) VALUES (
                v_engagement_id,
                'buyer',
                v_order.buyer_id,
                v_order.buyer_entity_id
            );
            v_repaired := true;
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM reputation.engagement_participants AS ep
             WHERE ep.engagement_id = v_engagement_id
               AND ep.party_role = 'seller'
        ) THEN
            INSERT INTO reputation.engagement_participants (
                engagement_id,
                party_role,
                entity_id
            ) VALUES (
                v_engagement_id,
                'seller',
                v_order.seller_entity_id
            );
            v_repaired := true;
        END IF;

        FOR v_subject IN
            WITH expected AS (
                SELECT
                    1 AS sort_order,
                    'entity'::text AS subject_type,
                    'seller'::text AS subject_role,
                    v_order.seller_entity_id AS identity_id,
                    'seller_entity'::text AS relationship,
                    jsonb_build_object(
                        'seller_entity_id', v_order.seller_entity_id
                    ) AS source_fact
                UNION ALL
                SELECT
                    2,
                    'listing',
                    'listing',
                    v_order.listing_id,
                    'listing',
                    jsonb_build_object('listing_id', v_order.listing_id)
                UNION ALL
                SELECT
                    3,
                    'item',
                    'product',
                    oi.product_id,
                    'product',
                    jsonb_build_object('item_id', oi.product_id)
                  FROM commerce.order_items AS oi
                 WHERE oi.order_id = p_order_id
                   AND oi.product_id IS NOT NULL
                UNION ALL
                SELECT
                    4,
                    'variant',
                    'product_variant',
                    oi.variant_id,
                    'variant',
                    jsonb_build_object('variant_id', oi.variant_id)
                  FROM commerce.order_items AS oi
                 WHERE oi.order_id = p_order_id
                   AND oi.variant_id IS NOT NULL
            )
            SELECT DISTINCT ON (subject_type, subject_role, identity_id)
                subject_type,
                subject_role,
                identity_id,
                relationship,
                source_fact
              FROM expected
             WHERE identity_id IS NOT NULL
             ORDER BY subject_type, subject_role, identity_id
        LOOP
            SELECT s.id
              INTO v_subject_id
              FROM reputation.subjects AS s
             WHERE s.subject_type = v_subject.subject_type
               AND s.subject_role = v_subject.subject_role
               AND (
                   (v_subject.subject_type = 'entity'
                       AND s.entity_id = v_subject.identity_id)
                   OR (v_subject.subject_type = 'listing'
                       AND s.listing_id = v_subject.identity_id)
                   OR (v_subject.subject_type = 'item'
                       AND s.item_id = v_subject.identity_id)
                   OR (v_subject.subject_type = 'variant'
                       AND s.variant_id = v_subject.identity_id)
               );

            IF v_subject_id IS NOT NULL THEN
                SELECT es.relationship
                  INTO v_subject_relationship
                  FROM reputation.engagement_subjects AS es
                 WHERE es.engagement_id = v_engagement_id
                   AND es.subject_id = v_subject_id;

                IF FOUND THEN
                    IF v_subject_relationship IS DISTINCT FROM v_subject.relationship THEN
                        v_outcome := 'source_conflict';
                        v_reason := 'subject_relationship_conflict';
                        v_details := jsonb_build_object(
                            'subject_id', v_subject_id,
                            'existing_relationship', v_subject_relationship,
                            'authoritative_relationship', v_subject.relationship
                        );
                        RAISE EXCEPTION USING ERRCODE = 'P2C01';
                    END IF;
                ELSE
                    v_subject_id := NULL;
                END IF;
            END IF;

            IF v_subject_id IS NULL THEN
                BEGIN
                    v_subject_id := reputation.register_subject(
                        v_subject.subject_type,
                        v_subject.subject_role,
                        v_subject.identity_id
                    );
                EXCEPTION
                    WHEN SQLSTATE 'P0001' THEN
                        v_outcome := 'ineligible';
                        v_reason := 'subject_retired';
                        v_details := jsonb_build_object(
                            'subject_type', v_subject.subject_type,
                            'subject_role', v_subject.subject_role,
                            'identity_id', v_subject.identity_id
                        );
                        RAISE EXCEPTION USING ERRCODE = 'P2C01';
                    WHEN SQLSTATE 'P0002' THEN
                        v_outcome := 'ineligible';
                        v_reason := 'subject_missing';
                        v_details := jsonb_build_object(
                            'subject_type', v_subject.subject_type,
                            'subject_role', v_subject.subject_role,
                            'identity_id', v_subject.identity_id
                        );
                        RAISE EXCEPTION USING ERRCODE = 'P2C01';
                    WHEN SQLSTATE '22023' THEN
                        v_outcome := 'ineligible';
                        v_reason := 'subject_invalid';
                        v_details := jsonb_build_object(
                            'subject_type', v_subject.subject_type,
                            'subject_role', v_subject.subject_role,
                            'identity_id', v_subject.identity_id
                        );
                        RAISE EXCEPTION USING ERRCODE = 'P2C01';
                END;

                INSERT INTO reputation.engagement_subjects (
                    engagement_id,
                    subject_id,
                    relationship,
                    source_fact
                ) VALUES (
                    v_engagement_id,
                    v_subject_id,
                    v_subject.relationship,
                    v_subject.source_fact
                );

                v_repaired := true;
            END IF;
        END LOOP;

        SELECT ee.id
          INTO v_recorded_event_id
          FROM reputation.engagement_events AS ee
         WHERE ee.engagement_id = v_engagement_id
           AND ee.event_type = 'engagement_recorded';

        IF v_recorded_event_id IS NULL THEN
            INSERT INTO reputation.engagement_events (
                engagement_id,
                event_origin,
                event_type,
                event_at,
                event_key,
                details
            ) VALUES (
                v_engagement_id,
                'reputation',
                'engagement_recorded',
                clock_timestamp(),
                'engagement-recorded',
                '{"source_integrity_status":"consistent"}'::jsonb
            );
            v_repaired := true;
        END IF;

        SELECT ee.*
          INTO v_existing_source_event
          FROM reputation.engagement_events AS ee
         WHERE ee.engagement_id = v_engagement_id
           AND ee.event_type = 'order_delivered';

        IF FOUND THEN
            v_source_event_id := v_existing_source_event.id;
        ELSE
            INSERT INTO reputation.engagement_events (
                engagement_id,
                event_origin,
                event_type,
                event_at,
                event_key,
                source_namespace,
                source_event_reference,
                payload_hash,
                details
            ) VALUES (
                v_engagement_id,
                'source',
                'order_delivered',
                v_order.delivered_at,
                'vunio:delivered',
                'vunio',
                v_event_ref,
                v_event_hash,
                '{}'::jsonb
            )
            RETURNING id INTO v_source_event_id;

            v_repaired := true;
        END IF;
    EXCEPTION
        WHEN SQLSTATE 'P2C01' THEN
            RETURN QUERY SELECT
                v_return_engagement_id,
                v_outcome,
                v_reason,
                v_details,
                NULL::uuid,
                0,
                0;
            RETURN;
    END;

    IF v_created THEN
        v_outcome := 'created';
    ELSIF v_repaired THEN
        v_outcome := 'repaired';
    ELSE
        v_outcome := 'already_ingested';
    END IF;

    v_reason := NULL;
    v_details := '{}'::jsonb;

    SELECT count(*)
      INTO v_participant_count
      FROM reputation.engagement_participants AS ep
     WHERE ep.engagement_id = v_engagement_id;

    SELECT count(*)
      INTO v_subject_count
      FROM reputation.engagement_subjects AS es
     WHERE es.engagement_id = v_engagement_id;

    RETURN QUERY SELECT
        v_engagement_id,
        v_outcome,
        v_reason,
        v_details,
        v_source_event_id,
        v_participant_count,
        v_subject_count;
END;
$function$;

ALTER FUNCTION reputation.ingest_stock_order_engagement(uuid)
    OWNER TO postgres;

COMMENT ON FUNCTION reputation.ingest_stock_order_engagement(uuid) IS
    'Private trusted ingestion of a Vunio stock-order Reputation engagement from authoritative Commerce data.';

REVOKE ALL ON FUNCTION reputation.ingest_stock_order_engagement(uuid)
    FROM PUBLIC, anon, authenticated, service_role;

COMMIT;
