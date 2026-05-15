final sync = AccessPolicySyncService(
  client: Supabase.instance.client,
  service: AccessPolicyService(),
);

sync.startListening();