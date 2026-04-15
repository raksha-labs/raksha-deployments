-- Local-only seed: one free plan + one tenant + one owner user, all
-- with stable UUIDs so dev-autologin (in portal/admin middlewares)
-- and BFF proxies can route against real rows without DB lookups.
--
-- UUID conventions for local stack:
--   Tenant:  00000000-0000-0000-0000-000000000001
--   User:    00000000-0000-0000-0000-0000000000aa  (owner of that tenant)

\c raksha_control

INSERT INTO tenants.plans (plan_id, display_name, is_public, description)
VALUES ('free', 'Free', false, 'Local dev plan')
ON CONFLICT (plan_id) DO NOTHING;

-- Minimal feature set for local-dev tenant on the free plan. Keeps
-- Monitor product visible; Lab/ML gated via LabRequiredGate + feature
-- keys (ml:detection, product:intelligence) stay off until upsell.
INSERT INTO tenants.plan_features (plan_id, feature_key, category, enabled) VALUES
    ('free', 'product:monitor',  'product',   true),
    ('free', 'monitor:basic',    'detection', true),
    ('free', 'patterns:create',  'detection', true),
    ('free', 'notify:webhook',   'notify',    true)
ON CONFLICT (plan_id, feature_key) DO NOTHING;

INSERT INTO tenants.tenants (id, display_name, slug, plan_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'Local Dev Tenant', 'local-dev', 'free')
ON CONFLICT (id) DO NOTHING;

INSERT INTO iam.users (id, email, display_name, is_platform_admin)
VALUES ('00000000-0000-0000-0000-0000000000aa', 'dev@raksha.local', 'Dev User', true)
ON CONFLICT (email) DO NOTHING;

INSERT INTO tenants.tenant_members (tenant_id, user_id, role, accepted_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-0000000000aa',
  'owner',
  now()
)
ON CONFLICT (tenant_id, user_id) DO NOTHING;
