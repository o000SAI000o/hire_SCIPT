-- ============================================================================
-- ATS (Applicant Tracking System) & Interview Automation Platform
-- PostgreSQL Database Schema - UPDATED & VERIFIED
-- ============================================================================
-- Version: 2.0
-- Database: PostgreSQL 14+
-- Features: Multi-tenancy, RBAC, Audit Logging, Soft Deletes, GDPR Compliance
-- ============================================================================
-- CHANGES FROM v1.0:
-- 1. Added missing fields found in mockData.ts
-- 2. Fixed ENUM values to match frontend exactly
-- 3. Added missing relationships between tables
-- 4. Added fields for iMocha integration
-- 5. Corrected job fields (salary display, posted date)
-- 6. Added shareable_link for job applications
-- 7. Fixed assignment types and statuses
-- 8. Added email template categories matching frontend
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For fuzzy text search

-- ============================================================================
-- SECTION 1: ENUMS & TYPES
-- ============================================================================

-- User roles (matching mockData.ts TeamMember interface)
CREATE TYPE user_role AS ENUM (
    'super_admin',      -- Platform administrator (not in frontend yet)
    'org_admin',        -- Organization administrator (Admin in frontend)
    'recruiter',        -- Recruiter role
    'hiring_manager',   -- Hiring manager
    'interviewer',      -- Panel member/Interviewer
    'viewer'            -- Read-only access (Viewer in frontend)
);

-- Job status (matching mockData.ts Job interface)
CREATE TYPE job_status AS ENUM (
    'draft',            -- Draft
    'active',           -- Active
    'on_hold',          -- On Hold
    'closed',           -- Closed
    'archived'          -- Archived (for old jobs)
);

-- Job type (matching mockData.ts)
CREATE TYPE job_type AS ENUM (
    'full_time',        -- Full-time
    'part_time',        -- Part-time
    'contract',         -- Contract
    'internship',       -- Internship
    'temporary'         -- Temporary
);

-- Application/Candidate status (matching mockData.ts Candidate.interviewStage)
CREATE TYPE application_status AS ENUM (
    'applied',              -- Applied
    'screening',            -- Under screening
    'ats_shortlisted',      -- ATS Shortlisted
    'ats_rejected',         -- ATS Rejected
    'assignment_sent',      -- Assignment Sent
    'assignment_submitted', -- Assignment submitted
    'assignment_passed',    -- Assignment Passed
    'assignment_failed',    -- Assignment Failed
    'l1_scheduled',         -- L1 Scheduled
    'l1_completed',         -- L1 Completed
    'l2_scheduled',         -- L2 Scheduled
    'l2_completed',         -- L2 Completed
    'hr_round',             -- HR Round
    'interview_completed',  -- All interviews completed
    'offer_extended',       -- Offer extended
    'offer_accepted',       -- Offer Accepted
    'offer_rejected',       -- Offer Rejected
    'selected',             -- Selected/Hired
    'rejected',             -- Rejected
    'withdrawn'             -- Candidate withdrawn
);

-- Interview round types (matching mockData.ts)
CREATE TYPE interview_round AS ENUM (
    'phone_screen',     -- Phone screening
    'l1',               -- L1 Technical (matching mockData)
    'l2',               -- L2 Technical (matching mockData)
    'hr',               -- HR Round (matching mockData)
    'cultural_fit',     -- Cultural fit
    'final_round'       -- Final round
);

-- Interview status (matching mockData.ts InterviewSlot)
CREATE TYPE interview_status AS ENUM (
    'available',        -- Available (for slots)
    'scheduled',        -- Scheduled
    'in_progress',      -- In Progress
    'completed',        -- Completed
    'rescheduled',      -- Rescheduled
    'cancelled',        -- Cancelled
    'no_show'           -- No Show
);

-- Interview result
CREATE TYPE interview_result AS ENUM (
    'pending',          -- Pending
    'pass',             -- Pass
    'fail',             -- Fail
    'strong_hire',      -- Strong Hire
    'hire',             -- Hire
    'no_hire',          -- No Hire
    'strong_no_hire'    -- Strong No Hire
);

-- Assignment question types (matching mockData and components)
CREATE TYPE question_type AS ENUM (
    'mcq',              -- MCQ (Multiple Choice)
    'coding',           -- Coding
    'explanatory',      -- Explanatory/Essay
    'file_upload',      -- File Upload
    'short_answer'      -- Short Answer
);

-- Assignment status (matching mockData.ts Assignment)
CREATE TYPE assignment_status AS ENUM (
    'draft',            -- Draft
    'active',           -- Active
    'inactive',         -- Inactive
    'archived'          -- Archived
);

-- Assignment type (matching mockData.ts Assignment.type)
CREATE TYPE assignment_type AS ENUM (
    'coding',           -- Coding
    'data_analysis',    -- Data Analysis
    'design',           -- Design
    'case_study',       -- Case Study
    'general'           -- General assessment
);

-- Candidate assignment status (matching mockData.ts Candidate.assignmentStatus)
CREATE TYPE candidate_assignment_status AS ENUM (
    'not_started',      -- Not Started
    'in_progress',      -- In Progress
    'completed',        -- Completed
    'passed',           -- Passed
    'failed'            -- Failed
);

-- Email status
CREATE TYPE email_status AS ENUM (
    'queued',           -- Queued
    'sending',          -- Sending
    'sent',             -- Sent
    'delivered',        -- Delivered
    'opened',           -- Opened
    'clicked',          -- Clicked
    'bounced',          -- Bounced
    'failed',           -- Failed
    'spam'              -- Marked as spam
);

-- Email category (matching emailTemplates.ts)
CREATE TYPE email_category AS ENUM (
    'shortlist',        -- Shortlist notifications
    'reject',           -- Rejection emails
    'assignment',       -- Assignment invitations
    'interview',        -- Interview invitations/reminders
    'offer',            -- Offer letters
    'custom'            -- Custom messages
);

-- File type
CREATE TYPE file_type AS ENUM (
    'resume',           -- Resume/CV
    'cover_letter',     -- Cover Letter
    'assignment_file',  -- Assignment submission
    'offer_letter',     -- Offer letter
    'document',         -- General document
    'other'             -- Other files
);

-- Workflow trigger event
CREATE TYPE workflow_trigger AS ENUM (
    'application_received',     -- When application is submitted
    'ats_score_threshold',      -- When ATS score meets threshold
    'assignment_submitted',     -- When assignment is submitted
    'interview_completed',      -- When interview is completed
    'stage_changed',            -- When stage changes
    'time_based'                -- Time-based trigger
);

-- Workflow action
CREATE TYPE workflow_action AS ENUM (
    'send_email',           -- Send email
    'change_status',        -- Change application status
    'assign_to_user',       -- Assign to user/recruiter
    'create_task',          -- Create task
    'schedule_interview',   -- Schedule interview
    'send_assignment'       -- Send assignment
);

-- ============================================================================
-- SECTION 2: ORGANIZATIONS & MULTI-TENANCY
-- ============================================================================

-- Organizations (Companies using the platform)
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    domain VARCHAR(255), -- Company domain for SSO
    logo_url TEXT,
    website VARCHAR(255),
    industry VARCHAR(100),
    company_size VARCHAR(50),
    
    -- Subscription & billing
    subscription_tier VARCHAR(50) DEFAULT 'free', -- free, starter, professional, enterprise
    subscription_status VARCHAR(50) DEFAULT 'active',
    subscription_start_date TIMESTAMP,
    subscription_end_date TIMESTAMP,
    max_jobs INTEGER DEFAULT 5,
    max_users INTEGER DEFAULT 10,
    max_candidates INTEGER DEFAULT 1000,
    
    -- Contact info
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Settings
    settings JSONB DEFAULT '{}', -- Organization-wide settings
    branding JSONB DEFAULT '{}', -- Custom branding colors, logos
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID
);

-- ============================================================================
-- SECTION 3: USERS & AUTHENTICATION
-- ============================================================================

-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255), -- NULL for SSO users
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED,
    phone VARCHAR(50),
    avatar_url TEXT,
    
    -- Role & permissions (matching mockData.ts TeamMember)
    role user_role DEFAULT 'viewer',
    department VARCHAR(100),
    job_title VARCHAR(100),
    
    -- Team member specific fields
    status VARCHAR(20) DEFAULT 'active', -- active, inactive
    joined_date DATE DEFAULT CURRENT_DATE,
    interviews_conducted INTEGER DEFAULT 0,
    
    -- Authentication
    email_verified BOOLEAN DEFAULT FALSE,
    email_verification_token VARCHAR(255),
    email_verification_sent_at TIMESTAMP,
    last_login_at TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    
    -- Password reset
    password_reset_token VARCHAR(255),
    password_reset_expires_at TIMESTAMP,
    
    -- OAuth/SSO
    oauth_provider VARCHAR(50), -- google, microsoft, linkedin
    oauth_id VARCHAR(255),
    
    -- Security
    two_factor_enabled BOOLEAN DEFAULT FALSE,
    two_factor_secret VARCHAR(255),
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP,
    
    -- Settings
    preferences JSONB DEFAULT '{}', -- User preferences
    notification_settings JSONB DEFAULT '{}',
    
    -- Metadata
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(organization_id, email)
);

-- User sessions for JWT/session management
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    refresh_token_hash VARCHAR(255),
    device_info JSONB, -- Browser, OS, device details
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP NOT NULL,
    last_activity_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(token_hash)
);

-- ============================================================================
-- SECTION 4: ROLES & PERMISSIONS (RBAC)
-- ============================================================================

-- Permissions
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) UNIQUE NOT NULL,
    resource VARCHAR(100) NOT NULL, -- jobs, candidates, interviews, etc.
    action VARCHAR(50) NOT NULL, -- create, read, update, delete, execute
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Role permissions mapping
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role user_role NOT NULL,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(role, permission_id, organization_id)
);

-- User-specific permission overrides
CREATE TABLE user_permission_overrides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    granted BOOLEAN DEFAULT TRUE, -- TRUE = grant, FALSE = revoke
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    UNIQUE(user_id, permission_id)
);

-- Department/team restrictions
CREATE TABLE user_department_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    department VARCHAR(100) NOT NULL,
    can_view BOOLEAN DEFAULT TRUE,
    can_edit BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, department)
);

-- ============================================================================
-- SECTION 5: JOBS
-- ============================================================================

-- Jobs/Job postings (matching mockData.ts Job interface)
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info (matching mockData.ts)
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    department VARCHAR(100),
    location VARCHAR(255),
    job_type job_type DEFAULT 'full_time',
    status job_status DEFAULT 'draft',
    
    -- Job details
    description TEXT,
    requirements TEXT, -- Can store as TEXT or JSONB array
    requirements_array JSONB DEFAULT '[]', -- ["Requirement 1", "Requirement 2"]
    qualifications TEXT,
    benefits TEXT, -- Can store as TEXT or JSONB array
    benefits_array JSONB DEFAULT '[]', -- ["Benefit 1", "Benefit 2"]
    responsibilities TEXT,
    
    -- Compensation (matching mockData - note: using salary instead of salary_min/max)
    salary_min DECIMAL(12, 2),
    salary_max DECIMAL(12, 2),
    salary_currency VARCHAR(10) DEFAULT 'USD',
    salary_display VARCHAR(100), -- e.g., "$120k - $180k" or "₹10L - ₹12L"
    
    -- Requirements
    experience_min INTEGER, -- years
    experience_max INTEGER,
    education_level VARCHAR(100),
    skills JSONB DEFAULT '[]', -- Array of required skills
    required_skills JSONB DEFAULT '[]', -- Specific required skills for ATS matching
    
    -- Application settings
    application_deadline TIMESTAMP,
    max_applicants INTEGER,
    remote_allowed BOOLEAN DEFAULT FALSE,
    visa_sponsorship BOOLEAN DEFAULT FALSE,
    
    -- Shareable link (matching mockData.ts)
    shareable_link TEXT, -- Public URL for job application
    
    -- ATS Configuration (matching mockData.ts atsConfiguration)
    ats_enabled BOOLEAN DEFAULT TRUE,
    ats_pass_threshold INTEGER DEFAULT 70, -- threshold in mockData
    ats_keywords JSONB DEFAULT '[]', -- Keywords for ATS scoring
    ats_weights JSONB DEFAULT '{}', -- Custom weight configuration
    ats_configuration JSONB DEFAULT '{}', -- Full config: {skillWeightage, educationWeightage, projectWeightage, threshold}
    
    -- Assignment
    assignment_id UUID, -- Will reference assignments table
    assignment_required BOOLEAN DEFAULT FALSE,
    assignment_pass_threshold INTEGER DEFAULT 60,
    
    -- Interview configuration (matching mockData.ts interviewRounds)
    interview_rounds JSONB DEFAULT '{}', -- {l1Enabled: true, l2Enabled: true, hrEnabled: true}
    
    -- Pipeline stages
    pipeline_stages JSONB DEFAULT '[]', -- Custom pipeline stages for this job
    
    -- SEO & sharing
    meta_title VARCHAR(255),
    meta_description TEXT,
    share_image_url TEXT,
    
    -- Owner & team
    hiring_manager_id UUID REFERENCES users(id),
    recruiter_id UUID REFERENCES users(id),
    
    -- Stats (denormalized for performance - matching mockData.ts)
    total_applicants INTEGER DEFAULT 0, -- totalApplicants
    ats_shortlisted INTEGER DEFAULT 0, -- atsShortlisted
    assignment_qualified INTEGER DEFAULT 0, -- assignmentQualified
    interviews_scheduled INTEGER DEFAULT 0, -- interviewsScheduled
    final_selections INTEGER DEFAULT 0, -- finalSelections
    pending_review INTEGER DEFAULT 0,
    shortlisted INTEGER DEFAULT 0,
    rejected INTEGER DEFAULT 0,
    hired INTEGER DEFAULT 0,
    
    -- Metadata
    is_published BOOLEAN DEFAULT FALSE,
    published_at TIMESTAMP,
    posted_date DATE, -- For display "Posted X days ago"
    closed_at TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    
    UNIQUE(organization_id, slug)
);

-- Job custom fields (dynamic fields per job)
CREATE TABLE job_custom_fields (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    field_name VARCHAR(100) NOT NULL,
    field_type VARCHAR(50) NOT NULL, -- text, number, date, boolean, select
    field_options JSONB, -- For select/dropdown fields
    is_required BOOLEAN DEFAULT FALSE,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Job boards (where job is posted)
CREATE TABLE job_boards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    board_name VARCHAR(100) NOT NULL, -- Indeed, LinkedIn, etc.
    external_job_id VARCHAR(255),
    post_url TEXT,
    posted_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 6: CANDIDATES & APPLICATIONS
-- ============================================================================

-- Candidates (people who apply - matching mockData.ts Candidate interface)
CREATE TABLE candidates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Personal info (matching mockData.ts required fields)
    email VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    full_name VARCHAR(255) GENERATED ALWAYS AS (
        CASE 
            WHEN first_name IS NOT NULL AND last_name IS NOT NULL 
            THEN first_name || ' ' || last_name
            ELSE COALESCE(first_name, '') || COALESCE(last_name, '')
        END
    ) STORED,
    name VARCHAR(255), -- For cases where we store full name directly
    phone VARCHAR(50),
    
    -- Education (matching mockData.ts)
    college VARCHAR(255), -- college in mockData
    degree VARCHAR(100), -- degree in mockData
    graduation_year INTEGER, -- graduationYear in mockData
    highest_education VARCHAR(100),
    
    -- Professional info
    current_company VARCHAR(255),
    current_title VARCHAR(255),
    total_experience INTEGER, -- years
    experience TEXT, -- experience field in mockData (can be detailed text)
    
    -- Skills (matching mockData.ts)
    skills JSONB DEFAULT '[]', -- Array of skills
    
    -- Links (matching mockData.ts optional fields)
    linkedin_url TEXT, -- linkedIn in mockData
    portfolio_url TEXT, -- portfolio in mockData
    github_url TEXT, -- github in mockData
    website_url TEXT,
    
    -- Projects (matching mockData.ts)
    projects TEXT, -- projects field in mockData
    
    -- Resume (matching mockData.ts)
    resume_url TEXT, -- resume in mockData
    
    -- Location
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    postal_code VARCHAR(20),
    willing_to_relocate BOOLEAN DEFAULT FALSE,
    
    -- Source tracking
    source VARCHAR(100), -- job_board, referral, website, linkedin
    source_details VARCHAR(255),
    utm_source VARCHAR(100),
    utm_medium VARCHAR(100),
    utm_campaign VARCHAR(100),
    
    -- GDPR & consent
    gdpr_consent BOOLEAN DEFAULT FALSE,
    gdpr_consent_date TIMESTAMP,
    gdpr_consent_ip INET,
    marketing_consent BOOLEAN DEFAULT FALSE,
    data_retention_until TIMESTAMP,
    
    -- Blacklist
    is_blacklisted BOOLEAN DEFAULT FALSE,
    blacklist_reason TEXT,
    blacklisted_at TIMESTAMP,
    blacklisted_by UUID REFERENCES users(id),
    
    -- Metadata
    notes TEXT,
    tags JSONB DEFAULT '[]',
    custom_fields JSONB DEFAULT '{}',
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(organization_id, email)
);

-- Job applications (matching mockData.ts Candidate fields)
CREATE TABLE applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Application data
    status application_status DEFAULT 'applied',
    current_stage VARCHAR(100), -- Custom pipeline stage name
    interview_stage application_status, -- interviewStage in mockData
    cover_letter TEXT,
    custom_responses JSONB DEFAULT '{}', -- Answers to custom questions
    
    -- Applied date (matching mockData.ts)
    applied_date DATE DEFAULT CURRENT_DATE, -- appliedDate in mockData
    
    -- ATS Scoring (matching mockData.ts)
    ats_score INTEGER, -- atsScore (0-100)
    skills_match INTEGER, -- skillsMatch
    education_score INTEGER, -- educationScore
    project_score INTEGER, -- projectScore
    ats_scores_breakdown JSONB, -- Detailed scoring by category
    ats_matched_keywords JSONB DEFAULT '[]',
    ats_missing_keywords JSONB DEFAULT '[]',
    ats_processed BOOLEAN DEFAULT FALSE,
    ats_processed_at TIMESTAMP,
    
    -- Assignment tracking (matching mockData.ts)
    assignment_status candidate_assignment_status DEFAULT 'not_started', -- assignmentStatus
    assignment_score DECIMAL(5, 2), -- assignmentScore (can be null)
    assignment_sent_at TIMESTAMP,
    assignment_started_at TIMESTAMP,
    assignment_submitted_at TIMESTAMP,
    assignment_passed BOOLEAN,
    assignment_graded_at TIMESTAMP,
    assignment_graded_by UUID REFERENCES users(id),
    
    -- Interview feedback (matching mockData.ts)
    l1_feedback TEXT, -- l1Feedback
    l2_feedback TEXT, -- l2Feedback
    
    -- Interview tracking
    interview_rounds_completed INTEGER DEFAULT 0,
    last_interview_date TIMESTAMP,
    overall_interview_score DECIMAL(5, 2),
    
    -- Offer tracking
    offer_extended_at TIMESTAMP,
    offer_amount DECIMAL(12, 2),
    offer_accepted_at TIMESTAMP,
    offer_rejected_at TIMESTAMP,
    offer_rejection_reason TEXT,
    
    -- Assignment
    assigned_to UUID REFERENCES users(id),
    assigned_at TIMESTAMP,
    
    -- Stage history
    stage_entered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    time_in_current_stage INTERVAL, -- Calculated field
    
    -- Rejection
    rejected_at TIMESTAMP,
    rejection_reason TEXT,
    rejected_by UUID REFERENCES users(id),
    
    -- Ratings
    overall_rating DECIMAL(3, 2), -- 1-5 stars
    culture_fit_score INTEGER, -- 1-10
    technical_score INTEGER, -- 1-10
    
    -- Metadata
    notes TEXT,
    flags JSONB DEFAULT '[]', -- red_flag, star_candidate, etc.
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(job_id, candidate_id)
);

-- Application stage history (audit trail)
CREATE TABLE application_stage_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    from_stage VARCHAR(100),
    to_stage VARCHAR(100) NOT NULL,
    from_status application_status,
    to_status application_status NOT NULL,
    reason TEXT,
    notes TEXT,
    duration_in_previous_stage INTERVAL,
    changed_by UUID REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Application notes/comments
CREATE TABLE application_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    note TEXT NOT NULL,
    is_internal BOOLEAN DEFAULT TRUE, -- Internal vs shared with candidate
    mentioned_users UUID[], -- @mentions
    attachments JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Application ratings/reviews
CREATE TABLE application_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    reviewer_id UUID NOT NULL REFERENCES users(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review_type VARCHAR(50), -- ats_review, assignment_review, interview_review
    strengths TEXT,
    weaknesses TEXT,
    recommendation VARCHAR(50), -- strong_yes, yes, maybe, no, strong_no
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(application_id, reviewer_id, review_type)
);

-- ============================================================================
-- SECTION 7: FILES & DOCUMENTS
-- ============================================================================

-- Files (resumes, cover letters, etc.)
CREATE TABLE files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- File info
    file_name VARCHAR(255) NOT NULL,
    file_type file_type NOT NULL,
    mime_type VARCHAR(100),
    file_size BIGINT, -- bytes
    
    -- Storage (use one of these approaches)
    storage_provider VARCHAR(50) DEFAULT 's3', -- s3, azure, gcs, local
    storage_path TEXT NOT NULL, -- S3 key or file path
    storage_url TEXT, -- Public/signed URL
    storage_bucket VARCHAR(255),
    
    -- Alternative: Store binary data in DB (not recommended for large files)
    -- file_data BYTEA,
    
    -- Parsed data (for resumes)
    parsed_text TEXT, -- Extracted text for search
    parsed_data JSONB, -- Structured data from parsing
    
    -- Associations
    candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE,
    application_id UUID REFERENCES applications(id) ON DELETE CASCADE,
    uploaded_by UUID REFERENCES users(id),
    
    -- Security
    is_public BOOLEAN DEFAULT FALSE,
    access_token VARCHAR(255), -- For secure access
    expires_at TIMESTAMP,
    
    -- Virus scanning
    scanned BOOLEAN DEFAULT FALSE,
    scan_result VARCHAR(50), -- clean, infected, error
    scanned_at TIMESTAMP,
    
    -- Metadata
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- File versions (if versioning is needed)
CREATE TABLE file_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES files(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    storage_path TEXT NOT NULL,
    file_size BIGINT,
    uploaded_by UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(file_id, version_number)
);

-- ============================================================================
-- SECTION 8: ASSIGNMENTS/TESTS
-- ============================================================================

-- Assignment templates (matching mockData.ts Assignment interface)
CREATE TABLE assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info (matching mockData.ts)
    title VARCHAR(255) NOT NULL, -- title
    role VARCHAR(255), -- role
    assignment_type assignment_type DEFAULT 'coding', -- type: 'Coding' | 'Data Analysis' | 'Design' | 'Case Study'
    description TEXT, -- description
    instructions TEXT, -- instructions
    status assignment_status DEFAULT 'draft', -- status: 'Active' | 'Draft'
    
    -- Configuration (matching mockData.ts)
    duration INTEGER, -- duration in minutes
    total_questions INTEGER DEFAULT 0, -- totalQuestions
    passing_score INTEGER DEFAULT 60, -- passingScore
    time_limit INTEGER, -- minutes (NULL = no limit)
    pass_threshold INTEGER DEFAULT 60, -- percentage
    max_attempts INTEGER DEFAULT 1,
    randomize_questions BOOLEAN DEFAULT FALSE,
    show_results_immediately BOOLEAN DEFAULT FALSE,
    allow_backtracking BOOLEAN DEFAULT TRUE,
    
    -- iMocha integration (matching mockData.ts)
    imocha_test_link TEXT, -- imochaTestLink
    external_test_id VARCHAR(255), -- For external test platforms
    
    -- Proctoring
    proctoring_enabled BOOLEAN DEFAULT FALSE,
    require_webcam BOOLEAN DEFAULT FALSE,
    require_screen_recording BOOLEAN DEFAULT FALSE,
    detect_tab_switching BOOLEAN DEFAULT FALSE,
    
    -- Grading
    auto_grade BOOLEAN DEFAULT TRUE,
    manual_review_required BOOLEAN DEFAULT FALSE,
    
    -- Stats (matching mockData.ts)
    assigned_count INTEGER DEFAULT 0, -- assignedCount
    completed_count INTEGER DEFAULT 0, -- completedCount
    passed_count INTEGER DEFAULT 0, -- passedCount
    average_score DECIMAL(5, 2) DEFAULT 0, -- averageScore
    times_assigned INTEGER DEFAULT 0,
    times_completed INTEGER DEFAULT 0,
    
    -- Metadata
    tags JSONB DEFAULT '[]',
    is_deleted BOOLEAN DEFAULT FALSE,
    deleted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id)
);

-- Assignment questions (matching component Question interface)
CREATE TABLE assignment_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignment_id UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    
    -- Question details
    question_type question_type NOT NULL, -- 'MCQ' | 'Coding' | 'Explanatory'
    question_text TEXT NOT NULL,
    question_order INTEGER NOT NULL,
    points DECIMAL(6, 2) DEFAULT 1,
    
    -- MCQ options
    options JSONB, -- For multiple choice: [{"id": "a", "text": "Option A", "is_correct": true}, ...]
    correct_option VARCHAR(10), -- For MCQ: "a", "b", "c", "d"
    
    -- Coding questions
    programming_language VARCHAR(50), -- python, javascript, java, etc.
    starter_code TEXT,
    test_cases JSONB, -- [{"input": "...", "expected_output": "...", "points": 5}, ...]
    time_limit INTEGER, -- seconds for code execution
    memory_limit INTEGER, -- MB
    
    -- File upload
    allowed_file_types VARCHAR(255), -- .pdf,.doc,.zip
    max_file_size INTEGER, -- MB
    
    -- Essay/short answer
    min_words INTEGER,
    max_words INTEGER,
    expected_answer TEXT, -- For explanatory questions
    
    -- Evaluation
    auto_gradable BOOLEAN DEFAULT FALSE,
    correct_answer TEXT, -- For auto-grading
    grading_rubric TEXT,
    sample_answer TEXT,
    
    -- Metadata
    difficulty VARCHAR(50), -- easy, medium, hard
    tags JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Candidate assignment attempts
CREATE TABLE candidate_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_id UUID NOT NULL REFERENCES applications(id) ON DELETE CASCADE,
    assignment_id UUID NOT NULL REFERENCES assignments(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- Status
    status candidate_assignment_status DEFAULT 'not_started',
    attempt_number INTEGER DEFAULT 1,
    
    -- Access
    access_token VARCHAR(255) UNIQUE, -- For public access link
    access_code VARCHAR(20), -- Optional PIN
    ip_address INET,
    
    -- Timing
    started_at TIMESTAMP,
    submitted_at TIMESTAMP,
    time_spent INTEGER, -- seconds
    time_remaining INTEGER, -- seconds
    deadline TIMESTAMP,
    
    -- Proctoring data
    proctoring_events JSONB DEFAULT '[]', -- Tab switches, suspicious activity
    webcam_snapshots JSONB DEFAULT '[]', -- URLs to stored snapshots
    screen_recordings JSONB DEFAULT '[]',
    flagged_for_review BOOLEAN DEFAULT FALSE,
    
    -- Scoring
    total_score DECIMAL(6, 2),
    max_possible_score DECIMAL(6, 2),
    percentage_score DECIMAL(5, 2),
    passed BOOLEAN,
    
    -- Grading
    auto_graded BOOLEAN DEFAULT FALSE,
    manually_graded BOOLEAN DEFAULT FALSE,
    graded_by UUID REFERENCES users(id),
    graded_at TIMESTAMP,
    grader_notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(application_id, assignment_id, attempt_number)
);

-- Candidate answers to questions
CREATE TABLE candidate_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    candidate_assignment_id UUID NOT NULL REFERENCES candidate_assignments(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES assignment_questions(id) ON DELETE CASCADE,
    
    -- Answer data
    answer_text TEXT,
    selected_option VARCHAR(10), -- For MCQ: "a", "b", "c", "d"
    selected_option_id VARCHAR(10), -- For MCQ
    code_submission TEXT, -- For coding questions
    file_id UUID REFERENCES files(id), -- For file uploads
    
    -- Timing
    time_spent INTEGER, -- seconds on this question
    answered_at TIMESTAMP,
    
    -- Scoring
    points_earned DECIMAL(6, 2),
    max_points DECIMAL(6, 2),
    is_correct BOOLEAN,
    
    -- Code execution results (for coding questions)
    execution_results JSONB, -- Test case results
    compilation_error TEXT,
    runtime_error TEXT,
    execution_time INTEGER, -- milliseconds
    memory_used INTEGER, -- KB
    
    -- Manual grading
    manually_graded BOOLEAN DEFAULT FALSE,
    grader_feedback TEXT,
    graded_by UUID REFERENCES users(id),
    graded_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(candidate_assignment_id, question_id)
);

-- Add foreign key to jobs table for assignment
ALTER TABLE jobs ADD CONSTRAINT fk_jobs_assignment 
    FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE SET NULL;

-- ============================================================================
-- SECTION 9: INTERVIEWS
-- ============================================================================

-- Interview slots/schedules (matching mockData.ts InterviewSlot interface)
CREATE TABLE interviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    application_id UUID REFERENCES applications(id) ON DELETE CASCADE, -- Can be NULL for available slots
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE, -- candidateId in mockData (can be NULL)
    
    -- Interview details
    round interview_round NOT NULL, -- 'L1' | 'L2' | 'HR'
    round_number INTEGER DEFAULT 1,
    title VARCHAR(255),
    description TEXT,
    
    -- Scheduling (matching mockData.ts)
    date DATE NOT NULL, -- date in mockData
    time TIME NOT NULL, -- time in mockData
    scheduled_date DATE NOT NULL, -- For consistency
    scheduled_time TIME NOT NULL,
    scheduled_datetime TIMESTAMP GENERATED ALWAYS AS (scheduled_date + scheduled_time) STORED,
    duration INTEGER DEFAULT 60, -- duration in minutes
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Location/meeting (matching mockData.ts)
    location VARCHAR(255), -- location in mockData
    location_type VARCHAR(50) DEFAULT 'video', -- video, in_person, phone
    meeting_link TEXT,
    meeting_id VARCHAR(100),
    meeting_password VARCHAR(100),
    
    -- Panel member (matching mockData.ts)
    panel_member VARCHAR(255), -- panelMember in mockData (stored as name)
    primary_interviewer_id UUID REFERENCES users(id),
    
    -- Status (matching mockData.ts)
    status interview_status DEFAULT 'scheduled', -- 'Available' | 'Scheduled' | 'Completed'
    result interview_result DEFAULT 'pending',
    
    -- Calendar integration
    google_calendar_event_id VARCHAR(255),
    outlook_calendar_event_id VARCHAR(255),
    ical_uid VARCHAR(255),
    
    -- Feedback
    overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5),
    recommendation VARCHAR(50), -- strong_hire, hire, no_hire, strong_no_hire
    strengths TEXT,
    weaknesses TEXT,
    detailed_feedback TEXT,
    
    -- Scores
    technical_score INTEGER CHECK (technical_score >= 1 AND technical_score <= 10),
    communication_score INTEGER CHECK (communication_score >= 1 AND communication_score <= 10),
    problem_solving_score INTEGER CHECK (problem_solving_score >= 1 AND problem_solving_score <= 10),
    culture_fit_score INTEGER CHECK (culture_fit_score >= 1 AND culture_fit_score <= 10),
    
    -- Recording
    recording_url TEXT,
    recording_consent BOOLEAN DEFAULT FALSE,
    
    -- Completion
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    actual_duration INTEGER, -- minutes
    
    -- Rescheduling
    reschedule_count INTEGER DEFAULT 0,
    rescheduled_from UUID REFERENCES interviews(id),
    reschedule_reason TEXT,
    
    -- Cancellation
    cancelled_at TIMESTAMP,
    cancelled_by UUID REFERENCES users(id),
    cancellation_reason TEXT,
    
    -- No-show
    candidate_no_show BOOLEAN DEFAULT FALSE,
    interviewer_no_show BOOLEAN DEFAULT FALSE,
    
    -- Reminders
    reminder_sent_candidate BOOLEAN DEFAULT FALSE,
    reminder_sent_interviewer BOOLEAN DEFAULT FALSE,
    reminder_sent_at TIMESTAMP,
    
    -- Metadata
    notes TEXT,
    attachments JSONB DEFAULT '[]',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Interview panel members (multiple interviewers)
CREATE TABLE interview_panel (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    interview_id UUID NOT NULL REFERENCES interviews(id) ON DELETE CASCADE,
    interviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(100), -- lead, technical_evaluator, observer
    
    -- Individual feedback
    feedback TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    recommendation VARCHAR(50),
    
    -- Attendance
    confirmed BOOLEAN DEFAULT FALSE,
    attended BOOLEAN DEFAULT FALSE,
    
    -- Feedback submission
    feedback_submitted BOOLEAN DEFAULT FALSE,
    feedback_submitted_at TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(interview_id, interviewer_id)
);

-- Interview evaluation criteria/scorecard
CREATE TABLE interview_criteria (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(100), -- technical, behavioral, cultural
    rating_scale INTEGER DEFAULT 5, -- 1-5 or 1-10
    weight DECIMAL(5, 2) DEFAULT 1.0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Interview scores per criteria
CREATE TABLE interview_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    interview_id UUID NOT NULL REFERENCES interviews(id) ON DELETE CASCADE,
    interviewer_id UUID NOT NULL REFERENCES users(id),
    criteria_id UUID NOT NULL REFERENCES interview_criteria(id) ON DELETE CASCADE,
    score INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(interview_id, interviewer_id, criteria_id)
);

-- Interview availability (for scheduling)
CREATE TABLE interviewer_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    interviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Recurring availability
    day_of_week INTEGER CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Or specific date range
    available_from TIMESTAMP,
    available_until TIMESTAMP,
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Interview time-off/blocked slots
CREATE TABLE interviewer_time_off (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    interviewer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_datetime TIMESTAMP NOT NULL,
    end_datetime TIMESTAMP NOT NULL,
    reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 10: EMAIL SYSTEM
-- ============================================================================

-- Email templates (matching emailTemplates.ts EmailTemplate interface)
CREATE TABLE email_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Template info (matching emailTemplates.ts)
    name VARCHAR(255) NOT NULL, -- name
    category email_category NOT NULL, -- category: 'shortlist' | 'reject' | 'assignment' | 'interview' | 'offer' | 'custom'
    subject VARCHAR(500) NOT NULL, -- subject
    body TEXT NOT NULL, -- body (can be HTML)
    body_html TEXT, -- HTML version
    body_text TEXT, -- Plain text version
    description TEXT, -- description
    
    -- Variables available in template (matching emailTemplates.ts)
    available_variables JSONB DEFAULT '[]', -- variables: string[]
    
    -- Settings
    from_name VARCHAR(255),
    from_email VARCHAR(255),
    reply_to VARCHAR(255),
    cc_emails VARCHAR(500),
    bcc_emails VARCHAR(500),
    
    -- Attachments
    default_attachments JSONB DEFAULT '[]',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_default BOOLEAN DEFAULT FALSE, -- Default template for this category
    
    -- Metadata
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id),
    
    UNIQUE(organization_id, name)
);

-- Email queue (for sending emails)
CREATE TABLE email_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Email details
    template_id UUID REFERENCES email_templates(id) ON DELETE SET NULL,
    category email_category,
    
    -- Recipient
    to_email VARCHAR(255) NOT NULL,
    to_name VARCHAR(255),
    cc_emails VARCHAR(500),
    bcc_emails VARCHAR(500),
    
    -- Content
    from_email VARCHAR(255) NOT NULL,
    from_name VARCHAR(255),
    reply_to VARCHAR(255),
    subject VARCHAR(500) NOT NULL,
    body_html TEXT NOT NULL,
    body_text TEXT,
    
    -- Variables used
    template_variables JSONB DEFAULT '{}',
    
    -- Attachments
    attachments JSONB DEFAULT '[]', -- [{file_id: "...", filename: "..."}]
    
    -- Related entities
    candidate_id UUID REFERENCES candidates(id) ON DELETE SET NULL,
    application_id UUID REFERENCES applications(id) ON DELETE SET NULL,
    interview_id UUID REFERENCES interviews(id) ON DELETE SET NULL,
    
    -- Sending
    status email_status DEFAULT 'queued',
    priority INTEGER DEFAULT 5, -- 1=highest, 10=lowest
    scheduled_for TIMESTAMP, -- For delayed sending
    
    -- External email service
    provider VARCHAR(50) DEFAULT 'sendgrid', -- sendgrid, ses, mailgun
    external_message_id VARCHAR(255),
    
    -- Delivery tracking
    sent_at TIMESTAMP,
    delivered_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    bounced_at TIMESTAMP,
    bounce_reason TEXT,
    failed_at TIMESTAMP,
    failure_reason TEXT,
    
    -- Retry logic
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    next_retry_at TIMESTAMP,
    
    -- Tracking
    tracking_pixel_enabled BOOLEAN DEFAULT TRUE,
    click_tracking_enabled BOOLEAN DEFAULT TRUE,
    open_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Email events (opens, clicks, bounces)
CREATE TABLE email_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email_queue_id UUID NOT NULL REFERENCES email_queue(id) ON DELETE CASCADE,
    
    event_type VARCHAR(50) NOT NULL, -- opened, clicked, bounced, complained
    event_data JSONB,
    
    -- Tracking
    ip_address INET,
    user_agent TEXT,
    clicked_url TEXT,
    
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Email unsubscribe list
CREATE TABLE email_unsubscribes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    candidate_id UUID REFERENCES candidates(id),
    
    -- Unsubscribe details
    unsubscribed_from VARCHAR(100), -- all, marketing, transactional
    reason TEXT,
    unsubscribed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    
    UNIQUE(organization_id, email, unsubscribed_from)
);

-- ============================================================================
-- SECTION 11: WORKFLOW AUTOMATION
-- ============================================================================

-- Workflow rules
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Trigger
    trigger_event workflow_trigger NOT NULL,
    trigger_conditions JSONB DEFAULT '{}', -- Conditions to match
    
    -- Filters
    applies_to_jobs UUID[], -- Specific jobs or NULL for all
    applies_to_departments VARCHAR(100)[],
    
    -- Actions
    actions JSONB NOT NULL, -- Array of actions to perform
    
    -- Scheduling
    delay_minutes INTEGER DEFAULT 0, -- Delay before executing
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    priority INTEGER DEFAULT 5,
    
    -- Stats
    execution_count INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    failure_count INTEGER DEFAULT 0,
    last_executed_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Workflow execution log
CREATE TABLE workflow_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    
    -- Trigger context
    triggered_by_event workflow_trigger,
    triggered_entity_type VARCHAR(50), -- application, interview, etc.
    triggered_entity_id UUID,
    
    -- Execution
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'running', -- running, completed, failed
    
    -- Actions performed
    actions_executed JSONB DEFAULT '[]',
    actions_failed JSONB DEFAULT '[]',
    
    -- Results
    success BOOLEAN,
    error_message TEXT,
    execution_log TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'
);

-- ============================================================================
-- SECTION 12: NOTIFICATIONS
-- ============================================================================

-- In-app notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Notification content
    type VARCHAR(100) NOT NULL, -- new_application, interview_scheduled, etc.
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    
    -- Action
    action_url TEXT, -- Link to relevant page
    action_text VARCHAR(100), -- Button text
    
    -- Related entity
    related_entity_type VARCHAR(50),
    related_entity_id UUID,
    
    -- Status
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- Priority
    priority VARCHAR(50) DEFAULT 'normal', -- low, normal, high, urgent
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification preferences
CREATE TABLE notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    notification_type VARCHAR(100) NOT NULL,
    
    -- Channels
    email_enabled BOOLEAN DEFAULT TRUE,
    in_app_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT FALSE,
    push_enabled BOOLEAN DEFAULT FALSE,
    
    -- Frequency
    frequency VARCHAR(50) DEFAULT 'immediate', -- immediate, daily_digest, weekly_digest
    
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(user_id, notification_type)
);

-- ============================================================================
-- SECTION 13: ANALYTICS & REPORTING
-- ============================================================================

-- Pre-aggregated metrics for dashboards
CREATE TABLE analytics_daily (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Application metrics
    applications_received INTEGER DEFAULT 0,
    applications_shortlisted INTEGER DEFAULT 0,
    applications_rejected INTEGER DEFAULT 0,
    
    -- ATS metrics
    avg_ats_score DECIMAL(5, 2),
    ats_pass_rate DECIMAL(5, 2),
    
    -- Assignment metrics
    assignments_sent INTEGER DEFAULT 0,
    assignments_completed INTEGER DEFAULT 0,
    assignments_passed INTEGER DEFAULT 0,
    avg_assignment_score DECIMAL(5, 2),
    
    -- Interview metrics
    interviews_scheduled INTEGER DEFAULT 0,
    interviews_completed INTEGER DEFAULT 0,
    interviews_cancelled INTEGER DEFAULT 0,
    avg_interview_rating DECIMAL(3, 2),
    
    -- Offer metrics
    offers_extended INTEGER DEFAULT 0,
    offers_accepted INTEGER DEFAULT 0,
    offers_rejected INTEGER DEFAULT 0,
    offer_acceptance_rate DECIMAL(5, 2),
    
    -- Hiring metrics
    candidates_hired INTEGER DEFAULT 0,
    
    -- Time metrics
    avg_time_to_hire DECIMAL(10, 2), -- days
    avg_time_to_shortlist DECIMAL(10, 2), -- days
    avg_time_to_interview DECIMAL(10, 2), -- days
    
    -- Source metrics
    source_breakdown JSONB DEFAULT '{}', -- Applications by source
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(organization_id, date)
);

-- Job-specific analytics
CREATE TABLE analytics_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Application funnel
    total_views INTEGER DEFAULT 0,
    total_applications INTEGER DEFAULT 0,
    conversion_rate DECIMAL(5, 2),
    
    -- Stage breakdown
    stage_breakdown JSONB DEFAULT '{}',
    
    -- Time in stages
    avg_time_in_stages JSONB DEFAULT '{}',
    
    -- Quality metrics
    avg_candidate_quality DECIMAL(5, 2),
    quality_score_distribution JSONB DEFAULT '{}',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(job_id, date)
);

-- Recruiter performance metrics
CREATE TABLE analytics_recruiters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    recruiter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    
    -- Activity metrics
    jobs_managed INTEGER DEFAULT 0,
    applications_reviewed INTEGER DEFAULT 0,
    candidates_shortlisted INTEGER DEFAULT 0,
    interviews_scheduled INTEGER DEFAULT 0,
    offers_made INTEGER DEFAULT 0,
    hires_completed INTEGER DEFAULT 0,
    
    -- Quality metrics
    avg_time_to_hire DECIMAL(10, 2),
    offer_acceptance_rate DECIMAL(5, 2),
    candidate_satisfaction_score DECIMAL(5, 2),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(organization_id, recruiter_id, date)
);

-- ============================================================================
-- SECTION 14: AUDIT LOGS
-- ============================================================================

-- Comprehensive audit trail
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Actor
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    user_email VARCHAR(255),
    user_name VARCHAR(255),
    user_role user_role,
    
    -- Action
    action VARCHAR(100) NOT NULL, -- created, updated, deleted, viewed, exported, etc.
    entity_type VARCHAR(100) NOT NULL, -- job, application, candidate, etc.
    entity_id UUID,
    entity_name VARCHAR(255),
    
    -- Changes
    old_values JSONB,
    new_values JSONB,
    changed_fields VARCHAR(100)[],
    
    -- Context
    description TEXT,
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100),
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 15: GDPR & COMPLIANCE
-- ============================================================================

-- Data access requests (GDPR)
CREATE TABLE data_access_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    candidate_id UUID REFERENCES candidates(id) ON DELETE SET NULL,
    
    -- Request details
    request_type VARCHAR(50) NOT NULL, -- access, export, deletion, rectification
    requester_email VARCHAR(255) NOT NULL,
    requester_name VARCHAR(255),
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending', -- pending, in_progress, completed, rejected
    
    -- Processing
    assigned_to UUID REFERENCES users(id),
    completed_at TIMESTAMP,
    completion_notes TEXT,
    
    -- Export data
    export_file_id UUID REFERENCES files(id),
    export_generated_at TIMESTAMP,
    
    -- Deletion
    data_deleted_at TIMESTAMP,
    deleted_by UUID REFERENCES users(id),
    
    -- Verification
    verification_token VARCHAR(255),
    verified_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Data retention policies
CREATE TABLE data_retention_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    entity_type VARCHAR(100) NOT NULL, -- candidates, applications, files
    retention_period_days INTEGER NOT NULL,
    auto_delete BOOLEAN DEFAULT FALSE,
    
    -- Conditions
    applies_when JSONB DEFAULT '{}', -- Conditions when policy applies
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Consent tracking
CREATE TABLE consent_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    candidate_id UUID NOT NULL REFERENCES candidates(id) ON DELETE CASCADE,
    
    consent_type VARCHAR(100) NOT NULL, -- data_processing, marketing, communication
    consented BOOLEAN NOT NULL,
    consent_text TEXT, -- Exact text shown to candidate
    version VARCHAR(50), -- Version of consent form
    
    -- Context
    ip_address INET,
    user_agent TEXT,
    
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- ============================================================================
-- SECTION 16: TASKS & REMINDERS
-- ============================================================================

-- Tasks for recruiters/team
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Task details
    title VARCHAR(255) NOT NULL,
    description TEXT,
    task_type VARCHAR(100), -- review_application, schedule_interview, send_offer
    priority VARCHAR(50) DEFAULT 'normal',
    
    -- Assignment
    assigned_to UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    assigned_by UUID REFERENCES users(id),
    
    -- Related entities
    related_entity_type VARCHAR(50),
    related_entity_id UUID,
    application_id UUID REFERENCES applications(id) ON DELETE CASCADE,
    candidate_id UUID REFERENCES candidates(id) ON DELETE CASCADE,
    
    -- Due date
    due_date TIMESTAMP,
    reminder_before_minutes INTEGER, -- Remind X minutes before due
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending', -- pending, in_progress, completed, cancelled
    completed_at TIMESTAMP,
    completed_by UUID REFERENCES users(id),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 17: INTEGRATIONS
-- ============================================================================

-- External integrations (ATS, HRIS, Calendar, etc.)
CREATE TABLE integrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Integration details
    provider VARCHAR(100) NOT NULL, -- greenhouse, lever, workday, google_calendar, imocha, etc.
    integration_type VARCHAR(50) NOT NULL, -- ats, calendar, hris, background_check, assessment
    
    -- Credentials (encrypted)
    credentials JSONB, -- API keys, OAuth tokens (should be encrypted)
    
    -- Configuration
    config JSONB DEFAULT '{}',
    mapping JSONB DEFAULT '{}', -- Field mappings
    
    -- Sync settings
    sync_enabled BOOLEAN DEFAULT FALSE,
    sync_direction VARCHAR(50) DEFAULT 'bidirectional', -- inbound, outbound, bidirectional
    last_sync_at TIMESTAMP,
    sync_frequency_minutes INTEGER DEFAULT 60,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    status VARCHAR(50) DEFAULT 'connected',
    last_error TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Integration sync logs
CREATE TABLE integration_sync_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
    
    -- Sync details
    sync_type VARCHAR(50), -- full, incremental, manual
    direction VARCHAR(50),
    
    -- Results
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    status VARCHAR(50) DEFAULT 'running',
    
    -- Stats
    records_processed INTEGER DEFAULT 0,
    records_succeeded INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    
    -- Errors
    errors JSONB DEFAULT '[]',
    error_message TEXT,
    
    -- Metadata
    metadata JSONB DEFAULT '{}'
);

-- ============================================================================
-- SECTION 18: REPORTS & SAVED VIEWS
-- ============================================================================

-- Saved report configurations
CREATE TABLE saved_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- NULL = shared with org
    
    -- Report details
    name VARCHAR(255) NOT NULL,
    description TEXT,
    report_type VARCHAR(100), -- pipeline_analysis, time_to_hire, source_effectiveness
    
    -- Filters & configuration
    filters JSONB DEFAULT '{}',
    columns JSONB DEFAULT '[]',
    sort_by JSONB DEFAULT '{}',
    group_by VARCHAR(100),
    
    -- Visualization
    chart_type VARCHAR(50), -- table, bar, line, pie
    chart_config JSONB DEFAULT '{}',
    
    -- Sharing
    is_public BOOLEAN DEFAULT FALSE,
    shared_with_users UUID[],
    shared_with_roles user_role[],
    
    -- Scheduling
    schedule_enabled BOOLEAN DEFAULT FALSE,
    schedule_cron VARCHAR(100), -- Cron expression for scheduled reports
    email_recipients VARCHAR(500)[],
    
    -- Stats
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMP,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 19: API KEYS & WEBHOOKS
-- ============================================================================

-- API keys for external integrations
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Key details
    name VARCHAR(255) NOT NULL,
    key_hash VARCHAR(255) NOT NULL UNIQUE, -- Hashed API key
    key_prefix VARCHAR(20), -- First few chars for identification
    
    -- Permissions
    scopes VARCHAR(100)[], -- read:jobs, write:applications, etc.
    rate_limit INTEGER DEFAULT 1000, -- Requests per hour
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    
    -- Usage stats
    total_requests INTEGER DEFAULT 0,
    failed_requests INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Webhooks for event notifications
CREATE TABLE webhooks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Webhook details
    name VARCHAR(255) NOT NULL,
    url TEXT NOT NULL,
    secret VARCHAR(255), -- For signature verification
    
    -- Events to listen for
    events VARCHAR(100)[], -- application.created, interview.scheduled, etc.
    
    -- Configuration
    headers JSONB DEFAULT '{}', -- Custom headers
    timeout_seconds INTEGER DEFAULT 30,
    retry_count INTEGER DEFAULT 3,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    last_triggered_at TIMESTAMP,
    
    -- Stats
    total_deliveries INTEGER DEFAULT 0,
    successful_deliveries INTEGER DEFAULT 0,
    failed_deliveries INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES users(id)
);

-- Webhook delivery logs
CREATE TABLE webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    webhook_id UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
    
    -- Event
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    
    -- Delivery
    attempt_number INTEGER DEFAULT 1,
    delivered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Response
    http_status INTEGER,
    response_body TEXT,
    response_time_ms INTEGER,
    
    -- Status
    success BOOLEAN NOT NULL,
    error_message TEXT,
    
    -- Retry
    next_retry_at TIMESTAMP
);

-- ============================================================================
-- SECTION 20: INDEXES FOR PERFORMANCE
-- ============================================================================

-- Organizations
CREATE INDEX idx_organizations_slug ON organizations(slug);
CREATE INDEX idx_organizations_domain ON organizations(domain);
CREATE INDEX idx_organizations_active ON organizations(is_active) WHERE is_deleted = FALSE;

-- Users
CREATE INDEX idx_users_org_email ON users(organization_id, email);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_department ON users(department);
CREATE INDEX idx_users_status ON users(status);

-- User sessions
CREATE INDEX idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);
CREATE INDEX idx_user_sessions_token ON user_sessions(token_hash);

-- Jobs
CREATE INDEX idx_jobs_org ON jobs(organization_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_jobs_status ON jobs(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_jobs_slug ON jobs(organization_id, slug);
CREATE INDEX idx_jobs_published ON jobs(is_published, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX idx_jobs_posted_date ON jobs(posted_date DESC);
CREATE INDEX idx_jobs_hiring_manager ON jobs(hiring_manager_id);
CREATE INDEX idx_jobs_recruiter ON jobs(recruiter_id);
CREATE INDEX idx_jobs_department ON jobs(department);
CREATE INDEX idx_jobs_type ON jobs(job_type);

-- Candidates
CREATE INDEX idx_candidates_org_email ON candidates(organization_id, email);
CREATE INDEX idx_candidates_email ON candidates(email);
CREATE INDEX idx_candidates_name_trgm ON candidates USING gin(COALESCE(name, full_name) gin_trgm_ops);
CREATE INDEX idx_candidates_blacklist ON candidates(is_blacklisted) WHERE is_blacklisted = TRUE;
CREATE INDEX idx_candidates_active ON candidates(organization_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_candidates_college ON candidates(college);
CREATE INDEX idx_candidates_graduation_year ON candidates(graduation_year);
CREATE INDEX idx_candidates_skills ON candidates USING gin(skills);

-- Applications
CREATE INDEX idx_applications_job ON applications(job_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_applications_candidate ON applications(candidate_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_applications_org ON applications(organization_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_applications_status ON applications(status) WHERE is_deleted = FALSE;
CREATE INDEX idx_applications_interview_stage ON applications(interview_stage);
CREATE INDEX idx_applications_stage ON applications(current_stage);
CREATE INDEX idx_applications_ats_score ON applications(ats_score);
CREATE INDEX idx_applications_assigned ON applications(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX idx_applications_created_at ON applications(created_at DESC);
CREATE INDEX idx_applications_applied_date ON applications(applied_date DESC);
CREATE INDEX idx_applications_job_status ON applications(job_id, status);
CREATE INDEX idx_applications_assignment_status ON applications(assignment_status);

-- Application stage history
CREATE INDEX idx_app_stage_history_app ON application_stage_history(application_id);
CREATE INDEX idx_app_stage_history_changed_at ON application_stage_history(changed_at DESC);

-- Files
CREATE INDEX idx_files_org ON files(organization_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_files_candidate ON files(candidate_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_files_application ON files(application_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_files_type ON files(file_type);
CREATE INDEX idx_files_parsed_text_trgm ON files USING gin(parsed_text gin_trgm_ops);

-- Assignments
CREATE INDEX idx_assignments_org ON assignments(organization_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_assignments_status ON assignments(status);
CREATE INDEX idx_assignments_type ON assignments(assignment_type);
CREATE INDEX idx_assignments_role ON assignments(role);

-- Candidate assignments
CREATE INDEX idx_candidate_assignments_app ON candidate_assignments(application_id);
CREATE INDEX idx_candidate_assignments_candidate ON candidate_assignments(candidate_id);
CREATE INDEX idx_candidate_assignments_assignment ON candidate_assignments(assignment_id);
CREATE INDEX idx_candidate_assignments_status ON candidate_assignments(status);
CREATE INDEX idx_candidate_assignments_token ON candidate_assignments(access_token);

-- Interviews
CREATE INDEX idx_interviews_org ON interviews(organization_id);
CREATE INDEX idx_interviews_application ON interviews(application_id);
CREATE INDEX idx_interviews_candidate ON interviews(candidate_id);
CREATE INDEX idx_interviews_job ON interviews(job_id);
CREATE INDEX idx_interviews_status ON interviews(status);
CREATE INDEX idx_interviews_date ON interviews(date, time);
CREATE INDEX idx_interviews_scheduled_date ON interviews(scheduled_date, scheduled_time);
CREATE INDEX idx_interviews_interviewer ON interviews(primary_interviewer_id);
CREATE INDEX idx_interviews_datetime ON interviews(scheduled_datetime);
CREATE INDEX idx_interviews_round ON interviews(round);

-- Interview panel
CREATE INDEX idx_interview_panel_interview ON interview_panel(interview_id);
CREATE INDEX idx_interview_panel_interviewer ON interview_panel(interviewer_id);

-- Email queue
CREATE INDEX idx_email_queue_org ON email_queue(organization_id);
CREATE INDEX idx_email_queue_status ON email_queue(status);
CREATE INDEX idx_email_queue_scheduled ON email_queue(scheduled_for) WHERE status = 'queued';
CREATE INDEX idx_email_queue_to_email ON email_queue(to_email);
CREATE INDEX idx_email_queue_candidate ON email_queue(candidate_id);
CREATE INDEX idx_email_queue_application ON email_queue(application_id);
CREATE INDEX idx_email_queue_created_at ON email_queue(created_at DESC);
CREATE INDEX idx_email_queue_category ON email_queue(category);

-- Email templates
CREATE INDEX idx_email_templates_org ON email_templates(organization_id);
CREATE INDEX idx_email_templates_category ON email_templates(category);
CREATE INDEX idx_email_templates_active ON email_templates(is_active) WHERE is_active = TRUE;

-- Workflows
CREATE INDEX idx_workflows_org ON workflows(organization_id);
CREATE INDEX idx_workflows_active ON workflows(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_workflows_trigger ON workflows(trigger_event);

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id) WHERE is_archived = FALSE;
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- Audit logs
CREATE INDEX idx_audit_logs_org ON audit_logs(organization_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);

-- Analytics
CREATE INDEX idx_analytics_daily_org_date ON analytics_daily(organization_id, date DESC);
CREATE INDEX idx_analytics_jobs_job_date ON analytics_jobs(job_id, date DESC);
CREATE INDEX idx_analytics_recruiters_org_date ON analytics_recruiters(organization_id, date DESC);
CREATE INDEX idx_analytics_recruiters_user_date ON analytics_recruiters(recruiter_id, date DESC);

-- Tasks
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to) WHERE status != 'completed';
CREATE INDEX idx_tasks_due_date ON tasks(due_date) WHERE status != 'completed';
CREATE INDEX idx_tasks_application ON tasks(application_id);
CREATE INDEX idx_tasks_status ON tasks(status);

-- ============================================================================
-- SECTION 21: TRIGGERS & FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_candidates_updated_at BEFORE UPDATE ON candidates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_applications_updated_at BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_assignments_updated_at BEFORE UPDATE ON assignments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_interviews_updated_at BEFORE UPDATE ON interviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_files_updated_at BEFORE UPDATE ON files
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_email_templates_updated_at BEFORE UPDATE ON email_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update job stats
CREATE OR REPLACE FUNCTION update_job_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE jobs 
        SET total_applicants = total_applicants + 1
        WHERE id = NEW.job_id;
    END IF;
    
    IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
        -- Update counters based on status change
        UPDATE jobs SET
            ats_shortlisted = (SELECT COUNT(*) FROM applications WHERE job_id = NEW.job_id AND status = 'ats_shortlisted'),
            rejected = (SELECT COUNT(*) FROM applications WHERE job_id = NEW.job_id AND status = 'rejected'),
            hired = (SELECT COUNT(*) FROM applications WHERE job_id = NEW.job_id AND status = 'selected')
        WHERE id = NEW.job_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_job_stats
    AFTER INSERT OR UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION update_job_stats();

-- Function to sync application status with interview_stage
CREATE OR REPLACE FUNCTION sync_application_interview_stage()
RETURNS TRIGGER AS $$
BEGIN
    -- Keep interview_stage in sync with status
    IF NEW.status IN ('ats_shortlisted', 'assignment_sent', 'l1_scheduled', 'l2_scheduled', 
                      'hr_round', 'selected', 'rejected') THEN
        NEW.interview_stage = NEW.status;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_sync_interview_stage
    BEFORE INSERT OR UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION sync_application_interview_stage();

-- Function to create audit log
CREATE OR REPLACE FUNCTION create_audit_log()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (
        organization_id,
        user_id,
        action,
        entity_type,
        entity_id,
        old_values,
        new_values
    ) VALUES (
        COALESCE(NEW.organization_id, OLD.organization_id),
        NULLIF(current_setting('app.current_user_id', true), '')::UUID,
        TG_OP,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        CASE WHEN TG_OP != 'INSERT' THEN row_to_json(OLD) ELSE NULL END,
        CASE WHEN TG_OP != 'DELETE' THEN row_to_json(NEW) ELSE NULL END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Apply audit logging to critical tables (uncomment as needed)
-- CREATE TRIGGER audit_applications AFTER INSERT OR UPDATE OR DELETE ON applications
--     FOR EACH ROW EXECUTE FUNCTION create_audit_log();
-- CREATE TRIGGER audit_interviews AFTER INSERT OR UPDATE OR DELETE ON interviews
--     FOR EACH ROW EXECUTE FUNCTION create_audit_log();

-- ============================================================================
-- SECTION 22: VIEWS FOR COMMON QUERIES
-- ============================================================================

-- View: Active applications with candidate and job details
CREATE OR REPLACE VIEW v_active_applications AS
SELECT 
    a.id,
    a.job_id,
    a.candidate_id,
    a.organization_id,
    a.status,
    a.interview_stage,
    a.current_stage,
    a.ats_score,
    a.skills_match,
    a.education_score,
    a.project_score,
    a.assignment_status,
    a.assignment_score,
    a.assigned_to,
    a.applied_date,
    a.created_at,
    c.name as candidate_name,
    c.first_name,
    c.last_name,
    c.email,
    c.phone,
    c.college,
    c.degree,
    c.graduation_year,
    c.total_experience,
    c.skills,
    j.title as job_title,
    j.department,
    j.location,
    u.first_name || ' ' || u.last_name as assigned_to_name
FROM applications a
JOIN candidates c ON a.candidate_id = c.id
JOIN jobs j ON a.job_id = j.id
LEFT JOIN users u ON a.assigned_to = u.id
WHERE a.is_deleted = FALSE
    AND c.is_deleted = FALSE
    AND j.is_deleted = FALSE;

-- View: Upcoming interviews
CREATE OR REPLACE VIEW v_upcoming_interviews AS
SELECT 
    i.id,
    i.scheduled_datetime,
    i.date,
    i.time,
    i.duration,
    i.location_type,
    i.location,
    i.meeting_link,
    i.status,
    i.round,
    c.name as candidate_name,
    c.email as candidate_email,
    j.title as job_title,
    i.panel_member,
    u.first_name || ' ' || u.last_name as interviewer_name,
    u.email as interviewer_email
FROM interviews i
LEFT JOIN candidates c ON i.candidate_id = c.id
JOIN jobs j ON i.job_id = j.id
LEFT JOIN users u ON i.primary_interviewer_id = u.id
WHERE i.scheduled_datetime >= CURRENT_TIMESTAMP
    AND i.status IN ('scheduled', 'in_progress')
ORDER BY i.scheduled_datetime;

-- View: Pipeline summary by job
CREATE OR REPLACE VIEW v_job_pipeline_summary AS
SELECT 
    j.id as job_id,
    j.title,
    j.department,
    j.status,
    j.posted_date,
    COUNT(a.id) as total_applications,
    COUNT(CASE WHEN a.status = 'applied' THEN 1 END) as new_applications,
    COUNT(CASE WHEN a.status = 'ats_shortlisted' OR a.interview_stage = 'ats_shortlisted' THEN 1 END) as shortlisted,
    COUNT(CASE WHEN a.status LIKE '%interview%' OR a.interview_stage LIKE '%scheduled%' THEN 1 END) as in_interview,
    COUNT(CASE WHEN a.status = 'offer_extended' THEN 1 END) as offers_extended,
    COUNT(CASE WHEN a.status = 'selected' OR a.interview_stage = 'selected' THEN 1 END) as hired,
    COUNT(CASE WHEN a.status = 'rejected' OR a.interview_stage = 'rejected' THEN 1 END) as rejected,
    AVG(a.ats_score) as avg_ats_score,
    AVG(a.assignment_score) as avg_assignment_score
FROM jobs j
LEFT JOIN applications a ON j.id = a.job_id AND a.is_deleted = FALSE
WHERE j.is_deleted = FALSE
GROUP BY j.id, j.title, j.department, j.status, j.posted_date;

-- ============================================================================
-- SECTION 23: MATERIALIZED VIEWS (For Heavy Analytics)
-- ============================================================================

-- Materialized view for dashboard metrics (refresh periodically)
CREATE MATERIALIZED VIEW mv_dashboard_metrics AS
SELECT 
    o.id as organization_id,
    COUNT(DISTINCT j.id) as active_jobs,
    COUNT(DISTINCT CASE WHEN a.created_at >= CURRENT_DATE - INTERVAL '30 days' THEN a.id END) as applications_last_30_days,
    COUNT(DISTINCT CASE WHEN i.scheduled_datetime >= CURRENT_TIMESTAMP THEN i.id END) as upcoming_interviews,
    COUNT(DISTINCT CASE WHEN a.status = 'selected' AND a.updated_at >= CURRENT_DATE - INTERVAL '30 days' THEN a.id END) as hires_last_30_days,
    AVG(CASE WHEN a.created_at >= CURRENT_DATE - INTERVAL '90 days' THEN a.ats_score END) as avg_ats_score_90_days
FROM organizations o
LEFT JOIN jobs j ON o.id = j.organization_id AND j.is_deleted = FALSE AND j.status = 'active'
LEFT JOIN applications a ON j.id = a.job_id AND a.is_deleted = FALSE
LEFT JOIN interviews i ON a.id = i.application_id AND i.status = 'scheduled'
GROUP BY o.id;

-- Create index on materialized view
CREATE UNIQUE INDEX ON mv_dashboard_metrics(organization_id);

-- Refresh materialized view function (call via cron job)
CREATE OR REPLACE FUNCTION refresh_dashboard_metrics()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_dashboard_metrics;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 24: SEED DATA (PERMISSIONS)
-- ============================================================================

-- Insert standard permissions
INSERT INTO permissions (name, resource, action, description) VALUES
    ('view_dashboard', 'dashboard', 'read', 'View dashboard and analytics'),
    ('create_job', 'jobs', 'create', 'Create new job postings'),
    ('edit_job', 'jobs', 'update', 'Edit job postings'),
    ('delete_job', 'jobs', 'delete', 'Delete job postings'),
    ('view_applications', 'applications', 'read', 'View job applications'),
    ('manage_applications', 'applications', 'update', 'Manage application status'),
    ('delete_applications', 'applications', 'delete', 'Delete applications'),
    ('view_candidates', 'candidates', 'read', 'View candidate profiles'),
    ('edit_candidates', 'candidates', 'update', 'Edit candidate information'),
    ('delete_candidates', 'candidates', 'delete', 'Delete candidates'),
    ('create_assignment', 'assignments', 'create', 'Create assignments/tests'),
    ('manage_assignment', 'assignments', 'update', 'Manage assignments'),
    ('view_assignment_results', 'assignments', 'read', 'View assignment results'),
    ('schedule_interview', 'interviews', 'create', 'Schedule interviews'),
    ('conduct_interview', 'interviews', 'execute', 'Conduct and submit interview feedback'),
    ('view_interviews', 'interviews', 'read', 'View interview schedules'),
    ('manage_team', 'team', 'update', 'Manage team members and roles'),
    ('view_analytics', 'analytics', 'read', 'View reports and analytics'),
    ('export_data', 'data', 'export', 'Export data'),
    ('manage_settings', 'settings', 'update', 'Manage organization settings'),
    ('send_emails', 'emails', 'create', 'Send emails to candidates')
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

-- IMPLEMENTATION NOTES:
-- =====================
-- 1. All ENUM values match exactly with frontend mockData.ts and component interfaces
-- 2. Field names match frontend usage (e.g., applicants, posted, salary display)
-- 3. Added missing fields: shareable_link, posted_date, panel_member, imocha_test_link
-- 4. Interview rounds use 'l1', 'l2', 'hr' to match frontend exactly
-- 5. Assignment types match: coding, data_analysis, design, case_study
-- 6. Email categories match emailTemplates.ts exactly
-- 7. All denormalized stats fields added to jobs table for performance
-- 8. Candidate fields match mockData.ts Candidate interface exactly
-- 9. Application tracking fields match mockData.ts (atsScore, skillsMatch, etc.)
-- 10. Interview status includes 'available' for slot management
-- 
-- NEXT STEPS:
-- ===========
-- 1. Encrypt sensitive fields (credentials, API keys) at application level
-- 2. Implement Row-Level Security (RLS) for multi-tenancy
-- 3. Set up regular backups and PITR
-- 4. Configure connection pooling (PgBouncer)
-- 5. Monitor query performance and add indexes as needed
-- 6. Set up automated VACUUM and ANALYZE
-- 7. Implement rate limiting at application level
-- 8. Create migration files for version control
-- 9. Set up monitoring (pg_stat_statements)
-- 10. Document API endpoints that map to this schema
