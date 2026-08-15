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
  risk_level text NOT NULL CHECK (risk_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  evaluated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT entity_performance_scores_pkey PRIMARY KEY (id),
  CONSTRAINT entity_performance_scores_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.anomaly_detection_flags (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_name text NOT NULL,
  entity_id uuid,
  flag_type text NOT NULL,
  severity text NOT NULL CHECK (severity = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  description text NOT NULL,
  status text NOT NULL DEFAULT 'open'::text CHECK (status = ANY (ARRAY['open'::text, 'investigating'::text, 'resolved'::text, 'dismissed'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  resolved_at timestamp with time zone,
  CONSTRAINT anomaly_detection_flags_pkey PRIMARY KEY (id),
  CONSTRAINT anomaly_detection_flags_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id)
);
CREATE TABLE system.scheduled_reports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  report_key text NOT NULL UNIQUE,
  report_name text NOT NULL,
  frequency text NOT NULL CHECK (frequency = ANY (ARRAY['daily'::text, 'weekly'::text, 'monthly'::text, 'quarterly'::text])),
  target_role text NOT NULL,
  delivery_channel text NOT NULL CHECK (delivery_channel = ANY (ARRAY['email'::text, 'dashboard'::text, 'export'::text, 'api'::text])),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_reports_pkey PRIMARY KEY (id)
);
CREATE TABLE system.report_exports (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL,
  generated_for uuid,
  file_url text,
  status text NOT NULL DEFAULT 'generated'::text CHECK (status = ANY (ARRAY['generated'::text, 'failed'::text, 'expired'::text, 'archived'::text])),
  generated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT report_exports_pkey PRIMARY KEY (id),
  CONSTRAINT report_exports_report_id_fkey FOREIGN KEY (report_id) REFERENCES system.scheduled_reports(id),
  CONSTRAINT report_exports_generated_for_fkey FOREIGN KEY (generated_for) REFERENCES users.profiles(id)
);
CREATE TABLE system.executive_summary_cache (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  summary_key text NOT NULL UNIQUE,
  summary_title text NOT NULL,
  summary_value text NOT NULL,
  summary_context jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT executive_summary_cache_pkey PRIMARY KEY (id)
);
CREATE TABLE system.scheduled_jobs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_key text NOT NULL UNIQUE,
  job_name text NOT NULL,
  job_type text NOT NULL CHECK (job_type = ANY (ARRAY['billing'::text, 'workflow'::text, 'analytics'::text, 'notification'::text, 'cleanup'::text, 'maintenance'::text, 'integration'::text, 'custom'::text])),
  module_name text NOT NULL,
  execution_mode text NOT NULL CHECK (execution_mode = ANY (ARRAY['once'::text, 'interval'::text, 'cron'::text, 'event_triggered'::text])),
  schedule_expression text,
  priority text NOT NULL DEFAULT 'medium'::text CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  is_active boolean NOT NULL DEFAULT true,
  last_run_at timestamp with time zone,
  next_run_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT scheduled_jobs_pkey PRIMARY KEY (id)
);
CREATE TABLE system.job_executions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  job_id uuid NOT NULL,
  execution_status text NOT NULL DEFAULT 'pending'::text CHECK (execution_status = ANY (ARRAY['pending'::text, 'running'::text, 'successful'::text, 'failed'::text, 'cancelled'::text, 'timed_out'::text])),
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  execution_log text,
  error_message text,
  retry_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT job_executions_pkey PRIMARY KEY (id),
  CONSTRAINT job_executions_job_id_fkey FOREIGN KEY (job_id) REFERENCES system.scheduled_jobs(id)
);
CREATE TABLE system.retry_queue (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  execution_id uuid NOT NULL,
  retry_reason text,
  retry_status text NOT NULL DEFAULT 'pending'::text CHECK (retry_status = ANY (ARRAY['pending'::text, 'scheduled'::text, 'processing'::text, 'resolved'::text, 'abandoned'::text])),
  next_retry_at timestamp with time zone,
  max_retries integer NOT NULL DEFAULT 5,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT retry_queue_pkey PRIMARY KEY (id),
  CONSTRAINT retry_queue_execution_id_fkey FOREIGN KEY (execution_id) REFERENCES system.job_executions(id)
);
CREATE TABLE system.delayed_actions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  action_type text NOT NULL,
  module_name text NOT NULL,
  reference_table text,
  reference_id uuid,
  execute_at timestamp with time zone NOT NULL,
  status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'executed'::text, 'cancelled'::text, 'failed'::text])),
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT delayed_actions_pkey PRIMARY KEY (id)
);
CREATE TABLE system.escalation_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  module_name text NOT NULL,
  trigger_type text NOT NULL,
  trigger_after_hours integer NOT NULL,
  escalation_target_role text,
  escalation_target_entity uuid,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT escalation_rules_pkey PRIMARY KEY (id),
  CONSTRAINT escalation_rules_escalation_target_entity_fkey FOREIGN KEY (escalation_target_entity) REFERENCES core.entities(id)
);
CREATE TABLE system.lifecycle_policies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  policy_key text NOT NULL UNIQUE,
  target_table text NOT NULL,
  lifecycle_action text NOT NULL CHECK (lifecycle_action = ANY (ARRAY['expire'::text, 'archive'::text, 'deactivate'::text, 'close'::text, 'renew'::text])),
  trigger_after_days integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT lifecycle_policies_pkey PRIMARY KEY (id)
);
CREATE TABLE system.cleanup_policies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  cleanup_key text NOT NULL UNIQUE,
  target_table text NOT NULL,
  cleanup_type text NOT NULL CHECK (cleanup_type = ANY (ARRAY['soft_delete'::text, 'archive'::text, 'purge'::text, 'compress'::text])),
  retention_days integer NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT cleanup_policies_pkey PRIMARY KEY (id)
);
CREATE TABLE system.maintenance_windows (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  maintenance_name text NOT NULL,
  module_name text,
  starts_at timestamp with time zone NOT NULL,
  ends_at timestamp with time zone NOT NULL,
  maintenance_type text NOT NULL CHECK (maintenance_type = ANY (ARRAY['system'::text, 'module'::text, 'database'::text, 'integration'::text, 'emergency'::text])),
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT maintenance_windows_pkey PRIMARY KEY (id)
);
CREATE TABLE system.background_workers (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  worker_name text NOT NULL UNIQUE,
  worker_type text NOT NULL,
  status text NOT NULL DEFAULT 'idle'::text CHECK (status = ANY (ARRAY['idle'::text, 'running'::text, 'stopped'::text, 'failed'::text, 'maintenance'::text])),
  last_heartbeat_at timestamp with time zone,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT background_workers_pkey PRIMARY KEY (id)
);
CREATE TABLE system.scheduler_locks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  lock_key text NOT NULL UNIQUE,
  locked_by text NOT NULL,
  locked_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  CONSTRAINT scheduler_locks_pkey PRIMARY KEY (id)
);
CREATE TABLE system.ai_agents (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  agent_key text NOT NULL UNIQUE,
  agent_name text NOT NULL,
  module_name text NOT NULL,
  agent_type text NOT NULL CHECK (agent_type = ANY (ARRAY['advisor'::text, 'copilot'::text, 'risk_engine'::text, 'recommender'::text, 'workflow_assistant'::text, 'fraud_detector'::text, 'prediction_engine'::text, 'smart_router'::text, 'custom'::text])),
  status text NOT NULL DEFAULT 'active'::text CHECK (status = ANY (ARRAY['active'::text, 'paused'::text, 'disabled'::text, 'testing'::text])),
  requires_human_review boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_agents_pkey PRIMARY KEY (id)
);
CREATE TABLE system.ai_models_registry (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  model_key text NOT NULL UNIQUE,
  model_name text NOT NULL,
  provider_name text NOT NULL,
  model_type text NOT NULL CHECK (model_type = ANY (ARRAY['llm'::text, 'classification'::text, 'regression'::text, 'forecasting'::text, 'vision'::text, 'ranking'::text, 'hybrid'::text])),
  version text NOT NULL,
  deployment_status text NOT NULL DEFAULT 'active'::text CHECK (deployment_status = ANY (ARRAY['active'::text, 'deprecated'::text, 'testing'::text, 'disabled'::text])),
  cost_profile jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_models_registry_pkey PRIMARY KEY (id)
);
CREATE TABLE system.ai_tasks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  agent_id uuid NOT NULL,
  model_id uuid,
  module_name text NOT NULL,
  task_type text NOT NULL,
  reference_table text,
  reference_id uuid,
  entity_id uuid,
  initiated_by uuid,
  task_status text NOT NULL DEFAULT 'pending'::text CHECK (task_status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'cancelled'::text, 'escalated'::text])),
  input_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  completed_at timestamp with time zone,
  CONSTRAINT ai_tasks_pkey PRIMARY KEY (id),
  CONSTRAINT ai_tasks_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES system.ai_agents(id),
  CONSTRAINT ai_tasks_model_id_fkey FOREIGN KEY (model_id) REFERENCES system.ai_models_registry(id),
  CONSTRAINT ai_tasks_entity_id_fkey FOREIGN KEY (entity_id) REFERENCES core.entities(id),
  CONSTRAINT ai_tasks_initiated_by_fkey FOREIGN KEY (initiated_by) REFERENCES users.profiles(id)
);
CREATE TABLE system.ai_task_executions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  execution_status text NOT NULL DEFAULT 'pending'::text CHECK (execution_status = ANY (ARRAY['pending'::text, 'running'::text, 'successful'::text, 'failed'::text, 'timed_out'::text, 'cancelled'::text])),
  started_at timestamp with time zone,
  completed_at timestamp with time zone,
  execution_log text,
  model_response jsonb DEFAULT '{}'::jsonb,
  error_message text,
  retry_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_task_executions_pkey PRIMARY KEY (id),
  CONSTRAINT ai_task_executions_task_id_fkey FOREIGN KEY (task_id) REFERENCES system.ai_tasks(id)
);
CREATE TABLE system.ai_recommendations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  task_id uuid NOT NULL,
  recommendation_type text NOT NULL,
  recommendation_summary text NOT NULL,
  recommendation_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  confidence_score numeric,
  recommendation_status text NOT NULL DEFAULT 'pending_review'::text CHECK (recommendation_status = ANY (ARRAY['pending_review'::text, 'approved'::text, 'rejected'::text, 'implemented'::text, 'overridden'::text])),
  requires_approval boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_recommendations_pkey PRIMARY KEY (id),
  CONSTRAINT ai_recommendations_task_id_fkey FOREIGN KEY (task_id) REFERENCES system.ai_tasks(id)
);
CREATE TABLE system.ai_decision_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  recommendation_id uuid,
  decision_type text NOT NULL,
  decided_by uuid,
  final_decision text NOT NULL,
  override_reason text,
  workflow_instance_id uuid,
  audit_reference_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_decision_logs_pkey PRIMARY KEY (id),
  CONSTRAINT ai_decision_logs_recommendation_id_fkey FOREIGN KEY (recommendation_id) REFERENCES system.ai_recommendations(id),
  CONSTRAINT ai_decision_logs_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES users.profiles(id),
  CONSTRAINT ai_decision_logs_workflow_instance_id_fkey FOREIGN KEY (workflow_instance_id) REFERENCES system.workflow_instances(id)
);
CREATE TABLE system.ai_feedback_loops (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  recommendation_id uuid,
  feedback_type text NOT NULL CHECK (feedback_type = ANY (ARRAY['positive'::text, 'negative'::text, 'correction'::text, 'override'::text, 'manual_adjustment'::text])),
  feedback_notes text,
  feedback_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_feedback_loops_pkey PRIMARY KEY (id),
  CONSTRAINT ai_feedback_loops_recommendation_id_fkey FOREIGN KEY (recommendation_id) REFERENCES system.ai_recommendations(id),
  CONSTRAINT ai_feedback_loops_feedback_by_fkey FOREIGN KEY (feedback_by) REFERENCES users.profiles(id)
);
CREATE TABLE system.ai_prompt_templates (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  template_key text NOT NULL UNIQUE,
  template_name text NOT NULL,
  module_name text NOT NULL,
  prompt_template text NOT NULL,
  version integer NOT NULL DEFAULT 1,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_prompt_templates_pkey PRIMARY KEY (id)
);
CREATE TABLE system.ai_guardrails (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  rule_key text NOT NULL UNIQUE,
  rule_name text NOT NULL,
  module_name text,
  restriction_type text NOT NULL CHECK (restriction_type = ANY (ARRAY['approval_required'::text, 'deny_action'::text, 'limit_scope'::text, 'human_override_required'::text, 'compliance_block'::text])),
  rule_definition jsonb NOT NULL DEFAULT '{}'::jsonb,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_guardrails_pkey PRIMARY KEY (id)
);
CREATE TABLE system.ai_escalation_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  escalation_key text NOT NULL UNIQUE,
  module_name text NOT NULL,
  trigger_type text NOT NULL,
  severity_level text NOT NULL CHECK (severity_level = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text])),
  escalation_target_role uuid,
  requires_manual_review boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_escalation_rules_pkey PRIMARY KEY (id),
  CONSTRAINT ai_escalation_rules_escalation_target_role_fkey FOREIGN KEY (escalation_target_role) REFERENCES core.user_roles(id)
);
CREATE TABLE system.dashboard_descriptors (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  widget_key text NOT NULL,
  descriptor_name text NOT NULL,
  display_order integer NOT NULL DEFAULT 0,
  layout_zone text DEFAULT 'main'::text,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  feature_flag_key text,
  is_enabled boolean NOT NULL DEFAULT true,
  is_premium boolean NOT NULL DEFAULT false,
  priority integer NOT NULL DEFAULT 0,
  visibility_scope text NOT NULL DEFAULT 'default'::text CHECK (visibility_scope = ANY (ARRAY['default'::text, 'farmer'::text, 'trader'::text, 'admin'::text, 'stakeholder'::text, 'enterprise'::text])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  descriptor_type text NOT NULL DEFAULT 'widget'::text,
  cache_strategy text NOT NULL DEFAULT 'standard'::text CHECK (cache_strategy = ANY (ARRAY['standard'::text, 'realtime'::text, 'heavy_cached'::text, 'lazy_load'::text])),
  mobile_visibility boolean NOT NULL DEFAULT true,
  tablet_visibility boolean NOT NULL DEFAULT true,
  desktop_visibility boolean NOT NULL DEFAULT true,
  requires_entity_context boolean NOT NULL DEFAULT false,
  CONSTRAINT dashboard_descriptors_pkey PRIMARY KEY (id),
  CONSTRAINT dashboard_descriptors_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key),
  CONSTRAINT dashboard_descriptors_feature_flag_key_fkey FOREIGN KEY (feature_flag_key) REFERENCES system.feature_flags(flag_key)
);
CREATE TABLE system.dashboard_blocks (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  block_key text NOT NULL,
  block_type text NOT NULL,
  block_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  display_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT dashboard_blocks_pkey PRIMARY KEY (id),
  CONSTRAINT dashboard_blocks_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.widget_registry (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  widget_key text NOT NULL UNIQUE,
  widget_name text NOT NULL,
  module_key text NOT NULL,
  widget_type text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  is_deprecated boolean NOT NULL DEFAULT false,
  version integer NOT NULL DEFAULT 1,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT widget_registry_pkey PRIMARY KEY (id),
  CONSTRAINT widget_registry_module_key_fkey FOREIGN KEY (module_key) REFERENCES system.modules(module_key)
);
CREATE TABLE system.dashboard_layout_settings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  module_key text NOT NULL,
  role text,
  entity_id uuid,
  device text NOT NULL,
  layout_key text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT dashboard_layout_settings_pkey PRIMARY KEY (id)
);
CREATE TABLE system.module_zone_mappings (
  module_key text NOT NULL,
  zone_id text NOT NULL,
  tenant_id text,
  is_active boolean NOT NULL DEFAULT true
);
CREATE TABLE system.policy_profiles (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  parent_policy_id uuid,
  name text NOT NULL,
  description text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  geo_location_id uuid,
  organization_id uuid,
  priority integer NOT NULL DEFAULT 0,
  CONSTRAINT policy_profiles_pkey PRIMARY KEY (id),
  CONSTRAINT policy_profiles_organization_id_fk FOREIGN KEY (organization_id) REFERENCES core.entities(id),
  CONSTRAINT policy_profiles_parent_policy_id_fkey FOREIGN KEY (parent_policy_id) REFERENCES system.policy_profiles(id),
  CONSTRAINT policy_profiles_geo_location_fk FOREIGN KEY (geo_location_id) REFERENCES core.locations(id)
);
CREATE TABLE system.policy_rules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  policy_id uuid NOT NULL,
  rule_key text NOT NULL,
  rule_value text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT policy_rules_pkey PRIMARY KEY (id),
  CONSTRAINT policy_rules_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES system.policy_profiles(id)
);
CREATE TABLE system.organization_policies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL,
  policy_id uuid NOT NULL,
  precedence integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT organization_policies_pkey PRIMARY KEY (id),
  CONSTRAINT organization_policies_policy_id_fkey FOREIGN KEY (policy_id) REFERENCES system.policy_profiles(id)
);
CREATE TABLE system.policy_audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  organization_id uuid,
  actor_user_id uuid,
  entity_type text NOT NULL CHECK (entity_type = ANY (ARRAY['policy_profile'::text, 'policy_rule'::text, 'organization_policy'::text])),
  entity_id uuid NOT NULL,
  action text NOT NULL CHECK (action = ANY (ARRAY['insert'::text, 'update'::text, 'delete'::text])),
  old_row jsonb,
  new_row jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT policy_audit_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE system.workspaces (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  icon text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workspaces_pkey PRIMARY KEY (id)
);
CREATE TABLE system.workspace_business_types (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL,
  key text NOT NULL,
  name text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workspace_business_types_pkey PRIMARY KEY (id),
  CONSTRAINT workspace_business_types_workspace_id_fkey FOREIGN KEY (workspace_id) REFERENCES system.workspaces(id)
);
CREATE TABLE system.workspace_specializations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  business_type_id uuid NOT NULL,
  key text NOT NULL,
  name text NOT NULL,
  description text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workspace_specializations_pkey PRIMARY KEY (id),
  CONSTRAINT workspace_specializations_business_type_id_fkey FOREIGN KEY (business_type_id) REFERENCES system.workspace_business_types(id)
);
