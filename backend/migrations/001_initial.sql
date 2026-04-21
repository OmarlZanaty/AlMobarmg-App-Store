CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('developer', 'user', 'admin');
CREATE TYPE subscription_plan AS ENUM ('free', 'pro', 'studio');
CREATE TYPE app_status AS ENUM ('pending', 'scanning', 'review', 'approved', 'rejected', 'removed');
CREATE TYPE risk_level AS ENUM ('safe', 'low', 'medium', 'high', 'critical');
CREATE TYPE platform AS ENUM ('android', 'ios', 'windows', 'mac', 'linux', 'web');
CREATE TYPE install_source AS ENUM ('store', 'api', 'direct');
CREATE TYPE subscription_status AS ENUM ('active', 'cancelled', 'past_due');
CREATE TYPE fix_rejection_status AS ENUM ('pending_payment', 'processing', 'completed', 'failed');

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'user',
    is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    is_identity_verified BOOLEAN NOT NULL DEFAULT FALSE,
    reputation_score INTEGER NOT NULL DEFAULT 0,
    subscription_plan subscription_plan NOT NULL DEFAULT 'free',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE apps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    package_id VARCHAR(255) UNIQUE NOT NULL CHECK (package_id ~ '^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$'),
    description TEXT NOT NULL,
    category VARCHAR(100) NOT NULL,
    short_description VARCHAR(200) NOT NULL,
    icon_url VARCHAR(1024) NOT NULL,
    screenshots JSONB NOT NULL DEFAULT '[]'::jsonb,
    version VARCHAR(64) NOT NULL,
    status app_status NOT NULL DEFAULT 'pending',
    security_score INTEGER CHECK (security_score BETWEEN 0 AND 100),
    supported_platforms JSONB NOT NULL DEFAULT '[]'::jsonb,
    android_file_url VARCHAR(1024),
    ios_pwa_url VARCHAR(1024),
    windows_file_url VARCHAR(1024),
    mac_file_url VARCHAR(1024),
    linux_deb_url VARCHAR(1024),
    linux_appimage_url VARCHAR(1024),
    linux_rpm_url VARCHAR(1024),
    file_sizes JSONB NOT NULL DEFAULT '{}'::jsonb,
    total_installs INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    published_at TIMESTAMPTZ
);

CREATE TABLE security_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
    risk_level risk_level NOT NULL,
    mobsf_raw JSONB NOT NULL DEFAULT '{}'::jsonb,
    virustotal_raw JSONB NOT NULL DEFAULT '{}'::jsonb,
    ai_summary TEXT NOT NULL,
    ai_developer_report JSONB NOT NULL DEFAULT '{}'::jsonb,
    ai_user_report JSONB NOT NULL DEFAULT '{}'::jsonb,
    dangerous_permissions JSONB NOT NULL DEFAULT '[]'::jsonb,
    suspicious_apis JSONB NOT NULL DEFAULT '[]'::jsonb,
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE installs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    app_id UUID NOT NULL REFERENCES apps(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    platform platform NOT NULL,
    country_code VARCHAR(2),
    install_source install_source NOT NULL,
    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan subscription_plan NOT NULL,
    status subscription_status NOT NULL,
    stripe_customer_id VARCHAR(255),
    stripe_subscription_id VARCHAR(255),
    current_period_end TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE fix_rejection_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    developer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    app_id UUID REFERENCES apps(id) ON DELETE SET NULL,
    rejection_reason TEXT NOT NULL,
    mobsf_findings JSONB NOT NULL DEFAULT '{}'::jsonb,
    ai_diagnosis JSONB NOT NULL DEFAULT '{}'::jsonb,
    stripe_payment_intent_id VARCHAR(255),
    status fix_rejection_status NOT NULL DEFAULT 'pending_payment',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_apps_status ON apps(status);
CREATE INDEX idx_apps_developer_id ON apps(developer_id);
CREATE INDEX idx_apps_category ON apps(category);
CREATE INDEX idx_installs_app_id ON installs(app_id);
CREATE INDEX idx_installs_installed_at ON installs(installed_at);
CREATE INDEX idx_apps_supported_platforms_gin ON apps USING GIN (supported_platforms);
CREATE INDEX idx_apps_search ON apps USING GIN (
    to_tsvector(
        'simple',
        COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(category, '')
    )
);
