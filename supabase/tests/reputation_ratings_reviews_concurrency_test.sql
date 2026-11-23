-- ============================================================================
-- reputation_ratings_reviews_concurrency_test.sql
-- LOCAL-ONLY / DISPOSABLE-DATABASE concurrency test for Phase 3B.
-- Creates committed fixtures because dblink sessions need visibility.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS dblink;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE OR REPLACE FUNCTION auth.uid()
RETURNS uuid LANGUAGE sql STABLE AS $f$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$f$;
CREATE OR REPLACE FUNCTION auth.role()
RETURNS text LANGUAGE sql STABLE AS $f$
    SELECT NULLIF(current_setting('request.jwt.claim.role', true), '')
$f$;
CREATE OR REPLACE FUNCTION core.current_profile_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'users'
AS $f$
    SELECT p.id FROM users.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1
$f$;
CREATE OR REPLACE FUNCTION core.has_permission(p_permission text)
RETURNS boolean LANGUAGE sql STABLE AS $f$ SELECT false $f$;

ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS middle_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS last_name text;
ALTER TABLE users.profiles ADD COLUMN IF NOT EXISTS profile_image text;

INSERT INTO core.countries (id, name, iso_alpha2, iso_alpha3, dialing_code, is_active)
VALUES ('e3000000-0000-4000-8000-000000000001', 'Ratings Concurrency Country', 'SQ', 'SQT', '9986', true);

INSERT INTO users.profiles (id, auth_user_id, first_name, last_name, country_id, is_active, account_status)
VALUES ('e3000000-0000-4000-8000-000000000101', 'e3000000-0000-4000-8000-000000000901',
        'Concurrent Reviewer', 'One', 'e3000000-0000-4000-8000-000000000001', true, 'active');

INSERT INTO core.items (id, name)
VALUES ('e3000000-0000-4000-8000-000000000201', 'Concurrent Product');

DO $fixture$
BEGIN
    PERFORM reputation.register_subject('item', 'product',
        'e3000000-0000-4000-8000-000000000201');
END;
$fixture$;

DO $connect$
DECLARE
    v_conn text;
BEGIN
    SELECT format('host=%s port=%s dbname=%s user=%s',
                  split_part(setting, ',', 1),
                  current_setting('port'),
                  current_database(),
                  current_user)
      INTO v_conn
      FROM pg_settings
     WHERE name = 'unix_socket_directories';
    PERFORM dblink_connect('p3b_a', v_conn);
    PERFORM dblink_connect('p3b_b', v_conn);
END;
$connect$;

-- Concurrent rating: exactly one current rating.
DO $rating_race$
DECLARE
    v_busy integer;
BEGIN
    PERFORM dblink_exec('p3b_a', 'BEGIN');
    PERFORM dblink_exec('p3b_a', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_a', $q$
        SELECT * FROM reputation.submit_rating(
            (SELECT id FROM reputation.subjects
              WHERE subject_type='item' AND subject_role='product'
                AND item_id='e3000000-0000-4000-8000-000000000201'),
            5::smallint, NULL
        )
    $q$);
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('p3b_b', 'BEGIN');
    PERFORM dblink_exec('p3b_b', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_b', $q$
        DO $block$
        BEGIN
            PERFORM reputation.submit_rating(
                (SELECT id FROM reputation.subjects
                  WHERE subject_type='item' AND subject_role='product'
                    AND item_id='e3000000-0000-4000-8000-000000000201'),
                4::smallint, NULL
            );
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;
        $block$
    $q$);
    PERFORM pg_sleep(0.5);
    SELECT dblink_is_busy('p3b_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'concurrent rating did not serialize';
    END IF;

    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(rating_id uuid, outcome text, verification_status text);
    PERFORM dblink_exec('p3b_a', 'COMMIT');
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM dblink_exec('p3b_b', 'COMMIT');

    IF (SELECT count(*) FROM reputation.ratings
         WHERE subject_id = (SELECT id FROM reputation.subjects
                              WHERE subject_type='item' AND subject_role='product'
                                AND item_id='e3000000-0000-4000-8000-000000000201')
           AND reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101') <> 1 THEN
        RAISE EXCEPTION 'concurrent ratings produced duplicate current ratings';
    END IF;
END;
$rating_race$;

-- Concurrent unverified review: exactly one independent review.
DO $review_race$
DECLARE
    v_busy integer;
BEGIN
    PERFORM dblink_exec('p3b_a', 'BEGIN');
    PERFORM dblink_exec('p3b_a', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_a', $q$
        SELECT * FROM reputation.submit_review(
            (SELECT id FROM reputation.subjects
              WHERE subject_type='item' AND subject_role='product'
                AND item_id='e3000000-0000-4000-8000-000000000201'),
            'Concurrent review A', 'A', NULL, NULL, 'display_name'
        )
    $q$);
    PERFORM pg_sleep(0.2);

    PERFORM dblink_exec('p3b_b', 'BEGIN');
    PERFORM dblink_exec('p3b_b', 'SET LOCAL request.jwt.claim.sub = ''e3000000-0000-4000-8000-000000000901''');
    PERFORM dblink_send_query('p3b_b', $q$
        DO $block$
        BEGIN
            PERFORM reputation.submit_review(
                (SELECT id FROM reputation.subjects
                  WHERE subject_type='item' AND subject_role='product'
                    AND item_id='e3000000-0000-4000-8000-000000000201'),
                'Concurrent review B', 'B', NULL, NULL, 'display_name'
            );
        EXCEPTION WHEN unique_violation THEN
            NULL;
        END;
        $block$
    $q$);
    PERFORM pg_sleep(0.5);
    SELECT dblink_is_busy('p3b_b') INTO v_busy;
    IF v_busy <> 1 THEN
        RAISE EXCEPTION 'concurrent review did not serialize';
    END IF;

    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(review_id uuid, outcome text, verification_status text);
    PERFORM * FROM dblink_get_result('p3b_a')
        AS t(review_id uuid, outcome text, verification_status text);
    PERFORM dblink_exec('p3b_a', 'COMMIT');
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM * FROM dblink_get_result('p3b_b') AS t(x text);
    PERFORM dblink_exec('p3b_b', 'COMMIT');

    IF (SELECT count(*) FROM reputation.reviews
         WHERE subject_id = (SELECT id FROM reputation.subjects
                              WHERE subject_type='item' AND subject_role='product'
                                AND item_id='e3000000-0000-4000-8000-000000000201')
           AND reviewer_profile_id = 'e3000000-0000-4000-8000-000000000101'
           AND engagement_id IS NULL) <> 1 THEN
        RAISE EXCEPTION 'concurrent reviews produced duplicate independent reviews';
    END IF;
END;
$review_race$;

SELECT dblink_disconnect('p3b_b');
SELECT dblink_disconnect('p3b_a');
