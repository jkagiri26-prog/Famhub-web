-- ============================================================================
-- Assistant chat history: persistent advisor conversations + messages
-- ============================================================================
--
-- WHAT THIS MIGRATION DOES
--   * Creates assistant.conversations and assistant.messages for the shell
--     AI advisor's persistent chat history.
--   * Enforces authenticated ownership in the schema itself:
--       - user_id DEFAULT core.auth_user_id()  (the server derives the owner)
--       - CHECK (user_id = core.auth_user_id())  (a client-supplied owner id
--         for anyone else is rejected outright)
--       - RLS USING/WITH CHECK on every operation
--       - a composite FK ties each message to a conversation the SAME owner
--         holds, so a message can never be attached to someone else's thread.
--   * Grants DML only to authenticated (+ service_role for operations).
--     anon and PUBLIC get nothing, not even schema USAGE.
--   * Bumps last_message_at/updated_at on the conversation when a message
--     lands, via an invoker-rights trigger (RLS still applies to the caller).
--
-- WHAT IT DELIBERATELY DOES NOT DO
--   * It does NOT reuse agri_connect.conversations/messages. That is the
--     social messaging core: type CHECKs, participant bootstrap triggers and
--     security-definer guards built for direct/group/community threads.
--     Bending it for private one-to-one advisor threads would mutate the
--     messaging contract — not "reusing an existing suitable table".
--   * It does NOT store workspace, entity, module or route IDs. Module,
--     route and workspace LABELS ride in conversations.context as free
--     metadata only; a conversation is never locked to one module/entity.
--   * It does NOT apply itself to any environment. Apply deliberately.
--   * It does NOT touch any existing table, policy or function.
--
-- Requires the "assistant" schema to be exposed by PostgREST (supabase
-- config.toml [api] schemas, and the equivalent deployed configuration).
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS "assistant";

REVOKE ALL ON SCHEMA "assistant" FROM PUBLIC;
REVOKE ALL ON SCHEMA "assistant" FROM anon;
GRANT USAGE ON SCHEMA "assistant" TO authenticated;
GRANT USAGE ON SCHEMA "assistant" TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- assistant.conversations
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "assistant"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" DEFAULT "core"."auth_user_id"() NOT NULL,
    "title" "text" DEFAULT 'New conversation'::"text" NOT NULL,
    "context" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "last_message_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "conversations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "conversations_title_non_empty" CHECK ("btrim"("title") <> ''::"text"),
    CONSTRAINT "conversations_context_is_object" CHECK ("jsonb_typeof"("context") = 'object'::"text"),
    -- A client may only ever create/read rows owned by the session user.
    CONSTRAINT "conversations_owner_is_session_user" CHECK ("user_id" = "core"."auth_user_id"())
);

ALTER TABLE "assistant"."conversations" OWNER TO "postgres";

COMMENT ON TABLE "assistant"."conversations" IS
  'One persistent advisor chat thread. Owned by a single auth user; context jsonb holds module/route/workspace labels as metadata only and never locks the thread to a module or entity.';

-- Composite key so messages can FK both ids and prove shared ownership.
CREATE UNIQUE INDEX IF NOT EXISTS "conversations_id_user_id_key"
  ON "assistant"."conversations" ("id", "user_id");

CREATE INDEX IF NOT EXISTS "conversations_user_activity_idx"
  ON "assistant"."conversations" ("user_id", "last_message_at" DESC NULLS LAST, "created_at" DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- assistant.messages
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS "assistant"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "uuid" DEFAULT "core"."auth_user_id"() NOT NULL,
    "role" "text" NOT NULL,
    "content" "text" NOT NULL,
    "error_code" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "messages_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "messages_role_check" CHECK ("role" = ANY (ARRAY['farmer'::"text", 'adviser'::"text"])),
    CONSTRAINT "messages_content_non_empty" CHECK ("btrim"("content") <> ''::"text"),
    CONSTRAINT "messages_owner_is_session_user" CHECK ("user_id" = "core"."auth_user_id"()),
    CONSTRAINT "messages_conversation_fk"
      FOREIGN KEY ("conversation_id", "user_id")
      REFERENCES "assistant"."conversations"("id", "user_id")
      ON DELETE CASCADE
);

ALTER TABLE "assistant"."messages" OWNER TO "postgres";

COMMENT ON TABLE "assistant"."messages" IS
  'One chat message inside an advisor conversation. Denormalised user_id is pinned to the session user by CHECK + RLS; the composite FK guarantees the conversation belongs to the same user.';

CREATE INDEX IF NOT EXISTS "messages_conversation_created_idx"
  ON "assistant"."messages" ("conversation_id", "created_at", "id");

-- ─────────────────────────────────────────────────────────────────────────────
-- Activity bump: a landed message marks the conversation as active.
-- Invoker rights: RLS on assistant.conversations still applies to the caller,
-- and the composite FK already proved the caller owns that conversation.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION "assistant"."bump_conversation_activity"()
  RETURNS trigger
  LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE "assistant"."conversations"
     SET "last_message_at" = NEW."created_at"
   WHERE "id" = NEW."conversation_id";
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS "messages_bump_conversation" ON "assistant"."messages";
CREATE TRIGGER "messages_bump_conversation"
  AFTER INSERT ON "assistant"."messages"
  FOR EACH ROW
  EXECUTE FUNCTION "assistant"."bump_conversation_activity"();

DROP TRIGGER IF EXISTS "conversations_set_updated_at" ON "assistant"."conversations";
CREATE TRIGGER "conversations_set_updated_at"
  BEFORE UPDATE ON "assistant"."conversations"
  FOR EACH ROW
  EXECUTE FUNCTION "core"."set_updated_at"();

-- ─────────────────────────────────────────────────────────────────────────────
-- Grants: no table access for anon/PUBLIC; authenticated owns its rows via
-- RLS; service_role keeps full access for backend operations.
-- ─────────────────────────────────────────────────────────────────────────────
REVOKE ALL ON TABLE "assistant"."conversations" FROM PUBLIC;
REVOKE ALL ON TABLE "assistant"."messages" FROM PUBLIC;
REVOKE ALL ON TABLE "assistant"."conversations" FROM anon;
REVOKE ALL ON TABLE "assistant"."messages" FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "assistant"."conversations" TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "assistant"."messages" TO authenticated;
GRANT ALL ON TABLE "assistant"."conversations" TO service_role;
GRANT ALL ON TABLE "assistant"."messages" TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security: every operation is owner-scoped. WITH CHECK pins the
-- owner to the session user, so a client-supplied user_id for another account
-- is rejected even if RLS were somehow bypassed for reads.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE "assistant"."conversations" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "assistant"."messages" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "conversations_owner_all" ON "assistant"."conversations";
CREATE POLICY "conversations_owner_all"
  ON "assistant"."conversations"
  FOR ALL
  TO "authenticated"
  USING ("user_id" = "core"."auth_user_id"())
  WITH CHECK ("user_id" = "core"."auth_user_id"());

DROP POLICY IF EXISTS "messages_owner_all" ON "assistant"."messages";
CREATE POLICY "messages_owner_all"
  ON "assistant"."messages"
  FOR ALL
  TO "authenticated"
  USING ("user_id" = "core"."auth_user_id"())
  WITH CHECK ("user_id" = "core"."auth_user_id"());
