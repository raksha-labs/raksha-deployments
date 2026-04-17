-- Local-only seed: one free plan + one tenant + one owner user, all
-- with stable UUIDs so dev-autologin (in portal/admin middlewares)
-- and BFF proxies can route against real rows without DB lookups.
--
-- UUID conventions for local stack:
--   Tenant:  00000000-0000-0000-0000-000000000001
--   User:    00000000-0000-0000-0000-0000000000aa  (owner of that tenant)

\c raksha_portal

INSERT INTO tenants.plans (plan_id, display_name, price_monthly, price_annual, is_public, description)
VALUES
    ('free',       'Free',         0,    0,    true,  'Local dev plan'),
    ('starter',    'Starter',      149,  1430, true,  'Starter self-serve plan'),
    ('pro',        'Professional', 499,  4790, true,  'Primary production plan'),
    ('enterprise', 'Enterprise',   NULL, NULL, true,  'Custom deployment plan')
ON CONFLICT (plan_id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    price_monthly = EXCLUDED.price_monthly,
    price_annual = EXCLUDED.price_annual,
    is_public = EXCLUDED.is_public,
    description = EXCLUDED.description;

-- Minimal feature set for local-dev tenant on the free plan. Keeps
-- Monitor product visible; Lab/ML gated via LabRequiredGate + feature
-- keys (ml:detection, product:intelligence) stay off until upsell.
INSERT INTO tenants.plan_features (plan_id, feature_key, category, enabled) VALUES
    ('free',       'product:monitor',          'product',    true),
    ('free',       'monitor:basic',            'detection',  true),
    ('free',       'patterns:create',          'detection',  true),
    ('free',       'detect:depeg',             'detection',  true),
    ('free',       'detect:tvl_drop',          'detection',  true),
    ('free',       'notify:webhook',           'notify',     true),

    ('starter',    'product:monitor',          'product',    true),
    ('starter',    'product:workbench',        'product',    true),
    ('starter',    'alert:build',              'detection',  true),
    ('starter',    'patterns:create',          'detection',  true),
    ('starter',    'detect:depeg',             'detection',  true),
    ('starter',    'detect:tvl_drop',          'detection',  true),
    ('starter',    'detect:utilization',       'detection',  true),
    ('starter',    'sim:scenario:create',      'workbench',  true),
    ('starter',    'datasource:custom',        'datasource', true),
    ('starter',    'notify:webhook',           'notify',     true),
    ('starter',    'team:members',             'team',       true),

    ('pro',        'product:monitor',          'product',    true),
    ('pro',        'product:workbench',        'product',    true),
    ('pro',        'alert:build',              'detection',  true),
    ('pro',        'alert:rule_studio',        'detection',  true),
    ('pro',        'patterns:create',          'detection',  true),
    ('pro',        'detect:depeg',             'detection',  true),
    ('pro',        'detect:tvl_drop',          'detection',  true),
    ('pro',        'detect:flash_loan',        'detection',  true),
    ('pro',        'detect:utilization',       'detection',  true),
    ('pro',        'sim:scenario:create',      'workbench',  true),
    ('pro',        'sim:datasource:playground','workbench',  true),
    ('pro',        'datasource:custom',        'datasource', true),
    ('pro',        'notify:webhook',           'notify',     true),
    ('pro',        'notify:slack',             'notify',     true),
    ('pro',        'notify:email',             'notify',     true),
    ('pro',        'api:key',                  'api',        true),
    ('pro',        'team:members',             'team',       true),

    ('enterprise', 'product:monitor',          'product',    true),
    ('enterprise', 'product:workbench',        'product',    true),
    ('enterprise', 'alert:build',              'detection',  true),
    ('enterprise', 'alert:rule_studio',        'detection',  true),
    ('enterprise', 'alert:backtest',           'detection',  true),
    ('enterprise', 'patterns:create',          'detection',  true),
    ('enterprise', 'detect:depeg',             'detection',  true),
    ('enterprise', 'detect:tvl_drop',          'detection',  true),
    ('enterprise', 'detect:flash_loan',        'detection',  true),
    ('enterprise', 'detect:utilization',       'detection',  true),
    ('enterprise', 'sim:scenario:create',      'workbench',  true),
    ('enterprise', 'sim:datasource:playground','workbench',  true),
    ('enterprise', 'sim:export',               'workbench',  true),
    ('enterprise', 'datasource:custom',        'datasource', true),
    ('enterprise', 'notify:webhook',           'notify',     true),
    ('enterprise', 'notify:slack',             'notify',     true),
    ('enterprise', 'notify:email',             'notify',     true),
    ('enterprise', 'notify:telegram',          'notify',     true),
    ('enterprise', 'api:key',                  'api',        true),
    ('enterprise', 'team:members',             'team',       true),
    ('enterprise', 'team:sso',                 'team',       true)
ON CONFLICT (plan_id, feature_key) DO UPDATE SET
    category = EXCLUDED.category,
    enabled = EXCLUDED.enabled;

INSERT INTO tenants.tenants (id, display_name, slug, plan_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'Local Dev Tenant', 'local-dev', 'enterprise')
ON CONFLICT (id) DO UPDATE SET plan_id = 'enterprise';

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
