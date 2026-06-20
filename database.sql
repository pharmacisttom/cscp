-- SQL Script to create tables for CSCP Postmarket Health Customer Product (Universal Schema)

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Table: businesses
CREATE TABLE businesses (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_type VARCHAR(100) NOT NULL, -- คลินิก, ร้านขายยา, ร้านนวด/สปา, ร้านชำ, อาหาร, น้ำดื่ม, เครื่องสำอาง, อื่นๆ
    business_name VARCHAR(255) NOT NULL,
    license_no VARCHAR(100),
    old_license_no VARCHAR(100),
    licensee_name VARCHAR(255),
    operator_name VARCHAR(255),
    professional_license_no VARCHAR(100),
    address TEXT,
    moo VARCHAR(50),
    subdistrict VARCHAR(100),
    district VARCHAR(100),
    province VARCHAR(100),
    phone VARCHAR(50),
    opening_hours VARCHAR(255),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    location_text TEXT,
    expire_year VARCHAR(50),
    current_expire_year VARCHAR(50),
    license_status VARCHAR(50) DEFAULT 'active', -- active, expired, revoked
    inspection_status VARCHAR(50) DEFAULT 'pending', -- pending, passed, failed, improved
    risk_level VARCHAR(50) DEFAULT 'low', -- low, medium, high
    waste_management TEXT,
    note TEXT,
    medical_equipment TEXT,
    
    -- Universal Image Links (Google Drive URLs)
    image_front TEXT,
    image_inside_1 TEXT,
    image_inside_2 TEXT,
    image_specific TEXT,
    image_document TEXT,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: inspections
CREATE TABLE inspections (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    inspection_date DATE NOT NULL,
    inspection_type VARCHAR(100),
    inspector_name VARCHAR(255),
    inspection_result VARCHAR(50), -- passed, failed, requires_improvement
    score INT,
    form_data JSONB, -- <--- Added to store dynamic form answers
    risk_level VARCHAR(50),
    problem_found TEXT,
    recommendation TEXT,
    next_followup_date DATE,
    attachment_url TEXT,
    is_confidential BOOLEAN DEFAULT false,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: products
CREATE TABLE products (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    product_type VARCHAR(100), -- อาหาร, น้ำดื่ม, ยา, เครื่องสำอาง
    product_name VARCHAR(255) NOT NULL,
    registration_no VARCHAR(100),
    brand VARCHAR(255),
    manufacturer VARCHAR(255),
    expire_date DATE,
    product_status VARCHAR(50), -- active, recalled, expired
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table: complaints
CREATE TABLE complaints (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
    complaint_date DATE NOT NULL,
    complainant_name VARCHAR(255),
    complaint_topic VARCHAR(255) NOT NULL,
    complaint_detail TEXT,
    status VARCHAR(50) DEFAULT 'open', -- open, investigating, resolved, closed
    action_taken TEXT,
    close_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Note: RLS policies can be added depending on the authentication requirements.
-- Example of enabling RLS:
-- ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY "Allow authenticated users full access" ON businesses FOR ALL USING (auth.role() = 'authenticated');

-- =========================================================
-- SYSTEM & USER MANAGEMENT
-- =========================================================

-- Table: business_types (Dynamic types managed by Admin)
CREATE TABLE business_types (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert Default Types
INSERT INTO business_types (type_name) VALUES 
('คลินิก / สถานพยาบาล'), 
('ร้านขายยา'), 
('สถานที่ผลิตอาหาร'), 
('สถานที่ผลิตน้ำดื่ม'), 
('ร้านชำ / ร้านค้าชุมชน')
ON CONFLICT (type_name) DO NOTHING;

-- Table: profiles (User Roles and Permissions)
-- Note: 'id' maps directly to auth.users.id from Supabase
CREATE TABLE profiles (
    id UUID PRIMARY KEY, 
    email VARCHAR(255),
    role VARCHAR(50) DEFAULT 'district_user', -- 'admin' or 'district_user'
    district VARCHAR(100), -- Used to lock visibility for 'district_user'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
