# How to Run the Project

This project consists of a **React Frontend (Vite)** and a **Node.js/Express Backend (Prisma)**. Follow these steps to get everything running locally.

## Prerequisites
- **Node.js**: (v16.0 or higher recommended)
- **npm**: (v7.0 or higher)

---

## 1. Backend Setup (API & Database)

The backend uses **SQLite** for easy local setup (no external database installation required).

1.  **Open a terminal** and navigate to the `server` directory:
    ```bash
    cd server
    ```
2.  **Install dependencies**:
    ```bash
    npm install
    ```
3.  **Synchronize Database**:
    This will create the local SQLite database (`dev.db`) and set up the tables.
    ```bash
    npx prisma db push
    ```
4.  **Seed Initial Data** (Optional but recommended):
    This will populate the database with some sample jobs and candidates.
    ```bash
    npm run prisma:generate  # Ensure types are generated
    npx prisma db seed
    ```
5.  **Start the Server**:
    The server will run on `http://localhost:5000`.
    ```bash
    npm run dev
    ```

---

## 2. Frontend Setup (React UI)

1.  **Open a new terminal** and ensure you are in the project's **root directory**:
    ```bash
    cd ..
    ```
2.  **Install dependencies**:
    ```bash
    npm install
    ```
3.  **Start the Frontend**:
    The application will run on `http://localhost:5173`.
    ```bash
    npm run dev
    ```

---

## 🚦 Important Notes
- **Database**: The database is stored in `server/prisma/dev.db`.
- **API Connection**: The frontend is configured to talk to the backend at `http://localhost:5000`.
- **Interviewer Panel**: To test the evaluation features, you can go to the "Panel Dashboard" after seeding data or applying through the job form.
