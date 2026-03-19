-- ============================================================================
-- ATS (Applicant Tracking System) & Interview Automation Platform
-- Microsoft SQL Server Database Schema - SINGLE TENANT VERSION
-- ============================================================================
-- Version: 2.0 - Single Tenant
-- Database: Microsoft SQL Server 2022
-- Client: Sthapatya Software Pvt. Ltd.
-- Features: RBAC, Audit Logging, Soft Deletes, GDPR Compliance
-- ============================================================================
-- Single-tenant architecture - No multi-tenancy overhead
-- All V2 performance fixes included
-- ============================================================================

USE master;
GO

-- ============================================================================
-- Create Database
-- ============================================================================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'ATS_SthapatyaSoftware')
BEGIN
    CREATE DATABASE ATS_SthapatyaSoftware
    COLLATE SQL_Latin1_General_CP1_CI_AS;
END
GO

USE ATS_SthapatyaSoftware;
GO

-- ============================================================================
-- SECTION 1: CORE TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Company Settings (Single tenant configuration)
-- ----------------------------------------------------------------------------
CREATE TABLE company_settings (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Company info
    company_name NVARCHAR(255) NOT NULL DEFAULT 'Sthapatya Software Pvt. Ltd.',
    domain NVARCHAR(255),
    logo_url NVARCHAR(500),
    website NVARCHAR(500),
    industry NVARCHAR(100),
    company_size NVARCHAR(50),
    timezone NVARCHAR(100) DEFAULT 'Asia/Kolkata',
    
    -- Application settings
    settings NVARCHAR(MAX), -- JSON data
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- Insert default company record
INSERT INTO company_settings (company_name, industry, company_size, timezone)
VALUES ('Sthapatya Software Pvt. Ltd.', 'Software Development', '50-200', 'Asia/Kolkata');
GO

-- ----------------------------------------------------------------------------
-- Users (Team members with RBAC)
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Authentication
    email NVARCHAR(255) NOT NULL UNIQUE,
    password_hash NVARCHAR(255),
    email_verified BIT DEFAULT 0,
    email_verified_at DATETIME2,
    
    -- Profile
    first_name NVARCHAR(100),
    last_name NVARCHAR(100),
    phone NVARCHAR(50),
    avatar_url NVARCHAR(500),
    
    -- Role & Access
    role NVARCHAR(50) NOT NULL DEFAULT 'viewer' CHECK (role IN ('super_admin', 'org_admin', 'recruiter', 'hiring_manager', 'interviewer', 'viewer')),
    department NVARCHAR(100),
    title NVARCHAR(100),
    
    -- Statistics
    interviews_conducted INT DEFAULT 0,
    
    -- Status
    status NVARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    last_login_at DATETIME2,
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2
);
GO

-- ----------------------------------------------------------------------------
-- Jobs
-- ----------------------------------------------------------------------------
CREATE TABLE jobs (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Basic info
    title NVARCHAR(255) NOT NULL,
    department NVARCHAR(100),
    location NVARCHAR(255),
    salary_display NVARCHAR(100), -- e.g., "$120k - $180k" or "₹10L - 12L"
    salary_min DECIMAL(15,2),
    salary_max DECIMAL(15,2),
    salary_currency NVARCHAR(10) DEFAULT 'INR',
    
    -- Job type and status
    job_type NVARCHAR(50) DEFAULT 'full_time' CHECK (job_type IN ('full_time', 'part_time', 'contract', 'internship', 'temporary')),
    status NVARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'on_hold', 'closed', 'archived')),
    
    -- Content
    description NVARCHAR(MAX),
    requirements NVARCHAR(MAX), -- JSON array
    benefits NVARCHAR(MAX), -- JSON array
    required_skills NVARCHAR(MAX), -- JSON array
    
    -- Configuration
    ats_configuration NVARCHAR(MAX), -- JSON: {skillWeightage, educationWeightage, projectWeightage, threshold}
    interview_rounds NVARCHAR(MAX), -- JSON: {l1Enabled, l2Enabled, hrEnabled}
    
    -- Assignment linkage
    assignment_id UNIQUEIDENTIFIER,
    
    -- Public access
    shareable_link NVARCHAR(500),
    posted_date DATE,
    
    -- Hiring manager
    hiring_manager_id UNIQUEIDENTIFIER,
    
    -- Statistics (computed/cached)
    total_applicants INT DEFAULT 0,
    ats_shortlisted INT DEFAULT 0,
    assignment_qualified INT DEFAULT 0,
    interviews_scheduled INT DEFAULT 0,
    final_selections INT DEFAULT 0,
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2,
    
    CONSTRAINT FK_jobs_hiring_manager FOREIGN KEY (hiring_manager_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Candidates
-- ----------------------------------------------------------------------------
CREATE TABLE candidates (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Basic info
    name NVARCHAR(255),
    full_name NVARCHAR(255),
    email NVARCHAR(255) NOT NULL,
    phone NVARCHAR(50),
    
    -- Education
    college NVARCHAR(255),
    degree NVARCHAR(100),
    graduation_year INT,
    
    -- Skills & experience
    skills NVARCHAR(MAX), -- JSON array
    experience NVARCHAR(MAX), -- Text or JSON
    projects NVARCHAR(MAX), -- Text or JSON
    
    -- Social links
    linkedin_url NVARCHAR(500),
    github_url NVARCHAR(500),
    portfolio_url NVARCHAR(500),
    
    -- ATS Scores
    ats_score DECIMAL(5,2),
    skills_match DECIMAL(5,2),
    education_score DECIMAL(5,2),
    project_score DECIMAL(5,2),
    
    -- Resume
    resume_url NVARCHAR(500),
    
    -- GDPR Compliance
    gdpr_consent BIT DEFAULT 0,
    gdpr_consent_date DATETIME2,
    gdpr_consent_ip NVARCHAR(50),
    data_retention_until DATETIME2,
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2
);
GO

-- ----------------------------------------------------------------------------
-- Applications
-- ----------------------------------------------------------------------------
CREATE TABLE applications (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    job_id UNIQUEIDENTIFIER NOT NULL,
    candidate_id UNIQUEIDENTIFIER NOT NULL,
    
    -- Application status
    status NVARCHAR(50) DEFAULT 'applied' CHECK (status IN (
        'applied', 'screening', 'ats_shortlisted', 'ats_rejected',
        'assignment_sent', 'assignment_submitted', 'assignment_passed', 'assignment_failed',
        'l1_scheduled', 'l1_completed', 'l2_scheduled', 'l2_completed', 'hr_round',
        'interview_completed', 'offer_extended', 'offer_accepted', 'offer_rejected',
        'selected', 'rejected', 'withdrawn'
    )),
    
    -- Interview stage (for display)
    interview_stage NVARCHAR(50),
    current_stage NVARCHAR(50),
    
    -- Stage tracking
    stage_entered_at DATETIME2,
    time_in_current_stage AS DATEDIFF(DAY, stage_entered_at, GETUTCDATE()) PERSISTED,
    
    -- Dates
    applied_date DATE DEFAULT CAST(GETUTCDATE() AS DATE),
    days_since_applied AS DATEDIFF(DAY, applied_date, CAST(GETUTCDATE() AS DATE)) PERSISTED,
    
    -- Scores
    ats_score DECIMAL(5,2),
    assignment_score DECIMAL(5,2),
    overall_score DECIMAL(5,2),
    
    -- Assignment tracking
    assignment_status NVARCHAR(50) CHECK (assignment_status IN ('not_started', 'in_progress', 'completed', 'passed', 'failed')),
    
    -- Feedback
    rejection_reason NVARCHAR(MAX),
    internal_notes NVARCHAR(MAX),
    
    -- Assignment tracking
    assigned_by_id UNIQUEIDENTIFIER,
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2,
    
    CONSTRAINT FK_applications_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
    CONSTRAINT FK_applications_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE CASCADE,
    CONSTRAINT FK_applications_assigned_by FOREIGN KEY (assigned_by_id) REFERENCES users(id) ON DELETE SET NULL,
    CONSTRAINT UQ_applications_job_candidate UNIQUE (job_id, candidate_id)
);
GO

-- ----------------------------------------------------------------------------
-- Application Stage History
-- ----------------------------------------------------------------------------
CREATE TABLE application_stage_history (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    application_id UNIQUEIDENTIFIER NOT NULL,
    
    from_stage NVARCHAR(50),
    to_stage NVARCHAR(50) NOT NULL,
    changed_by_id UNIQUEIDENTIFIER,
    reason NVARCHAR(MAX),
    duration_in_previous_stage INT, -- days
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_stage_history_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT FK_stage_history_user FOREIGN KEY (changed_by_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Assignments
-- ----------------------------------------------------------------------------
CREATE TABLE assignments (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Basic info
    title NVARCHAR(255) NOT NULL,
    role NVARCHAR(255),
    assignment_type NVARCHAR(50) DEFAULT 'coding' CHECK (assignment_type IN ('coding', 'data_analysis', 'design', 'case_study', 'general')),
    
    -- Content
    description NVARCHAR(MAX),
    instructions NVARCHAR(MAX),
    
    -- Configuration
    duration INT DEFAULT 90, -- minutes
    total_questions INT DEFAULT 0,
    passing_score DECIMAL(5,2) DEFAULT 70.0,
    
    -- iMocha integration
    imocha_test_link NVARCHAR(500),
    imocha_test_id NVARCHAR(255),
    
    -- Status
    status NVARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'inactive', 'archived')),
    
    -- Statistics
    assigned_count INT DEFAULT 0,
    completed_count INT DEFAULT 0,
    passed_count INT DEFAULT 0,
    average_score DECIMAL(5,2) DEFAULT 0,
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2
);
GO

-- ----------------------------------------------------------------------------
-- Assignment Questions
-- ----------------------------------------------------------------------------
CREATE TABLE assignment_questions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    assignment_id UNIQUEIDENTIFIER NOT NULL,
    
    -- Question details
    question_order INT NOT NULL,
    question_type NVARCHAR(50) NOT NULL CHECK (question_type IN ('mcq', 'coding', 'explanatory', 'file_upload', 'short_answer')),
    title NVARCHAR(500) NOT NULL,
    description NVARCHAR(MAX),
    
    -- MCQ specific
    options NVARCHAR(MAX), -- JSON array for MCQ
    correct_option NVARCHAR(255), -- for MCQ
    correct_answer NVARCHAR(MAX), -- for other types
    
    -- Scoring
    points DECIMAL(5,2) DEFAULT 10.0,
    auto_gradable BIT DEFAULT 0,
    
    -- Coding question specific
    test_cases NVARCHAR(MAX), -- JSON
    starter_code NVARCHAR(MAX),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_questions_assignment FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Candidate Assignments
-- ----------------------------------------------------------------------------
CREATE TABLE candidate_assignments (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    application_id UNIQUEIDENTIFIER NOT NULL,
    assignment_id UNIQUEIDENTIFIER NOT NULL,
    candidate_id UNIQUEIDENTIFIER NOT NULL,
    
    -- Status
    status NVARCHAR(50) DEFAULT 'not_started' CHECK (status IN ('not_started', 'in_progress', 'completed', 'passed', 'failed')),
    
    -- Access control
    access_token NVARCHAR(255) UNIQUE,
    access_link NVARCHAR(500),
    
    -- Timing
    assigned_at DATETIME2 DEFAULT GETUTCDATE(),
    started_at DATETIME2,
    submitted_at DATETIME2,
    expires_at DATETIME2,
    time_taken INT, -- minutes
    
    -- Scoring
    score DECIMAL(5,2),
    max_score DECIMAL(5,2),
    auto_score DECIMAL(5,2),
    manual_score DECIMAL(5,2),
    
    -- Results
    result NVARCHAR(50), -- 'passed' or 'failed'
    feedback NVARCHAR(MAX),
    
    -- Proctoring
    proctoring_enabled BIT DEFAULT 0,
    proctoring_data NVARCHAR(MAX), -- JSON
    
    -- iMocha integration
    imocha_attempt_id NVARCHAR(255),
    imocha_score DECIMAL(5,2),
    imocha_result NVARCHAR(MAX), -- JSON
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_candidate_assignments_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT FK_candidate_assignments_assignment FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE CASCADE,
    CONSTRAINT FK_candidate_assignments_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Candidate Answers
-- ----------------------------------------------------------------------------
CREATE TABLE candidate_answers (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    candidate_assignment_id UNIQUEIDENTIFIER NOT NULL,
    question_id UNIQUEIDENTIFIER NOT NULL,
    
    -- Answer
    answer NVARCHAR(MAX),
    submitted_at DATETIME2,
    
    -- Scoring
    earned_points DECIMAL(5,2) DEFAULT 0,
    max_points DECIMAL(5,2),
    is_correct BIT,
    
    -- Coding specific
    code NVARCHAR(MAX),
    language NVARCHAR(50),
    execution_results NVARCHAR(MAX), -- JSON
    test_cases_passed INT,
    test_cases_total INT,
    
    -- Manual grading
    manual_score DECIMAL(5,2),
    graded_by_id UNIQUEIDENTIFIER,
    graded_at DATETIME2,
    feedback NVARCHAR(MAX),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_answers_candidate_assignment FOREIGN KEY (candidate_assignment_id) REFERENCES candidate_assignments(id) ON DELETE CASCADE,
    CONSTRAINT FK_answers_question FOREIGN KEY (question_id) REFERENCES assignment_questions(id) ON DELETE CASCADE,
    CONSTRAINT FK_answers_graded_by FOREIGN KEY (graded_by_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Interviews
-- ----------------------------------------------------------------------------
CREATE TABLE interviews (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    job_id UNIQUEIDENTIFIER NOT NULL,
    application_id UNIQUEIDENTIFIER,
    candidate_id UNIQUEIDENTIFIER,
    
    -- Interview details
    round NVARCHAR(50) NOT NULL CHECK (round IN ('phone_screen', 'l1', 'l2', 'hr', 'cultural_fit', 'final_round')),
    
    -- Scheduling (legacy fields for backward compatibility)
    date DATE,
    time NVARCHAR(20),
    
    -- Scheduling (preferred fields)
    scheduled_date DATE,
    scheduled_time NVARCHAR(20),
    scheduled_datetime DATETIME2,
    
    duration INT DEFAULT 60, -- minutes
    
    -- Location
    location NVARCHAR(255),
    meeting_link NVARCHAR(500),
    meeting_type NVARCHAR(50) CHECK (meeting_type IN ('in_person', 'video_call', 'phone')),
    
    -- Interviewer
    primary_interviewer_id UNIQUEIDENTIFIER,
    panel_member NVARCHAR(255), -- Display name for backward compatibility
    
    -- Status
    status NVARCHAR(50) DEFAULT 'scheduled' CHECK (status IN ('available', 'scheduled', 'in_progress', 'completed', 'rescheduled', 'cancelled', 'no_show')),
    
    -- Feedback
    feedback NVARCHAR(MAX),
    strengths NVARCHAR(MAX),
    weaknesses NVARCHAR(MAX),
    recommendation NVARCHAR(50) CHECK (recommendation IN ('strong_hire', 'hire', 'no_hire', 'strong_no_hire')),
    
    -- Rating
    overall_rating INT CHECK (overall_rating BETWEEN 1 AND 5),
    
    -- Result
    result NVARCHAR(50) CHECK (result IN ('pending', 'pass', 'fail', 'strong_hire', 'hire', 'no_hire', 'strong_no_hire')),
    
    -- Notes
    notes NVARCHAR(MAX),
    
    -- Calendar integration
    google_calendar_event_id NVARCHAR(255),
    outlook_event_id NVARCHAR(255),
    
    -- Audit fields
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2,
    
    CONSTRAINT FK_interviews_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE,
    CONSTRAINT FK_interviews_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL,
    CONSTRAINT FK_interviews_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL,
    CONSTRAINT FK_interviews_primary_interviewer FOREIGN KEY (primary_interviewer_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Interview Panel (for multi-interviewer panels)
-- ----------------------------------------------------------------------------
CREATE TABLE interview_panel (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    interview_id UNIQUEIDENTIFIER NOT NULL,
    interviewer_id UNIQUEIDENTIFIER NOT NULL,
    
    role NVARCHAR(100), -- Lead, Technical Expert, etc.
    attended BIT DEFAULT 0,
    feedback NVARCHAR(MAX),
    rating INT CHECK (rating BETWEEN 1 AND 5),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_panel_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE CASCADE,
    CONSTRAINT FK_panel_interviewer FOREIGN KEY (interviewer_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT UQ_panel_interview_interviewer UNIQUE (interview_id, interviewer_id)
);
GO

-- ----------------------------------------------------------------------------
-- Interview Criteria
-- ----------------------------------------------------------------------------
CREATE TABLE interview_criteria (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    category NVARCHAR(100),
    max_score INT DEFAULT 5,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- ----------------------------------------------------------------------------
-- Interview Scores
-- ----------------------------------------------------------------------------
CREATE TABLE interview_scores (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    interview_id UNIQUEIDENTIFIER NOT NULL,
    interviewer_id UNIQUEIDENTIFIER NOT NULL,
    criteria_id UNIQUEIDENTIFIER NOT NULL,
    
    score INT NOT NULL,
    comments NVARCHAR(MAX),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_scores_interview FOREIGN KEY (interview_id) REFERENCES interviews(id) ON DELETE CASCADE,
    CONSTRAINT FK_scores_interviewer FOREIGN KEY (interviewer_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT FK_scores_criteria FOREIGN KEY (criteria_id) REFERENCES interview_criteria(id) ON DELETE CASCADE,
    CONSTRAINT UQ_scores_interview_interviewer_criteria UNIQUE (interview_id, interviewer_id, criteria_id)
);
GO

-- ----------------------------------------------------------------------------
-- Interviewer Availability
-- ----------------------------------------------------------------------------
CREATE TABLE interviewer_availability (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    interviewer_id UNIQUEIDENTIFIER NOT NULL,
    
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Sunday, 6=Saturday
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    
    is_active BIT DEFAULT 1,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_availability_interviewer FOREIGN KEY (interviewer_id) REFERENCES users(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Files
-- ----------------------------------------------------------------------------
CREATE TABLE files (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    candidate_id UNIQUEIDENTIFIER,
    application_id UNIQUEIDENTIFIER,
    
    -- File info
    file_name NVARCHAR(255) NOT NULL,
    original_name NVARCHAR(255),
    file_type NVARCHAR(50) CHECK (file_type IN ('resume', 'cover_letter', 'assignment_file', 'offer_letter', 'document', 'other')),
    mime_type NVARCHAR(100),
    file_size BIGINT, -- bytes
    
    -- Storage
    storage_path NVARCHAR(500),
    storage_url NVARCHAR(500),
    
    -- Metadata
    uploaded_by_id UNIQUEIDENTIFIER,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2,
    
    CONSTRAINT FK_files_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL,
    CONSTRAINT FK_files_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL,
    CONSTRAINT FK_files_uploaded_by FOREIGN KEY (uploaded_by_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Email Templates
-- ----------------------------------------------------------------------------
CREATE TABLE email_templates (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    -- Template info
    name NVARCHAR(255) NOT NULL,
    category NVARCHAR(50) NOT NULL CHECK (category IN ('shortlist', 'reject', 'assignment', 'interview', 'offer', 'custom')),
    
    -- Content
    subject NVARCHAR(500) NOT NULL,
    body NVARCHAR(MAX) NOT NULL,
    
    -- Variables
    available_variables NVARCHAR(MAX), -- JSON array
    
    -- Status
    is_default BIT DEFAULT 0,
    is_active BIT DEFAULT 1,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2
);
GO

-- ----------------------------------------------------------------------------
-- Email Queue
-- ----------------------------------------------------------------------------
CREATE TABLE email_queue (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    template_id UNIQUEIDENTIFIER,
    workflow_id UNIQUEIDENTIFIER, -- Track workflow source
    
    -- Recipient
    to_email NVARCHAR(255) NOT NULL,
    to_name NVARCHAR(255),
    cc_emails NVARCHAR(MAX), -- JSON array
    bcc_emails NVARCHAR(MAX), -- JSON array
    
    -- Content
    subject NVARCHAR(500) NOT NULL,
    body NVARCHAR(MAX) NOT NULL,
    
    -- Context
    candidate_id UNIQUEIDENTIFIER,
    application_id UNIQUEIDENTIFIER,
    job_id UNIQUEIDENTIFIER,
    
    -- Scheduling
    scheduled_for DATETIME2 DEFAULT GETUTCDATE(),
    sent_at DATETIME2,
    
    -- Status
    status NVARCHAR(50) DEFAULT 'queued' CHECK (status IN ('queued', 'sending', 'sent', 'delivered', 'opened', 'clicked', 'bounced', 'failed', 'spam')),
    priority INT DEFAULT 5, -- 1=highest, 10=lowest
    
    -- Tracking
    provider_message_id NVARCHAR(255),
    error_message NVARCHAR(MAX),
    retry_count INT DEFAULT 0,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_email_queue_template FOREIGN KEY (template_id) REFERENCES email_templates(id) ON DELETE SET NULL,
    CONSTRAINT FK_email_queue_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL,
    CONSTRAINT FK_email_queue_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL,
    CONSTRAINT FK_email_queue_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Email Events (tracking)
-- ----------------------------------------------------------------------------
CREATE TABLE email_events (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    email_queue_id UNIQUEIDENTIFIER NOT NULL,
    
    event_type NVARCHAR(50) NOT NULL CHECK (event_type IN ('sent', 'delivered', 'opened', 'clicked', 'bounced', 'spam', 'failed')),
    event_data NVARCHAR(MAX), -- JSON
    provider_event_id NVARCHAR(255),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_email_events_queue FOREIGN KEY (email_queue_id) REFERENCES email_queue(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Email Unsubscribes
-- ----------------------------------------------------------------------------
CREATE TABLE email_unsubscribes (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    email NVARCHAR(255) NOT NULL,
    candidate_id UNIQUEIDENTIFIER,
    
    category NVARCHAR(50), -- specific category unsubscribe
    reason NVARCHAR(MAX),
    
    unsubscribed_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_email_unsubscribes_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE SET NULL,
    CONSTRAINT UQ_email_unsubscribes_email UNIQUE (email)
);
GO

-- ----------------------------------------------------------------------------
-- Workflows (Automation)
-- ----------------------------------------------------------------------------
CREATE TABLE workflows (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    
    -- Trigger
    trigger_event NVARCHAR(50) NOT NULL CHECK (trigger_event IN ('application_received', 'ats_score_threshold', 'assignment_submitted', 'interview_completed', 'stage_changed', 'time_based')),
    trigger_conditions NVARCHAR(MAX), -- JSON
    
    -- Actions
    actions NVARCHAR(MAX) NOT NULL, -- JSON array
    
    -- Status
    is_active BIT DEFAULT 1,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    is_deleted BIT DEFAULT 0,
    deleted_at DATETIME2
);
GO

-- ----------------------------------------------------------------------------
-- Workflow Executions (audit log)
-- ----------------------------------------------------------------------------
CREATE TABLE workflow_executions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    workflow_id UNIQUEIDENTIFIER NOT NULL,
    
    application_id UNIQUEIDENTIFIER,
    triggered_by NVARCHAR(MAX), -- JSON
    
    status NVARCHAR(50) CHECK (status IN ('success', 'failed', 'partial')),
    execution_log NVARCHAR(MAX), -- JSON
    
    executed_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_workflow_executions_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE CASCADE,
    CONSTRAINT FK_workflow_executions_application FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- Notifications
-- ----------------------------------------------------------------------------
CREATE TABLE notifications (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER NOT NULL,
    
    title NVARCHAR(255) NOT NULL,
    message NVARCHAR(MAX) NOT NULL,
    notification_type NVARCHAR(50) CHECK (notification_type IN ('info', 'success', 'warning', 'error')),
    
    -- Context
    entity_type NVARCHAR(50), -- 'application', 'interview', etc.
    entity_id UNIQUEIDENTIFIER,
    action_url NVARCHAR(500),
    
    -- Status
    is_read BIT DEFAULT 0,
    read_at DATETIME2,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_notifications_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Permissions
-- ----------------------------------------------------------------------------
CREATE TABLE permissions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    resource NVARCHAR(100) NOT NULL,
    action NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT UQ_permissions_resource_action UNIQUE (resource, action)
);
GO

-- ----------------------------------------------------------------------------
-- Role Permissions
-- ----------------------------------------------------------------------------
CREATE TABLE role_permissions (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    role NVARCHAR(50) NOT NULL CHECK (role IN ('super_admin', 'org_admin', 'recruiter', 'hiring_manager', 'interviewer', 'viewer')),
    permission_id UNIQUEIDENTIFIER NOT NULL,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    CONSTRAINT UQ_role_permissions_role_permission UNIQUE (role, permission_id)
);
GO

-- ----------------------------------------------------------------------------
-- User Permission Overrides
-- ----------------------------------------------------------------------------
CREATE TABLE user_permission_overrides (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER NOT NULL,
    permission_id UNIQUEIDENTIFIER NOT NULL,
    
    granted BIT NOT NULL, -- 1=grant, 0=revoke
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_user_overrides_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT FK_user_overrides_permission FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE,
    CONSTRAINT UQ_user_overrides_user_permission UNIQUE (user_id, permission_id)
);
GO

-- ----------------------------------------------------------------------------
-- User Department Access (for row-level security)
-- ----------------------------------------------------------------------------
CREATE TABLE user_department_access (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER NOT NULL,
    department NVARCHAR(100) NOT NULL,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_dept_access_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT UQ_dept_access_user_dept UNIQUE (user_id, department)
);
GO

-- ----------------------------------------------------------------------------
-- Audit Logs
-- ----------------------------------------------------------------------------
CREATE TABLE audit_logs (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    user_id UNIQUEIDENTIFIER,
    
    action NVARCHAR(100) NOT NULL,
    entity_type NVARCHAR(100) NOT NULL,
    entity_id UNIQUEIDENTIFIER,
    
    old_values NVARCHAR(MAX), -- JSON
    new_values NVARCHAR(MAX), -- JSON
    
    ip_address NVARCHAR(50),
    user_agent NVARCHAR(500),
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_audit_logs_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);
GO

-- ----------------------------------------------------------------------------
-- GDPR: Consent Records
-- ----------------------------------------------------------------------------
CREATE TABLE consent_records (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    candidate_id UNIQUEIDENTIFIER NOT NULL,
    
    consent_type NVARCHAR(100) NOT NULL,
    consent_given BIT NOT NULL,
    consent_date DATETIME2 DEFAULT GETUTCDATE(),
    consent_ip NVARCHAR(50),
    
    withdrawn_at DATETIME2,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_consent_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- GDPR: Data Access Requests
-- ----------------------------------------------------------------------------
CREATE TABLE data_access_requests (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    candidate_id UNIQUEIDENTIFIER NOT NULL,
    
    request_type NVARCHAR(50) NOT NULL CHECK (request_type IN ('export', 'deletion', 'rectification')),
    status NVARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'rejected')),
    
    requested_at DATETIME2 DEFAULT GETUTCDATE(),
    completed_at DATETIME2,
    
    notes NVARCHAR(MAX),
    
    CONSTRAINT FK_data_requests_candidate FOREIGN KEY (candidate_id) REFERENCES candidates(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- GDPR: Data Retention Policies
-- ----------------------------------------------------------------------------
CREATE TABLE data_retention_policies (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    entity_type NVARCHAR(100) NOT NULL,
    retention_days INT NOT NULL,
    auto_delete BIT DEFAULT 0,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- ----------------------------------------------------------------------------
-- Saved Reports
-- ----------------------------------------------------------------------------
CREATE TABLE saved_reports (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    created_by_id UNIQUEIDENTIFIER NOT NULL,
    
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    report_type NVARCHAR(100),
    
    filters NVARCHAR(MAX), -- JSON
    columns NVARCHAR(MAX), -- JSON array
    
    is_shared BIT DEFAULT 0,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_reports_created_by FOREIGN KEY (created_by_id) REFERENCES users(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- Webhooks
-- ----------------------------------------------------------------------------
CREATE TABLE webhooks (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    
    name NVARCHAR(255) NOT NULL,
    url NVARCHAR(500) NOT NULL,
    secret_key NVARCHAR(255),
    
    events NVARCHAR(MAX) NOT NULL, -- JSON array
    
    is_active BIT DEFAULT 1,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    updated_at DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- ----------------------------------------------------------------------------
-- Webhook Deliveries (log)
-- ----------------------------------------------------------------------------
CREATE TABLE webhook_deliveries (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    webhook_id UNIQUEIDENTIFIER NOT NULL,
    
    event_type NVARCHAR(100) NOT NULL,
    payload NVARCHAR(MAX) NOT NULL, -- JSON
    
    status_code INT,
    response_body NVARCHAR(MAX),
    
    delivered_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_webhook_deliveries_webhook FOREIGN KEY (webhook_id) REFERENCES webhooks(id) ON DELETE CASCADE
);
GO

-- ----------------------------------------------------------------------------
-- API Keys
-- ----------------------------------------------------------------------------
CREATE TABLE api_keys (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    created_by_id UNIQUEIDENTIFIER NOT NULL,
    
    name NVARCHAR(255) NOT NULL,
    key_hash NVARCHAR(255) NOT NULL UNIQUE,
    key_prefix NVARCHAR(20),
    
    scopes NVARCHAR(MAX), -- JSON array
    
    last_used_at DATETIME2,
    expires_at DATETIME2,
    
    is_active BIT DEFAULT 1,
    
    created_at DATETIME2 DEFAULT GETUTCDATE(),
    
    CONSTRAINT FK_api_keys_created_by FOREIGN KEY (created_by_id) REFERENCES users(id) ON DELETE CASCADE
);
GO

-- ============================================================================
-- SECTION 2: INDEXES FOR PERFORMANCE
-- ============================================================================

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role) WHERE is_deleted = 0;
GO

-- Jobs
CREATE INDEX idx_jobs_status ON jobs(status) WHERE is_deleted = 0;
CREATE INDEX idx_jobs_posted_date ON jobs(posted_date DESC) WHERE is_deleted = 0;
CREATE INDEX idx_jobs_department ON jobs(department) WHERE is_deleted = 0;
GO

-- Candidates (with full-text search support)
CREATE INDEX idx_candidates_email ON candidates(email);
CREATE INDEX idx_candidates_name ON candidates(name) WHERE is_deleted = 0;
GO

-- Applications (V2 performance indexes)
CREATE INDEX idx_applications_job ON applications(job_id) WHERE is_deleted = 0;
CREATE INDEX idx_applications_candidate ON applications(candidate_id) WHERE is_deleted = 0;
CREATE INDEX idx_applications_status ON applications(status) WHERE is_deleted = 0;
CREATE INDEX idx_applications_job_status_date ON applications(job_id, status, applied_date DESC) WHERE is_deleted = 0;
CREATE INDEX idx_applications_pending_review ON applications(status, created_at DESC) WHERE status = 'applied' AND is_deleted = 0;
CREATE INDEX idx_applications_days_since ON applications(days_since_applied) WHERE days_since_applied <= 30 AND is_deleted = 0;
GO

-- Assignments
CREATE INDEX idx_assignments_status ON assignments(status) WHERE is_deleted = 0;
GO

-- Candidate Assignments
CREATE INDEX idx_candidate_assignments_application ON candidate_assignments(application_id);
CREATE INDEX idx_candidate_assignments_candidate ON candidate_assignments(candidate_id);
CREATE INDEX idx_candidate_assignments_token ON candidate_assignments(access_token);
GO

-- Interviews (V2 performance indexes)
CREATE INDEX idx_interviews_job ON interviews(job_id) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_candidate ON interviews(candidate_id) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_application ON interviews(application_id) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_interviewer ON interviews(primary_interviewer_id) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_scheduled_datetime ON interviews(scheduled_datetime) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_status ON interviews(status) WHERE is_deleted = 0;
CREATE INDEX idx_interviews_availability ON interviews(scheduled_date, status, primary_interviewer_id) WHERE status IN ('available', 'scheduled');
GO

-- Files
CREATE INDEX idx_files_candidate ON files(candidate_id) WHERE is_deleted = 0;
CREATE INDEX idx_files_application ON files(application_id) WHERE is_deleted = 0;
GO

-- Email Queue (V2 performance index)
CREATE INDEX idx_email_queue_status ON email_queue(status);
CREATE INDEX idx_email_queue_scheduled_priority ON email_queue(scheduled_for, priority) WHERE status = 'queued';
CREATE INDEX idx_email_queue_workflow ON email_queue(workflow_id) WHERE workflow_id IS NOT NULL;
GO

-- Notifications
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
GO

-- Audit Logs
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(created_at DESC);
GO

-- ============================================================================
-- SECTION 3: TRIGGERS FOR AUTO-UPDATE
-- ============================================================================

-- Trigger to update updated_at timestamp on company_settings
CREATE TRIGGER trg_company_settings_updated_at ON company_settings
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE company_settings
    SET updated_at = GETUTCDATE()
    FROM company_settings cs
    INNER JOIN inserted i ON cs.id = i.id;
END;
GO

-- Trigger to update updated_at timestamp on users
CREATE TRIGGER trg_users_updated_at ON users
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE users
    SET updated_at = GETUTCDATE()
    FROM users u
    INNER JOIN inserted i ON u.id = i.id;
END;
GO

-- Trigger to update updated_at timestamp on jobs
CREATE TRIGGER trg_jobs_updated_at ON jobs
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE jobs
    SET updated_at = GETUTCDATE()
    FROM jobs j
    INNER JOIN inserted i ON j.id = i.id;
END;
GO

-- Trigger to update updated_at timestamp on applications
CREATE TRIGGER trg_applications_updated_at ON applications
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    UPDATE applications
    SET updated_at = GETUTCDATE()
    FROM applications a
    INNER JOIN inserted i ON a.id = i.id;
END;
GO

-- V2: Trigger to track application stage duration
CREATE TRIGGER trg_applications_stage_duration ON applications
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE applications
    SET stage_entered_at = GETUTCDATE()
    FROM applications a
    INNER JOIN inserted i ON a.id = i.id
    INNER JOIN deleted d ON a.id = d.id
    WHERE i.current_stage <> d.current_stage OR d.current_stage IS NULL;
END;
GO

-- V2: Trigger to auto-increment interviews_conducted
CREATE TRIGGER trg_interviews_increment_count ON interviews
AFTER INSERT, UPDATE AS
BEGIN
    SET NOCOUNT ON;
    
    -- Update for primary interviewer
    UPDATE users
    SET interviews_conducted = interviews_conducted + 1
    FROM users u
    INNER JOIN inserted i ON u.id = i.primary_interviewer_id
    LEFT JOIN deleted d ON i.id = d.id
    WHERE i.status = 'completed' 
      AND (d.id IS NULL OR d.status <> 'completed');
    
    -- Update for panel members who attended
    UPDATE users
    SET interviews_conducted = interviews_conducted + 1
    FROM users u
    INNER JOIN interview_panel ip ON u.id = ip.interviewer_id
    INNER JOIN inserted i ON ip.interview_id = i.id
    LEFT JOIN deleted d ON i.id = d.id
    WHERE ip.attended = 1
      AND i.status = 'completed'
      AND (d.id IS NULL OR d.status <> 'completed');
END;
GO

-- ============================================================================
-- SECTION 4: VIEWS FOR REPORTING
-- ============================================================================

-- View: Upcoming Interviews
CREATE VIEW v_upcoming_interviews AS
SELECT 
    i.id,
    i.scheduled_datetime,
    i.round,
    i.status,
    c.id as candidate_id,
    c.name as candidate_name,
    c.email as candidate_email,
    j.id as job_id,
    j.title as job_title,
    i.panel_member,
    u.first_name + ' ' + u.last_name as interviewer_name,
    u.email as interviewer_email
FROM interviews i
LEFT JOIN candidates c ON i.candidate_id = c.id
INNER JOIN jobs j ON i.job_id = j.id
LEFT JOIN users u ON i.primary_interviewer_id = u.id
WHERE i.scheduled_datetime >= GETUTCDATE()
    AND i.status IN ('scheduled', 'in_progress')
    AND i.is_deleted = 0;
GO

-- View: Job Pipeline Summary
CREATE VIEW v_job_pipeline_summary AS
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
LEFT JOIN applications a ON j.id = a.job_id AND a.is_deleted = 0
WHERE j.is_deleted = 0
GROUP BY j.id, j.title, j.department, j.status, j.posted_date;
GO

-- ============================================================================
-- SECTION 5: DASHBOARD METRICS TABLE
-- ============================================================================

-- Dashboard metrics table (refreshed via scheduled job)
CREATE TABLE dashboard_metrics (
    id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    active_jobs INT,
    applications_last_30_days INT,
    upcoming_interviews INT,
    hires_last_30_days INT,
    avg_ats_score_90_days DECIMAL(5,2),
    shortlisted_candidates INT,
    pending_reviews INT,
    last_refreshed DATETIME2 DEFAULT GETUTCDATE()
);
GO

-- Stored procedure to refresh dashboard metrics
CREATE PROCEDURE sp_refresh_dashboard_metrics
AS
BEGIN
    SET NOCOUNT ON;
    
    TRUNCATE TABLE dashboard_metrics;
    
    INSERT INTO dashboard_metrics (
        active_jobs,
        applications_last_30_days,
        upcoming_interviews,
        hires_last_30_days,
        avg_ats_score_90_days,
        shortlisted_candidates,
        pending_reviews,
        last_refreshed
    )
    SELECT 
        COUNT(DISTINCT j.id) as active_jobs,
        COUNT(DISTINCT CASE WHEN a.created_at >= DATEADD(DAY, -30, GETUTCDATE()) THEN a.id END) as applications_last_30_days,
        COUNT(DISTINCT CASE WHEN i.scheduled_datetime >= GETUTCDATE() THEN i.id END) as upcoming_interviews,
        COUNT(DISTINCT CASE WHEN a.status = 'selected' AND a.updated_at >= DATEADD(DAY, -30, GETUTCDATE()) THEN a.id END) as hires_last_30_days,
        AVG(CASE WHEN a.created_at >= DATEADD(DAY, -90, GETUTCDATE()) THEN a.ats_score END) as avg_ats_score_90_days,
        COUNT(DISTINCT CASE WHEN a.status = 'ats_shortlisted' OR a.interview_stage = 'ats_shortlisted' THEN a.id END) as shortlisted_candidates,
        COUNT(DISTINCT CASE WHEN a.status = 'applied' AND a.is_deleted = 0 THEN a.id END) as pending_reviews,
        GETUTCDATE() as last_refreshed
    FROM jobs j
    LEFT JOIN applications a ON j.id = a.job_id AND j.is_deleted = 0 AND a.is_deleted = 0
    LEFT JOIN interviews i ON a.id = i.application_id AND i.status = 'scheduled'
    WHERE j.is_deleted = 0 AND j.status = 'active';
END;
GO

-- ============================================================================
-- SECTION 6: INITIAL DATA & FOREIGN KEYS
-- ============================================================================

-- Execute initial dashboard metrics refresh
EXEC sp_refresh_dashboard_metrics;
GO

-- Foreign key for jobs.assignment_id
ALTER TABLE jobs
ADD CONSTRAINT FK_jobs_assignment FOREIGN KEY (assignment_id) REFERENCES assignments(id) ON DELETE SET NULL;
GO

-- Foreign key for email_queue.workflow_id (V2 fix)
ALTER TABLE email_queue
ADD CONSTRAINT FK_email_queue_workflow FOREIGN KEY (workflow_id) REFERENCES workflows(id) ON DELETE SET NULL;
GO

-- ============================================================================
-- Script Complete
-- ============================================================================

PRINT '============================================================================';
PRINT 'ATS Platform Database Schema Created Successfully';
PRINT '============================================================================';
PRINT 'Database: ATS_SthapatyaSoftware';
PRINT 'Client: Sthapatya Software Pvt. Ltd.';
PRINT 'Architecture: Single Tenant';
PRINT 'Tables: 41';
PRINT 'Views: 2';
PRINT 'Stored Procedures: 1 (dashboard metrics refresh)';
PRINT 'Triggers: 5 (auto-update + V2 fixes)';
PRINT '============================================================================';
PRINT 'Next Steps:';
PRINT '1. Setup SQL Server Agent Job to run sp_refresh_dashboard_metrics every 5 minutes';
PRINT '2. Configure full-text search indexes if needed';
PRINT '3. Create initial admin user';
PRINT '4. Setup backup schedule';
PRINT '5. Configure email SMTP settings';
PRINT '============================================================================';
GO
