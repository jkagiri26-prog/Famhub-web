-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE agri_connect.communities (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  community_type text NOT NULL CHECK (community_type = ANY (ARRAY['interest'::text, 'location'::text, 'buyer'::text, 'self_help'::text, 'cooperative'::text, 'organization'::text, 'private'::text, 'project'::text])),
  visibility text NOT NULL DEFAULT 'public'::text CHECK (visibility = ANY (ARRAY['public'::text, 'private'::text, 'restricted'::text])),
  entity_id uuid,
  location_id uuid,
  created_by uuid NOT NULL,
  profile_image_file_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  is_verified boolean NOT NULL DEFAULT false,
  member_count integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT communities_pkey PRIMARY KEY (id),
  CONSTRAINT communities_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT communities_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id),
  CONSTRAINT communities_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.community_members (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'member'::text CHECK (role = ANY (ARRAY['member'::text, 'moderator'::text, 'admin'::text, 'owner'::text])),
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['pending'::text, 'active'::text, 'suspended'::text, 'banned'::text, 'left'::text, 'rejected'::text])),
  joined_at timestamp with time zone,
  invited_by uuid,
  requested_at timestamp with time zone,
  approved_by uuid,
  approved_at timestamp with time zone,
  muted_until timestamp with time zone,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_members_pkey PRIMARY KEY (id),
  CONSTRAINT community_members_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT community_members_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT community_members_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES users.profiles(id),
  CONSTRAINT community_members_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.community_join_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text])),
  message text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_join_requests_pkey PRIMARY KEY (id),
  CONSTRAINT community_join_requests_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT community_join_requests_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT community_join_requests_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.community_invitations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL,
  invited_profile_id uuid,
  invited_email text,
  invited_by uuid NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text, 'expired'::text, 'cancelled'::text])),
  expires_at timestamp with time zone,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_invitations_pkey PRIMARY KEY (id),
  CONSTRAINT community_invitations_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT community_invitations_invited_profile_id_fkey FOREIGN KEY (invited_profile_id) REFERENCES users.profiles(id),
  CONSTRAINT community_invitations_invited_by_fkey FOREIGN KEY (invited_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.conversations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_type text NOT NULL CHECK (conversation_type = ANY (ARRAY['direct'::text, 'group'::text, 'community'::text, 'marketplace'::text, 'support'::text, 'organization'::text])),
  title text,
  community_id uuid,
  created_by uuid,
  context_type text,
  context_id uuid,
  is_active boolean NOT NULL DEFAULT true,
  last_message_at timestamp with time zone,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversations_pkey PRIMARY KEY (id),
  CONSTRAINT conversations_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT conversations_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.conversation_participants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  profile_id uuid,
  entity_id uuid,
  role text NOT NULL DEFAULT 'participant'::text CHECK (role = ANY (ARRAY['participant'::text, 'moderator'::text, 'admin'::text, 'owner'::text])),
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['invited'::text, 'active'::text, 'left'::text, 'removed'::text, 'blocked'::text])),
  joined_at timestamp with time zone,
  last_read_at timestamp with time zone,
  muted_until timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT conversation_participants_pkey PRIMARY KEY (id),
  CONSTRAINT conversation_participants_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES agri_connect.conversations(id),
  CONSTRAINT conversation_participants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT conversation_participants_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE agri_connect.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  sender_profile_id uuid,
  sender_entity_id uuid,
  message_type text NOT NULL DEFAULT 'text'::text CHECK (message_type = ANY (ARRAY['text'::text, 'image'::text, 'video'::text, 'document'::text, 'audio'::text, 'system'::text])),
  body text,
  reply_to_message_id uuid,
  media_file_id uuid,
  is_edited boolean NOT NULL DEFAULT false,
  edited_at timestamp with time zone,
  is_deleted boolean NOT NULL DEFAULT false,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES agri_connect.conversations(id),
  CONSTRAINT messages_sender_profile_id_fkey FOREIGN KEY (sender_profile_id) REFERENCES users.profiles(id),
  CONSTRAINT messages_sender_entity_id_fkey FOREIGN KEY (sender_entity_id) REFERENCES core.entities(id),
  CONSTRAINT messages_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES agri_connect.messages(id)
);
CREATE TABLE agri_connect.message_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  message_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  reaction text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT message_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES agri_connect.messages(id),
  CONSTRAINT message_reactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.discussions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid,
  title text NOT NULL,
  discussion_type text NOT NULL DEFAULT 'discussion'::text CHECK (discussion_type = ANY (ARRAY['question'::text, 'discussion'::text, 'announcement'::text, 'poll'::text])),
  created_by uuid NOT NULL,
  is_pinned boolean NOT NULL DEFAULT false,
  is_locked boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  view_count integer NOT NULL DEFAULT 0,
  reply_count integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT discussions_pkey PRIMARY KEY (id),
  CONSTRAINT discussions_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT discussions_created_by_fkey FOREIGN KEY (created_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  discussion_id uuid NOT NULL,
  author_profile_id uuid NOT NULL,
  parent_post_id uuid,
  body text NOT NULL,
  is_edited boolean NOT NULL DEFAULT false,
  edited_at timestamp with time zone,
  is_deleted boolean NOT NULL DEFAULT false,
  deleted_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_discussion_id_fkey FOREIGN KEY (discussion_id) REFERENCES agri_connect.discussions(id),
  CONSTRAINT posts_author_profile_id_fkey FOREIGN KEY (author_profile_id) REFERENCES users.profiles(id),
  CONSTRAINT posts_parent_post_id_fkey FOREIGN KEY (parent_post_id) REFERENCES agri_connect.posts(id)
);
CREATE TABLE agri_connect.post_reactions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  profile_id uuid NOT NULL,
  reaction text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_reactions_pkey PRIMARY KEY (id),
  CONSTRAINT post_reactions_post_id_fkey FOREIGN KEY (post_id) REFERENCES agri_connect.posts(id),
  CONSTRAINT post_reactions_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.announcements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  announcement_type text NOT NULL CHECK (announcement_type = ANY (ARRAY['community'::text, 'organization'::text, 'famhub'::text])),
  community_id uuid,
  entity_id uuid,
  published_by uuid NOT NULL,
  is_published boolean NOT NULL DEFAULT false,
  published_at timestamp with time zone,
  expires_at timestamp with time zone,
  is_pinned boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT announcements_pkey PRIMARY KEY (id),
  CONSTRAINT announcements_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT announcements_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT announcements_published_by_fkey FOREIGN KEY (published_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.content_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reporter_profile_id uuid NOT NULL,
  target_type text NOT NULL CHECK (target_type = ANY (ARRAY['community'::text, 'discussion'::text, 'post'::text, 'message'::text, 'announcement'::text, 'profile'::text])),
  target_id uuid NOT NULL,
  reason text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'reviewing'::text, 'resolved'::text, 'dismissed'::text])),
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  resolution text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT content_reports_pkey PRIMARY KEY (id),
  CONSTRAINT content_reports_reporter_profile_id_fkey FOREIGN KEY (reporter_profile_id) REFERENCES users.profiles(id),
  CONSTRAINT content_reports_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.user_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  blocker_profile_id uuid NOT NULL,
  blocked_profile_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT user_blocks_blocker_profile_id_fkey FOREIGN KEY (blocker_profile_id) REFERENCES users.profiles(id),
  CONSTRAINT user_blocks_blocked_profile_id_fkey FOREIGN KEY (blocked_profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.moderation_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid,
  moderator_profile_id uuid NOT NULL,
  target_type text NOT NULL,
  target_id uuid NOT NULL,
  action_type text NOT NULL CHECK (action_type = ANY (ARRAY['warn'::text, 'mute'::text, 'remove'::text, 'restore'::text, 'suspend'::text, 'ban'::text, 'unban'::text, 'lock'::text, 'unlock'::text])),
  reason text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT moderation_actions_pkey PRIMARY KEY (id),
  CONSTRAINT moderation_actions_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id),
  CONSTRAINT moderation_actions_moderator_profile_id_fkey FOREIGN KEY (moderator_profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE agri_connect.community_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  community_id uuid NOT NULL,
  rule_order integer NOT NULL,
  title text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_rules_pkey PRIMARY KEY (id),
  CONSTRAINT community_rules_community_id_fkey FOREIGN KEY (community_id) REFERENCES agri_connect.communities(id)
);
CREATE TABLE agri_connect.discussion_views (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  discussion_id uuid NOT NULL,
  profile_id uuid,
  entity_id uuid,
  viewed_at timestamp with time zone NOT NULL DEFAULT now(),
  invalidated_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT discussion_views_pkey PRIMARY KEY (id),
  CONSTRAINT discussion_views_discussion_id_fkey FOREIGN KEY (discussion_id) REFERENCES agri_connect.discussions(id),
  CONSTRAINT discussion_views_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id),
  CONSTRAINT discussion_views_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);