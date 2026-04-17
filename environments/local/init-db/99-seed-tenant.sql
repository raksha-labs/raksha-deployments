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
-- the monitor surface visible while simulation/intelligence features
-- stay off until a higher tier enables them.
INSERT INTO tenants.plan_features (plan_id, feature_key, category, enabled) VALUES
    ('free',       'product:monitor',          'product',    true),
    ('free',       'monitor:basic',            'detection',  true),
    ('free',       'patterns:create',          'detection',  true),
    ('free',       'detect:depeg',             'detection',  true),
    ('free',       'detect:tvl_drop',          'detection',  true),
    ('free',       'notify:webhook',           'notify',     true),

    ('starter',    'product:monitor',          'product',    true),
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

-- ─── Reserved _platform tenant ─────────────────────────────────────────────
-- Assets owned by this tenant are scope='platform' (auto-computed from the
-- well-known UUID). All bounded contexts use the same UUID constant:
--   00000000-0000-0000-0000-ffffffffffff
INSERT INTO tenants.tenants (id, display_name, slug, plan_id)
VALUES ('00000000-0000-0000-0000-ffffffffffff', 'Raksha Platform', '_platform', 'enterprise')
ON CONFLICT (id) DO UPDATE SET display_name = 'Raksha Platform';

-- ─── Regular dev tenant ───────────────────────────────────────────────────
INSERT INTO tenants.tenants (id, display_name, slug, plan_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'Local Dev Tenant', 'local-dev', 'enterprise')
ON CONFLICT (id) DO UPDATE SET plan_id = 'enterprise';

-- ─── Dev users with different roles ──────────────────────────────────────
-- 1. Platform owner: full platform admin + owns the dev tenant
INSERT INTO iam.users (id, email, display_name, is_platform_admin)
VALUES ('00000000-0000-0000-0000-0000000000aa', 'dev@raksha.local', 'Dev User (Platform Owner)', true)
ON CONFLICT (email) DO UPDATE SET display_name = 'Dev User (Platform Owner)', is_platform_admin = true;

-- 2. Platform editor: can edit platform patterns but not publish/delete
INSERT INTO iam.users (id, email, display_name, is_platform_admin)
VALUES ('00000000-0000-0000-0000-0000000000bb', 'editor@raksha.local', 'Platform Editor', false)
ON CONFLICT (email) DO UPDATE SET display_name = 'Platform Editor';

-- 3. Tenant admin: manages the dev tenant, no platform access
INSERT INTO iam.users (id, email, display_name, is_platform_admin)
VALUES ('00000000-0000-0000-0000-0000000000cc', 'admin@local-dev.local', 'Tenant Admin', false)
ON CONFLICT (email) DO UPDATE SET display_name = 'Tenant Admin';

-- 4. Tenant viewer: read-only on the dev tenant
INSERT INTO iam.users (id, email, display_name, is_platform_admin)
VALUES ('00000000-0000-0000-0000-0000000000dd', 'viewer@local-dev.local', 'Tenant Viewer', false)
ON CONFLICT (email) DO UPDATE SET display_name = 'Tenant Viewer';

-- ─── Membership: _platform tenant ────────────────────────────────────────
-- Dev user is platform_owner, editor is platform_editor
INSERT INTO tenants.tenant_members (tenant_id, user_id, role, accepted_at) VALUES
  ('00000000-0000-0000-0000-ffffffffffff', '00000000-0000-0000-0000-0000000000aa', 'platform_owner', now()),
  ('00000000-0000-0000-0000-ffffffffffff', '00000000-0000-0000-0000-0000000000bb', 'platform_editor', now())
ON CONFLICT (tenant_id, user_id) DO UPDATE SET role = EXCLUDED.role;

-- ─── Membership: dev tenant ──────────────────────────────────────────────
-- Dev user is also owner of the dev tenant (multi-tenant membership)
-- Tenant admin is admin, viewer is viewer
INSERT INTO tenants.tenant_members (tenant_id, user_id, role, accepted_at) VALUES
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000aa', 'owner', now()),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000cc', 'admin', now()),
  ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000dd', 'viewer', now())
ON CONFLICT (tenant_id, user_id) DO UPDATE SET role = EXCLUDED.role;
