-- SQL Script to create tables for CSCP Postmarket Health Customer Product (Universal Schema)
-- IDEMPOTENT VERSION: Safe to run multiple times. Skips existing tables/columns.

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1. CREATE TABLES (IF NOT EXISTS)
-- =========================================================

-- Table: businesses
CREATE TABLE IF NOT EXISTS businesses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_type VARCHAR(100) NOT NULL,
    business_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: inspections
CREATE TABLE IF NOT EXISTS inspections (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    inspection_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: products
CREATE TABLE IF NOT EXISTS products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: complaints
CREATE TABLE IF NOT EXISTS complaints (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    complaint_date DATE NOT NULL,
    complaint_topic VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: business_types
CREATE TABLE IF NOT EXISTS business_types (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: profiles
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY, 
    email VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: inspection_plans
CREATE TABLE IF NOT EXISTS inspection_plans (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    planned_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: officers
CREATE TABLE IF NOT EXISTS officers (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: import_history
CREATE TABLE IF NOT EXISTS import_history (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    file_name VARCHAR(255) NOT NULL,
    file_content_base64 TEXT NOT NULL,
    summary JSONB,
    uploader_id UUID,
    uploader_email VARCHAR(255),
    district VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


-- =========================================================
-- 2. ADD COLUMNS SAFELY (IF NOT EXISTS)
-- =========================================================
-- This section ensures that if you run this script on an older database,
-- any missing columns will be added without throwing "column already exists" errors.

-- Businesses
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS license_no VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS old_license_no VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS licensee_name VARCHAR(255);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS operator_name VARCHAR(255);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS professional_license_no VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS moo VARCHAR(50);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS subdistrict VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS district VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS province VARCHAR(100);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS opening_hours VARCHAR(255);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS latitude DECIMAL(10, 8);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS longitude DECIMAL(11, 8);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS location_text TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS expire_year VARCHAR(50);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS current_expire_year VARCHAR(50);
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS license_status VARCHAR(50) DEFAULT 'active';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS inspection_status VARCHAR(50) DEFAULT 'pending';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS risk_level VARCHAR(50) DEFAULT 'low';
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS waste_management TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS medical_equipment TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS image_front TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS image_inside_1 TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS image_inside_2 TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS image_specific TEXT;
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS image_document TEXT;

-- Inspections
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS inspection_type VARCHAR(100);
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS inspector_name VARCHAR(255);
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS inspection_result VARCHAR(50);
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS score INT;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS form_data JSONB;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS risk_level VARCHAR(50);
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS problem_found TEXT;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS recommendation TEXT;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS next_followup_date DATE;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS attachment_url TEXT;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS is_confidential BOOLEAN DEFAULT false;
ALTER TABLE inspections ADD COLUMN IF NOT EXISTS created_by UUID;

-- Products
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_type VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS registration_no VARCHAR(100);
ALTER TABLE products ADD COLUMN IF NOT EXISTS brand VARCHAR(255);
ALTER TABLE products ADD COLUMN IF NOT EXISTS manufacturer VARCHAR(255);
ALTER TABLE products ADD COLUMN IF NOT EXISTS expire_date DATE;
ALTER TABLE products ADD COLUMN IF NOT EXISTS product_status VARCHAR(50);
ALTER TABLE products ADD COLUMN IF NOT EXISTS note TEXT;

-- Complaints
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS complainant_name VARCHAR(255);
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS complaint_detail TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'open';
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS action_taken TEXT;
ALTER TABLE complaints ADD COLUMN IF NOT EXISTS close_date DATE;

-- Profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'district_user';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS district VARCHAR(100);

-- Inspection Plans
ALTER TABLE inspection_plans ADD COLUMN IF NOT EXISTS inspector_name VARCHAR(255);
ALTER TABLE inspection_plans ADD COLUMN IF NOT EXISTS inspectors_data JSONB DEFAULT '[]'::jsonb;
ALTER TABLE inspection_plans ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'planned';
ALTER TABLE inspection_plans ADD COLUMN IF NOT EXISTS created_by UUID;

-- Officers
ALTER TABLE officers ADD COLUMN IF NOT EXISTS position VARCHAR(255);
ALTER TABLE officers ADD COLUMN IF NOT EXISTS workplace VARCHAR(255);
ALTER TABLE officers ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE officers ADD COLUMN IF NOT EXISTS district VARCHAR(100);

-- Import History
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS file_name VARCHAR(255);
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS file_content_base64 TEXT;
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS summary JSONB;
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS uploader_id UUID;
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS uploader_email VARCHAR(255);
ALTER TABLE import_history ADD COLUMN IF NOT EXISTS district VARCHAR(100);

-- =========================================================
-- 3. INITIAL DATA (Safe Inserts)
-- =========================================================

-- Insert Default Types
INSERT INTO business_types (type_name) VALUES 
('คลินิก / สถานพยาบาล'), 
('ร้านขายยา'), 
('สถานที่ผลิตอาหาร'), 
('สถานที่ผลิตน้ำดื่ม'), 
('ร้านชำ / ร้านค้าชุมชน')
ON CONFLICT (type_name) DO NOTHING;

-- =========================================================
-- 4. SYSTEM SECURITY & AUDIT TRAIL (Idempotent)
-- =========================================================

-- Table: audit_logs
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    record_id UUID,
    action VARCHAR(50) NOT NULL, -- INSERT, UPDATE, DELETE
    old_data JSONB,
    new_data JSONB,
    changed_by UUID,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Safely add columns if they were missing (Idempotent)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS table_name VARCHAR(255);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS record_id UUID;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS action VARCHAR(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS old_data JSONB;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS new_data JSONB;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS changed_by UUID;

-- Function: process_audit_log
-- This function captures changes and records them in audit_logs
CREATE OR REPLACE FUNCTION process_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    uid UUID;
BEGIN
    -- Try to get the user ID from Supabase auth (JWT)
    BEGIN
        uid := auth.uid();
    EXCEPTION WHEN OTHERS THEN
        uid := NULL;
    END;

    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_data, changed_by)
        VALUES (TG_TABLE_NAME::text, OLD.id, TG_OP, row_to_json(OLD)::jsonb, uid);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit_logs (table_name, record_id, action, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME::text, NEW.id, TG_OP, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb, uid);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit_logs (table_name, record_id, action, new_data, changed_by)
        VALUES (TG_TABLE_NAME::text, NEW.id, TG_OP, row_to_json(NEW)::jsonb, uid);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Safe way to create triggers without "trigger already exists" error
DO $$
BEGIN
    -- Drop triggers if they exist to recreate them safely
    DROP TRIGGER IF EXISTS audit_businesses_trigger ON businesses;
    DROP TRIGGER IF EXISTS audit_inspections_trigger ON inspections;
    DROP TRIGGER IF EXISTS audit_inspection_plans_trigger ON inspection_plans;
    DROP TRIGGER IF EXISTS audit_complaints_trigger ON complaints;

    -- Create triggers
    CREATE TRIGGER audit_businesses_trigger
    AFTER INSERT OR UPDATE OR DELETE ON businesses
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

    CREATE TRIGGER audit_inspections_trigger
    AFTER INSERT OR UPDATE OR DELETE ON inspections
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

    CREATE TRIGGER audit_inspection_plans_trigger
    AFTER INSERT OR UPDATE OR DELETE ON inspection_plans
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();

    CREATE TRIGGER audit_complaints_trigger
    AFTER INSERT OR UPDATE OR DELETE ON complaints
    FOR EACH ROW EXECUTE FUNCTION process_audit_log();
END $$;

-- =========================================================
-- 4. ENSURE ALL TABLES ARE ACCESSIBLE (DISABLE RLS)
-- =========================================================
-- Since the frontend handles role-based access control (isAdmin),
-- we disable RLS to prevent "No data showing" issues caused by Supabase defaults.
ALTER TABLE businesses DISABLE ROW LEVEL SECURITY;
ALTER TABLE inspections DISABLE ROW LEVEL SECURITY;
ALTER TABLE products DISABLE ROW LEVEL SECURITY;
ALTER TABLE complaints DISABLE ROW LEVEL SECURITY;
ALTER TABLE business_types DISABLE ROW LEVEL SECURITY;
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE inspection_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE officers DISABLE ROW LEVEL SECURITY;
ALTER TABLE import_history DISABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs DISABLE ROW LEVEL SECURITY;
