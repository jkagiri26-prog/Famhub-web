-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE system.roles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT roles_pkey PRIMARY KEY (id)
);
CREATE TABLE system.modules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL UNIQUE,
  module_name text NOT NULL,
  module_description text,
  is_enabled boolean NOT NULL DEFAULT true,
  is_public boolean NOT NULL DEFAULT true,
  is_beta boolean NOT NULL DEFAULT false,
  is_premium boolean NOT NULL DEFAULT false,
  maintenance_mode boolean NOT NULL DEFAULT false,
  dashboard_visible boolean NOT NULL DEFAULT true,
  required_subscription text,
  required_roles ARRAY DEFAULT '{}'::text[],
  icon text,
  version text DEFAULT '1.0.0'::text,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT modules_pkey PRIMARY KEY (id)
);
CREATE TABLE system.feature_flags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  flag_key text NOT NULL UNIQUE,
  flag_name text NOT NULL,
  description text,
  is_enabled boolean NOT NULL DEFAULT false,
  module_key text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT feature_flags_pkey PRIMARY KEY (id),
  CONSTRAINT feature_flags_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.module_dependencies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  depends_on_module_key text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT module_dependencies_pkey PRIMARY KEY (id),
  CONSTRAINT module_dependencies_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key),
  CONSTRAINT module_dependencies_depends_on_module_key_fkey FOREIGN KEY (depends_on_module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.module_access_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  allowed_role text NOT NULL,
  subscription_required text,
  country_scope ARRAY DEFAULT '{}'::text[],
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT module_access_rules_pkey PRIMARY KEY (id),
  CONSTRAINT module_access_rules_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.module_audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  action_type text NOT NULL,
  old_value jsonb,
  new_value jsonb,
  changed_by uuid,
  reason text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT module_audit_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE system.workflow_definitions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workflow_key text NOT NULL UNIQUE,
  workflow_name text NOT NULL,
  module_name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_definitions_pkey PRIMARY KEY (id)
);
CREATE TABLE system.workflow_steps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL,
  step_order integer NOT NULL,
  step_name text NOT NULL,
  required_role_id uuid,
  is_mandatory boolean NOT NULL DEFAULT true,
  sla_hours integer,
  auto_approve boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_steps_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_steps_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES system.workflow_definitions(id),
  CONSTRAINT workflow_steps_required_role_id_fkey FOREIGN KEY (required_role_id) REFERENCES core.user_roles(id)
);
CREATE TABLE system.workflow_instances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL,
  module_name text NOT NULL,
  reference_table text NOT NULL,
  reference_id uuid NOT NULL,
  entity_id uuid,
  initiated_by uuid,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'in_progress'::text, 'approved'::text, 'rejected'::text, 'cancelled'::text, 'escalated'::text, 'completed'::text])),
  current_step integer DEFAULT 1,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_instances_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_instances_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES users.profiles(id),
  CONSTRAINT workflow_instances_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES system.workflow_definitions(id),
  CONSTRAINT workflow_instances_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.workflow_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NOT NULL,
  step_id uuid,
  acted_by uuid,
  action_type text NOT NULL CHECK (action_type = ANY (ARRAY['approve'::text, 'reject'::text, 'comment'::text, 'reassign'::text, 'escalate'::text, 'override'::text, 'cancel'::text])),
  decision text,
  notes text,
  acted_at timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT workflow_actions_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_actions_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES system.workflow_instances(id),
  CONSTRAINT workflow_actions_step_id_fkey FOREIGN KEY (step_id) REFERENCES system.workflow_steps(id),
  CONSTRAINT workflow_actions_acted_by_fkey FOREIGN KEY (acted_by) REFERENCES users.profiles(id)
);
CREATE TABLE system.workflow_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NOT NULL,
  assigned_to uuid,
  assigned_role_id uuid,
  assigned_entity_id uuid,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'accepted'::text, 'completed'::text, 'expired'::text, 'reassigned'::text])),
  assigned_at timestamp with time zone NOT NULL DEFAULT now(),
  due_at timestamp with time zone,
  resolved_at timestamp with time zone,
  CONSTRAINT workflow_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_assignments_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES system.workflow_instances(id),
  CONSTRAINT workflow_assignments_assigned_to_fkey FOREIGN KEY (assigned_to) REFERENCES users.profiles(id),
  CONSTRAINT workflow_assignments_assigned_role_id_fkey FOREIGN KEY (assigned_role_id) REFERENCES core.user_roles(id),
  CONSTRAINT workflow_assignments_assigned_entity_id_fkey FOREIGN KEY (assigned_entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.workflow_escalations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid NOT NULL,
  from_step integer,
  to_step integer,
  reason text,
  escalated_by uuid,
  escalated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_escalations_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_escalations_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES system.workflow_instances(id),
  CONSTRAINT workflow_escalations_escalated_by_fkey FOREIGN KEY (escalated_by) REFERENCES users.profiles(id)
);
CREATE TABLE system.workflow_notifications (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  instance_id uuid,
  recipient_id uuid,
  notification_type text NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  sent_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_notifications_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_notifications_instance_id_fkey FOREIGN KEY (instance_id) REFERENCES system.workflow_instances(id),
  CONSTRAINT workflow_notifications_recipient_id_fkey FOREIGN KEY (recipient_id) REFERENCES users.profiles(id)
);
CREATE TABLE system.workflow_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workflow_id uuid NOT NULL,
  rule_type text NOT NULL,
  condition_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  action_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  priority integer NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workflow_rules_pkey PRIMARY KEY (id),
  CONSTRAINT workflow_rules_workflow_id_fkey FOREIGN KEY (workflow_id) REFERENCES system.workflow_definitions(id)
);
CREATE TABLE system.billing_accounts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid,
  profile_id uuid,
  account_type text NOT NULL CHECK (account_type = ANY (ARRAY['individual'::text, 'business'::text, 'cooperative'::text, 'supplier'::text, 'partner'::text, 'platform_internal'::text])),
  currency text NOT NULL DEFAULT 'KES'::text,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text, 'closed'::text, 'restricted'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT billing_accounts_pkey PRIMARY KEY (id),
  CONSTRAINT billing_accounts_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT billing_accounts_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES users.profiles(id)
);
CREATE TABLE system.subscription_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  plan_key text NOT NULL UNIQUE,
  plan_name text NOT NULL,
  module_key text,
  billing_cycle text NOT NULL CHECK (billing_cycle = ANY (ARRAY['once'::text, 'monthly'::text, 'quarterly'::text, 'yearly'::text])),
  amount numeric NOT NULL DEFAULT 0,
  currency text NOT NULL DEFAULT 'KES'::text,
  is_active boolean NOT NULL DEFAULT true,
  features_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT subscription_plans_pkey PRIMARY KEY (id),
  CONSTRAINT subscription_plans_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.active_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  billing_account_id uuid NOT NULL,
  plan_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'expired'::text, 'cancelled'::text, 'pending'::text, 'suspended'::text])),
  start_date timestamp with time zone NOT NULL DEFAULT now(),
  end_date timestamp with time zone,
  auto_renew boolean NOT NULL DEFAULT false,
  payment_reference text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT active_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT active_subscriptions_billing_account_id_fkey FOREIGN KEY (billing_account_id) REFERENCES system.billing_accounts(id),
  CONSTRAINT active_subscriptions_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES system.subscription_plans(id)
);
CREATE TABLE system.invoices (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  billing_account_id uuid NOT NULL,
  invoice_number text NOT NULL UNIQUE,
  module_name text NOT NULL,
  reference_table text,
  reference_id uuid,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'paid'::text, 'failed'::text, 'cancelled'::text, 'overdue'::text, 'refunded'::text])),
  total_amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'KES'::text,
  due_date timestamp with time zone,
  paid_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT invoices_pkey PRIMARY KEY (id),
  CONSTRAINT invoices_billing_account_id_fkey FOREIGN KEY (billing_account_id) REFERENCES system.billing_accounts(id)
);
CREATE TABLE system.invoice_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL,
  item_type text NOT NULL,
  description text NOT NULL,
  quantity numeric NOT NULL DEFAULT 1,
  unit_price numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT invoice_items_pkey PRIMARY KEY (id),
  CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES system.invoices(id)
);
CREATE TABLE system.payment_attempts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  invoice_id uuid NOT NULL,
  payment_method text NOT NULL CHECK (payment_method = ANY (ARRAY['mpesa'::text, 'bank'::text, 'card'::text, 'wallet'::text, 'escrow'::text, 'cash'::text])),
  transaction_reference text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'successful'::text, 'failed'::text, 'cancelled'::text, 'reversed'::text])),
  provider_response text,
  amount numeric NOT NULL,
  attempted_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT payment_attempts_pkey PRIMARY KEY (id),
  CONSTRAINT payment_attempts_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES system.invoices(id)
);
CREATE TABLE system.commission_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_name text NOT NULL,
  rule_type text NOT NULL,
  percentage numeric,
  fixed_amount numeric,
  conditions_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT commission_rules_pkey PRIMARY KEY (id)
);
CREATE TABLE system.payout_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  billing_account_id uuid NOT NULL,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'KES'::text,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'processing'::text, 'paid'::text, 'rejected'::text, 'cancelled'::text])),
  requested_by uuid,
  requested_at timestamp with time zone NOT NULL DEFAULT now(),
  processed_at timestamp with time zone,
  CONSTRAINT payout_requests_pkey PRIMARY KEY (id),
  CONSTRAINT payout_requests_billing_account_id_fkey FOREIGN KEY (billing_account_id) REFERENCES system.billing_accounts(id),
  CONSTRAINT payout_requests_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES users.profiles(id)
);
CREATE TABLE system.payout_disbursements (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  payout_request_id uuid NOT NULL,
  payment_method text NOT NULL,
  transaction_reference text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'successful'::text, 'failed'::text, 'reversed'::text])),
  provider_response text,
  disbursed_at timestamp with time zone,
  CONSTRAINT payout_disbursements_pkey PRIMARY KEY (id),
  CONSTRAINT payout_disbursements_payout_request_id_fkey FOREIGN KEY (payout_request_id) REFERENCES system.payout_requests(id)
);
CREATE TABLE system.revenue_ledger (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_type text NOT NULL,
  module_name text NOT NULL,
  reference_table text,
  reference_id uuid,
  amount numeric NOT NULL,
  currency text NOT NULL DEFAULT 'KES'::text,
  direction text NOT NULL CHECK (direction = ANY (ARRAY['credit'::text, 'debit'::text])),
  billing_account_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT revenue_ledger_pkey PRIMARY KEY (id),
  CONSTRAINT revenue_ledger_billing_account_id_fkey FOREIGN KEY (billing_account_id) REFERENCES system.billing_accounts(id)
);
CREATE TABLE system.wallet_balances (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  billing_account_id uuid NOT NULL UNIQUE,
  available_balance numeric NOT NULL DEFAULT 0,
  reserved_balance numeric NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT wallet_balances_pkey PRIMARY KEY (id),
  CONSTRAINT wallet_balances_billing_account_id_fkey FOREIGN KEY (billing_account_id) REFERENCES system.billing_accounts(id)
);
CREATE TABLE system.transaction_reconciliation (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  payment_attempt_id uuid NOT NULL,
  provider_name text NOT NULL,
  provider_reference text,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'matched'::text, 'mismatch'::text, 'resolved'::text])),
  notes text,
  reconciled_at timestamp with time zone,
  CONSTRAINT transaction_reconciliation_pkey PRIMARY KEY (id),
  CONSTRAINT transaction_reconciliation_payment_attempt_id_fkey FOREIGN KEY (payment_attempt_id) REFERENCES system.payment_attempts(id)
);
CREATE TABLE system.kpi_definitions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  kpi_key text NOT NULL UNIQUE,
  kpi_name text NOT NULL,
  module_name text NOT NULL,
  calculation_type text NOT NULL CHECK (calculation_type = ANY (ARRAY['sum'::text, 'average'::text, 'count'::text, 'ratio'::text, 'score'::text, 'custom'::text])),
  aggregation_level text NOT NULL CHECK (aggregation_level = ANY (ARRAY['global'::text, 'module'::text, 'entity'::text, 'location'::text, 'user'::text])),
  refresh_frequency text NOT NULL CHECK (refresh_frequency = ANY (ARRAY['hourly'::text, 'daily'::text, 'weekly'::text, 'monthly'::text, 'manual'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT kpi_definitions_pkey PRIMARY KEY (id)
);
CREATE TABLE system.kpi_snapshots (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  kpi_id uuid NOT NULL,
  entity_id uuid,
  location_id uuid,
  period_type text NOT NULL CHECK (period_type = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'quarterly'::text, 'yearly'::text])),
  period_start timestamp with time zone NOT NULL,
  period_end timestamp with time zone NOT NULL,
  metric_value numeric NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  calculated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT kpi_snapshots_pkey PRIMARY KEY (id),
  CONSTRAINT kpi_snapshots_kpi_id_fkey FOREIGN KEY (kpi_id) REFERENCES system.kpi_definitions(id),
  CONSTRAINT kpi_snapshots_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT kpi_snapshots_location_id_fkey FOREIGN KEY (location_id) REFERENCES core.locations(id)
);
CREATE TABLE system.analytics_events (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  module_name text NOT NULL,
  entity_id uuid,
  reference_table text,
  reference_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT analytics_events_pkey PRIMARY KEY (id),
  CONSTRAINT analytics_events_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.dashboard_metrics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  dashboard_key text NOT NULL,
  metric_key text NOT NULL,
  entity_id uuid,
  value numeric NOT NULL DEFAULT 0,
  last_updated timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT dashboard_metrics_pkey PRIMARY KEY (id),
  CONSTRAINT dashboard_metrics_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.module_health_scores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_name text NOT NULL,
  health_score numeric NOT NULL DEFAULT 0,
  risk_level text NOT NULL CHECK (risk_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  notes text,
  evaluated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT module_health_scores_pkey PRIMARY KEY (id)
);
CREATE TABLE system.entity_performance_scores (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entity_id uuid NOT NULL,
  score_type text NOT NULL,
  score_value numeric NOT NULL DEFAULT 0,
  risk_level text N
