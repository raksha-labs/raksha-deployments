-- Local-only seed so the gRPC ConfigWatch handshake has something
-- to resolve. Without a tenant row the snapshot builder returns nothing
-- but the stream stays open — that's fine for bring-up verification.
--
-- A `free` plan row is needed because tenants.plan_id is a NOT NULL FK.

\c raksha_control

INSERT INTO tenants.plans (plan_id, display_name, is_public, description)
VALUES ('free', 'Free', false, 'Local dev plan')
ON CONFLICT (plan_id) DO NOTHING;

INSERT INTO tenants.tenants (id, display_name, slug, plan_id)
VALUES ('00000000-0000-0000-0000-000000000001', 'Local Dev Tenant', 'local-dev', 'free')
ON CONFLICT (id) DO NOTHING;
