# Sthapatya Recruitment ATS (Talent Management System)

Sthapatya Recruitment ATS is a sophisticated, AI-enhanced Applicant Tracking System (ATS) designed to streamline the modern hiring pipeline. From intelligent resume parsing and automated scoring to multi-stage interview coordination and conversion analytics, Sthapatya provides a centralized command center for talent acquisition teams.

It is tailored for modern organizations looking to build a structured hiring funnel, leverage AI for automated candidate screening, and coordinate flawlessly between recruitment teams and technical panels.

---

## 🚀 Key Features

- **AI-Driven Resume Scoring**: Automated analysis using a custom Python backend (Groq AI + Llama). Ranks candidates by Skill, Education, and Experience match against job requirements.
- **Smart Resume Auto-Fill**: Improved candidate UX with AI-powered form filling. Candidates simply upload a PDF resume, and the AI extracts all details into the application form instantly.
- **Traffic Source Tracking & Attribution**: Track where your applicants are coming from. Shareable job links automatically tag sources like **LinkedIn**, **Naukri**, **Careers Page**, or **Direct**.
- **Comprehensive Analytics Dashboard**:
  - **Hiring Funnel**: Visualize candidate drop-off across stages.
  - **Traffic Source Distribution**: Pie chart visualization of your most effective recruitment platforms.
  - **Hiring Success Index**: Real-time conversion rate analysis with industry benchmarking.
  - **Application Trends**: Weekly activity tracking.
- **Structured Interview Workflow**: Manage multiple rounds (L1, L2, HR) with dedicated panel member dashboards and structured feedback forms.
- **Server-Side Pagination & Search**: High-performance handling of thousands of applicants with advanced filtering by ATS score, stage, college, and source.
- **Premium UI/UX**: Modern dark-themed dashboard components, glassmorphism effects, and smooth Framer-Motion transitions for a state-of-the-art feel.

---

## 🛠️ Technical Stack

- **Frontend Application**
  - **Framework:** React (TypeScript) + Vite
  - **Styling:** Tailwind CSS + Shadcn UI + Lucide Icons
  - **State Management:** TanStack Query (React Query)
  - **Charts:** Recharts (Interactive Line, Bar, and Pie charts)
  - **Animations**: Framer Motion
- **Backend Infrastructure**
  - **Core API:** Node.js + Express
  - **ORM & DB:** Prisma ORM + PostgreSQL / SQLite
  - **Security:** JWT Authentication + Helmet + Rate Limiting
- **AI Microservice**
  - **Engine:** Python / FastAPI
  - **NLP:** Groq SDK (Llama 3 70B) for high-accuracy document extraction

---

## 🏗️ Getting Started

### 1. Backend Setup

```bash
cd server
npm install
npx prisma db push
npx prisma db seed
npm run dev
```

### 2. Frontend Setup

```bash
npm install
npm run dev
```

### 3. AI Service Setup

```bash
# Requires Python 3.9+ and Groq API Key
cd server/ResumePraser/backend
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --port 8000 --reload
```

---

## 👥 Access Credentials (Demo)

- **Employer/Admin:** `kp1@admin.com` | `Password123!`
- **Panel Interviewer:** `panel@hireflow.com` | `Password123!`

---

_Empowering Sthapatya Software Pvt. Ltd. to hire the best talent, faster._
