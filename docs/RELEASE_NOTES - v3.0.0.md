# Orbit Release Notes — Version 3.0.0 (v3.0.0+4)

We are thrilled to announce **Orbit v3.0.0**, the most significant architectural evolution since the app's inception. This release transforms Orbit into a resilient, zero-knowledge, offline-first personal assistant.

---

## 🏗️ Architectural Changes

### 1. Offline-First Database Layer (SQLite via Drift)
* **Local-First Reads/Writes**: All user data is now written to a local, per-user SQLite database first. Reads are instantaneous and work fully offline.
* **Domain Model Mapping**: All repositories (`tasks`, `reflections`, `learnings`, `events`, `decisions`, `days`, `academic`) now interface with Drift tables through custom domain model mappers instead of direct Firestore calls.

### 2. Reliable Cloud Sync Engine (`SyncService`)
* **Outbox Pattern**: Appends all database operations (INSERT, UPDATE, DELETE) to a local `SyncQueueTable` outbox.
* **Background Worker**: An asynchronous background processor handles cloud updates to Firestore, managing automated retries for network-resilient syncing.
* **Encryption Integration**: The sync engine works hand-in-hand with the encryption layer to selectively encrypt sensitive payload fields while keeping metadata/index fields plaintext for cloud queries.

### 3. Client-Side Transparent Encryption
* **AES-256-GCM Encryption**: Secures user documents at rest in Firestore.
* **Argon2id + HKDF Key Hierarchy**: Zero-knowledge design. A master key stored in local Secure Storage (Android Keystore / iOS Keychain) is encrypted under a Passphrase Encryption Key (PEK) derived via Argon2id. Collection-specific Data Encryption Keys (DEKs) are derived dynamically via HKDF-SHA256.
* **Lazy Schema Migration**: Automatically upgrades legacy v1 plaintext documents to v2 encrypted format on-demand during normal reads/writes, avoiding downtime.

---

## 🚀 Key Feature & UX Updates

### 📊 AI Analytics Dashboard
* Located under **Settings → AI Analytics**.
* Visualizes request volume, estimated token counts, and daily usage logs using `fl_chart`.
* Tracks usage across Chat/LLM, Voice/STT, and Multimodal Extraction models.

### 📷 Voice & Multimodal Extraction Services
* **Multimodal Extraction**: Automatically parses uploaded timetable screenshots in the Academic section.
* **Voice Reliability**: Enhanced error boundaries and loading indicators in `VoiceService` with automated analytics logging.

### 🗺️ Modular UI & UX Overhaul
* **Guide & About Split**: Rebuilt the monolithic guide page into structured, modular cards and added a swipeable prompting handbook. Created a new **About Orbit** info page.
* **Escape Hatches**: Added logout buttons on passphrase setup/recovery views and a secure "Delete Account" flow on recovery.
* **List Ordering & QoL Fixes**: Standardized date-grouped descending sorting across all lists. Fixed `ReflectionTagChip` deletions, stale auth states on logout, and profile image load delays.
