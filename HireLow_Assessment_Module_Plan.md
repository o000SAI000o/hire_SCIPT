# HireLow ATS — Assessment Module: Complete Build Plan

---

## 1. OVERVIEW

The Assessment Module is a self-contained feature inside HireLow ATS that allows employers
to create, send, and evaluate technical assessments for candidates. It covers three question
types: MCQ (Multiple Choice), DSA Coding (with live code execution), and Assignment tasks
(take-home projects like building a CRUD app).

Candidates receive a unique, token-based public link via email. They fill in their details,
complete the test under timed and proctored conditions, and submit. Results are automatically
saved to the HireLow database and linked to the candidate's ATS profile.

---

## 2. ARCHITECTURE

```
HireLow ATS
└── Assessment Module
    ├── Admin Side (Employer)
    │   ├── Assessment Builder
    │   │   ├── MCQ Question Creator
    │   │   ├── Coding Problem Creator (with test cases)
    │   │   └── Assignment Task Creator
    │   ├── Assessment Config (time limit, scoring, proctoring on/off)
    │   ├── Send via Email (Nodemailer — token-based unique link per candidate)
    │   └── Results Dashboard (per candidate, per assessment)
    │
    └── Candidate Side (Public Portal)
        ├── Landing Page (token verified → fill name, email, consent)
        ├── Test Environment
        │   ├── MCQ Section (timed, one question at a time or all-at-once)
        │   ├── Coding Section (Monaco Editor → submit → Judge0 → show result)
        │   └── Assignment Section (instructions + file/zip/GitHub link upload)
        ├── Proctoring Layer (tab-switch detection, fullscreen, webcam snapshots)
        └── Submission + Auto-score → Save to DB
```

---

## 3. TECH STACK (Fits Your Existing HireLow Stack)

| Layer            | Technology                          | Cost      |
|------------------|-------------------------------------|-----------|
| Frontend         | React + TypeScript + Tailwind       | Free      |
| Code Editor      | Monaco Editor (VSCode engine)       | Free      |
| Code Execution   | Judge0 (self-hosted via Docker)     | Free      |
| Backend          | Node.js + Express + Prisma          | Free      |
| Database         | SQLite (existing)                   | Free      |
| Email Invites    | Nodemailer + Gmail SMTP             | Free      |
| File Uploads     | Multer (Node.js middleware)         | Free      |
| Proctoring       | Native Browser APIs (custom built)  | Free      |

Total external cost: $0/month (fully self-hosted)

---

## 4. DATABASE SCHEMA

### New Tables Required

**Assessment**
- id, title, description, jobId (optional link to job posting)
- type: MCQ | CODING | ASSIGNMENT | MIXED
- totalMarks, passingMarks, durationMinutes
- proctoringEnabled (boolean)
- createdBy (adminId), createdAt, updatedAt

**Question**
- id, assessmentId
- type: MCQ | CODING | ASSIGNMENT
- title, description, order
- marks

**MCQOption** (for MCQ questions)
- id, questionId, text, isCorrect

**TestCase** (for Coding questions)
- id, questionId, input, expectedOutput, isHidden (boolean)
- hidden test cases are not shown to candidate but used for scoring

**CandidateAssessment** (one row per invite sent)
- id, assessmentId, candidateId (or email if not yet in system)
- token (unique UUID for public link)
- status: PENDING | IN_PROGRESS | SUBMITTED | EXPIRED
- startedAt, submittedAt, expiresAt
- totalScore, result: PASS | FAIL | UNDER_REVIEW

**CandidateAnswer**
- id, candidateAssessmentId, questionId
- answerType: MCQ | CODE | ASSIGNMENT
- selectedOptionId (for MCQ)
- codeSubmission (text, for coding)
- codeLanguage (for coding)
- assignmentLink (GitHub URL or file path, for assignment)
- isCorrect (boolean, auto-set for MCQ and coding)
- marksAwarded

**ProctoringEvent**
- id, candidateAssessmentId
- eventType: TAB_SWITCH | FULLSCREEN_EXIT | WEBCAM_SNAPSHOT | COPY_PASTE
- timestamp, metadata (JSON)

---

## 5. PHASE-BY-PHASE BUILD PLAN

---

### PHASE 1 — Assessment Builder (Admin Side)
**Estimated Time: 1 week**

Goal: Employer can create an assessment with questions.

Tasks:
1. Create "Assessments" section in HireLow admin sidebar
2. Assessment creation form:
   - Title, description, duration, total marks, passing marks
   - Toggle: proctoring on/off
   - Link to a Job (optional)
3. Question Builder:
   - MCQ: question text + 4 options + mark correct answer + assign marks
   - Coding: problem title + description + input/output format + add test cases
     (visible test cases for candidate + hidden test cases for scoring)
   - Assignment: task title + description + tech stack + expected deliverable
4. Question ordering (drag and drop)
5. Save assessment to DB via Prisma

Deliverable: Admin can fully create a mixed assessment with all three question types.

---

### PHASE 2 — Invite System (Email + Token Links)
**Estimated Time: 3-4 days**

Goal: Send unique test links to candidates via email.

Tasks:
1. On the assessment page, add "Send to Candidate" button
2. Enter candidate email (or pick from existing ATS candidates)
3. Backend generates a UUID token, creates a CandidateAssessment row with:
   - status: PENDING
   - expiresAt: now + X days (configurable)
   - unique link: https://hirelow.app/test/{token}
4. Nodemailer sends the email with:
   - Candidate's name
   - Company/job name
   - Link to start test
   - Deadline
   - Instructions
5. Admin can see all sent invites with status (Pending / In Progress / Submitted / Expired)
6. Admin can resend or revoke a link

Deliverable: Candidates receive a professional invite email with a unique, expiring test link.

---

### PHASE 3 — Candidate Portal (Public Test Interface)
**Estimated Time: 1 week**

Goal: Candidate opens their link and takes the test.

Flow:
1. Candidate opens /test/{token}
2. Backend validates token:
   - If expired → show "This link has expired" page
   - If already submitted → show "Already submitted" page
   - If valid → proceed
3. Pre-test page:
   - Candidate fills: Full Name, Email, Phone (optional)
   - Shows: test duration, number of questions, rules, proctoring notice
   - "Start Test" button (starts the timer, marks status as IN_PROGRESS)
4. Test Interface:
   - Top bar: timer (countdown), section tabs (MCQ / Coding / Assignment)
   - Question navigator sidebar (jump to any question, mark for review)
   - MCQ: radio buttons, single or multi-select
   - Coding: Monaco Editor + language dropdown + Run (test against visible cases) + Submit
   - Assignment: markdown task description + text area for GitHub link or file upload
5. Submit button:
   - Confirmation modal
   - All answers saved to DB
   - Auto-score MCQ and coding (via test cases)
   - Assignment marked as UNDER_REVIEW
   - Status set to SUBMITTED
6. Thank you page shown to candidate

Deliverable: Clean, professional test-taking experience for all three question types.

---

### PHASE 4 — Code Execution Engine (Judge0)
**Estimated Time: 3-4 days**

Goal: Candidate code is compiled and run in a sandboxed environment.

Setup:
1. Install Docker on your server
2. Self-host Judge0 using the official docker-compose setup
   (See: https://github.com/judge0/judge0)
3. Judge0 exposes a REST API at localhost:2358

Integration:
1. Candidate writes code in Monaco Editor (supports 40+ languages)
2. "Run" button → frontend sends code + language + input to your Node backend
3. Backend calls Judge0 API: POST /submissions with:
   - source_code (base64)
   - language_id (e.g., 71 for Python, 62 for Java, 63 for JS)
   - stdin (test case input)
4. Judge0 returns: stdout, stderr, compile_error, time, memory
5. Frontend shows output panel: Pass / Fail per test case + time + memory used
6. On "Submit": run against all hidden test cases, calculate score, save to DB

Supported Languages (out of the box):
Python, JavaScript, TypeScript, Java, C, C++, C#, Go, Rust, PHP, Ruby, Swift, Kotlin

Deliverable: Full compile-and-run experience, identical to HackerRank.

---

### PHASE 5 — Proctoring Layer
**Estimated Time: 3-4 days**

Goal: Detect and log suspicious behavior during the test.

Features to Implement:
1. Fullscreen enforcement:
   - Force fullscreen on test start using the Fullscreen API
   - Detect fullscreen exit → warn candidate → log ProctoringEvent
2. Tab switch / window blur detection:
   - Listen to document.visibilitychange and window.blur events
   - After 3 violations, auto-flag the submission
   - Log each event with timestamp
3. Copy-paste detection:
   - Disable right-click context menu in the test area
   - Listen to copy/paste events and log them
4. Webcam snapshots (optional, can be toggled per assessment):
   - Request webcam permission on test start
   - Take a silent snapshot every 2-3 minutes using the MediaDevices API
   - Save snapshot URLs to ProctoringEvent table
5. Admin proctoring report:
   - On results page, show a "Proctoring Log" tab
   - List all events with timestamps
   - Flag high-risk submissions (e.g., 5+ tab switches, fullscreen exits)
   - Show webcam snapshots in a timeline view

Note: Inform candidates of all proctoring measures in the pre-test consent screen.
This is both ethical practice and required in many jurisdictions.

Deliverable: Admin gets a clear proctoring report for every submission.

---

### PHASE 6 — Results & Scoring
**Estimated Time: 3-4 days**

Goal: Auto-score where possible and surface results in the ATS.

Scoring Logic:
- MCQ: compare selectedOptionId with isCorrect=true option → full marks or 0
- Coding: run against all hidden test cases in Judge0 → marks = (passed/total) * questionMarks
- Assignment: no auto-score → status = UNDER_REVIEW, admin manually scores

Results Dashboard (Admin):
- List of all candidates who took a specific assessment
- Score, pass/fail status, time taken, proctoring risk level
- Click into individual candidate → see answer-by-answer breakdown
- For coding: view submitted code, test case results
- For assignment: view GitHub link or download submitted file
- Manual score entry for assignments
- Add reviewer notes

Integration with HireLow ATS Pipeline:
- Assessment score visible on candidate's ATS profile card
- Filter/sort candidates by score in the shortlisted / assignments pipeline stage
- Automatically move candidate to next stage if score > passing marks (optional automation)

Deliverable: Complete results view, fully linked to the existing HireLow hiring pipeline.

---

## 6. FEATURE CHECKLIST

| Feature                                  | Phase | Status       |
|------------------------------------------|-------|--------------|
| MCQ Question Builder                     | 1     | Build it     |
| Coding Problem Builder + Test Cases      | 1     | Build it     |
| Assignment Task Builder                  | 1     | Build it     |
| Token-based invite links                 | 2     | Build it     |
| Email invites via Nodemailer             | 2     | Build it     |
| Invite status tracking                   | 2     | Build it     |
| Candidate registration before test      | 3     | Build it     |
| Timed test interface                     | 3     | Build it     |
| MCQ test UI                              | 3     | Build it     |
| Monaco Code Editor UI                    | 3     | Monaco (free)|
| Assignment submission (link/file)        | 3     | Build it     |
| Judge0 self-hosted code execution        | 4     | Judge0 (free)|
| Run against visible test cases           | 4     | Build it     |
| Score against hidden test cases          | 4     | Build it     |
| Multi-language support (13+ languages)   | 4     | Judge0       |
| Fullscreen enforcement                   | 5     | Build it     |
| Tab-switch / blur detection              | 5     | Build it     |
| Copy-paste detection                     | 5     | Build it     |
| Webcam snapshots                         | 5     | Build it     |
| Proctoring event log for admin           | 5     | Build it     |
| Auto-score MCQ + Coding                  | 6     | Build it     |
| Manual score for assignments             | 6     | Build it     |
| Results dashboard in ATS                 | 6     | Build it     |
| ATS pipeline integration                 | 6     | Build it     |

---

## 7. TOTAL TIMELINE ESTIMATE

| Phase | Feature                    | Time      |
|-------|----------------------------|-----------|
| 1     | Assessment Builder         | 1 week    |
| 2     | Invite + Email System      | 3-4 days  |
| 3     | Candidate Portal           | 1 week    |
| 4     | Code Execution (Judge0)    | 3-4 days  |
| 5     | Proctoring Layer           | 3-4 days  |
| 6     | Results + ATS Integration  | 3-4 days  |
| —     | Testing + Bug Fixes        | 1 week    |
| TOTAL |                            | ~6 weeks  |

---

## 8. COST SUMMARY

| Component           | Free Option                  | Paid Option (if needed)           |
|---------------------|------------------------------|-----------------------------------|
| Code Execution      | Judge0 self-hosted (Docker)  | Judge0 cloud: ~$20-50/month       |
| Code Editor UI      | Monaco Editor (MIT License)  | —                                 |
| MCQ Engine          | Build yourself               | —                                 |
| Email Invites       | Nodemailer + Gmail SMTP      | Resend / SendGrid: ~$0-15/month   |
| File Uploads        | Multer (self-hosted)         | S3 / Cloudinary: ~$5/month        |
| Proctoring          | Browser APIs (build it)      | Proctorio: $$$                    |
| Database            | SQLite (existing)            | Postgres if you scale: ~$7/month  |
| Hosting             | Your existing server         | VPS (if separate): ~$10/month     |

Realistic total: $0/month to launch. Scale costs only apply at volume.

---

## 9. THIRD-PARTY ALTERNATIVES (If You Don't Want to Build)

If at any point you want to skip building a component and integrate an existing service:

| Platform       | What it Replaces                  | Cost            |
|----------------|-----------------------------------|-----------------|
| HackerRank     | Everything (MCQ + Code + Assign)  | ~$250+/month    |
| Coderbyte      | Code assessments + MCQ            | ~$199/month     |
| TestGorilla    | MCQ + soft skills                 | ~$75-300/month  |
| Sphere Engine  | Code execution engine only (API)  | ~$49/month      |
| Judge0 Cloud   | Code execution only (API)         | ~$20/month      |
| Proctorio      | Proctoring only                   | Per-exam pricing|

Recommendation: Build everything in-house using the plan above. You get full control,
zero vendor lock-in, and it integrates perfectly with HireLow's existing data model.

---

## 10. QUICK-START STEPS (Week 1)

To get started immediately:

1. Run this to self-host Judge0:
   git clone https://github.com/judge0/judge0.git
   cd judge0
   docker-compose up -d

2. Install Monaco Editor in your React frontend:
   npm install @monaco-editor/react

3. Add Nodemailer to your backend:
   npm install nodemailer

4. Create the new Prisma schema tables:
   Assessment, Question, MCQOption, TestCase,
   CandidateAssessment, CandidateAnswer, ProctoringEvent

5. Run prisma migrate dev and start building Phase 1.

---

End of Plan
