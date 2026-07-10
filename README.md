# ⚡ MeterVision – AI-Powered Smart Meter Reading System

> An enterprise-grade smart electricity meter reading platform built for Punjab State Power Corporation Limited (PSPCL).

MeterVision is an AI-assisted meter reading ecosystem designed to digitize and automate the complete electricity meter reading workflow—from field data collection to AI-powered validation and administrative monitoring.

The platform enables field officers to capture meter readings offline, leverages AI for image quality assessment and OCR, detects anomalies, routes suspicious cases to an LCR (Local Complaint Resolution) team, and provides administrators with a centralized dashboard for monitoring operations and analytics.

---

# 📌 Problem Statement

Traditional electricity meter reading involves:

- Manual meter reading
- Human errors
- Poor image quality
- Delayed synchronization
- Incorrect billing
- Lack of operational visibility
- Difficult anomaly tracking

MeterVision addresses these challenges through AI-assisted validation, offline-first mobile data collection, automated review workflows, and a centralized operations dashboard.

---

# 🏗 System Architecture

```text
                    PSPCL MeterVision

                  ┌───────────────────┐
                  │ React Dashboard   │
                  │ (Admin + LCR)     │
                  └─────────▲─────────┘
                            │
                    FastAPI REST API
                            │
          ┌─────────────────┴─────────────────┐
          │                                   │
   Flutter Mobile App                  AI Services
   (Field Officer)                Blur + OCR + AI Classifier
          │                                   │
          └─────────────────┬─────────────────┘
                            │
                        Supabase
              PostgreSQL + Storage + Authentication
```

---

# 🚀 Key Features

## 👷 Field Officer Mobile Application

- Secure JWT authentication
- Consumer assignment download
- Offline-first architecture
- Camera integration
- Meter image capture
- Blur detection
- OCR-assisted reading extraction
- AI-based image classification
- Offline SQLite storage
- Automatic synchronization
- Reading history
- Retry failed uploads

---

## 🤖 AI Pipeline

### Blur Detection

Determines whether an image is suitable for OCR.

Output:

- Blur
- Not Blur

---

### OCR & Classification

Extracts meter readings and classifies image quality.

Outputs:

- Meter Reading
- OCR Confidence
- AI Classification

Supported Classes:

- Image Okay Electro Mechanical Meter
- Blur Image Electro Mechanical Meter
- Blur Image Digital Meter
- Reading MisMatch Electro Mechanical Meter
- Reading Mis Match Digital Meter
- Reflection Digital Meter
- Irrelevant Image Electro Mechanical Meter
- Irrelevant Image Digital Meter
- Image Okay Digital Meter

---

## 🚨 Anomaly Detection

Automatically detects abnormal readings including:

- Reading mismatch
- High consumption
- Reflection
- Blur
- Irrelevant image
- OCR confidence issues

Suspicious readings are automatically routed to the LCR workflow.

---

## 👨‍💼 LCR Workflow

Dedicated review interface for problematic readings.

Capabilities include:

- View original image
- OCR review
- AI classification review
- Reading correction
- Approve
- Reject
- Request revisit
- Audit logging

---

## 📊 Admin Dashboard

Built using React.

Provides complete operational visibility.

Modules include:

- Dashboard
- Consumers
- Officers
- Assignments
- Readings
- Images
- OCR Results
- Anomalies
- LCR Queue
- Analytics
- Notifications
- Settings

---

# 📈 Operations Center

The dashboard serves as a live operations center displaying:

- Today's Readings
- Active Officers
- Offline Officers
- Pending Synchronizations
- Pending LCR Cases
- OCR Accuracy
- Blur Rate
- Reflection Rate
- AI Model Status
- Server Status
- Recent Activities
- System Notifications

---

# 📱 Offline Synchronization

One of the core capabilities of MeterVision.

```text
Flutter

↓

SQLite

↓

Sync Queue

↓

Internet Available

↓

FastAPI

↓

Supabase

↓

Conflict Resolution

↓

Synchronization Successful
```

Field officers can continue working without internet connectivity. Data is synchronized automatically when connectivity is restored.

---

# 🔐 Role-Based Access Control

## Admin

- Manage officers
- Assign consumers
- View analytics
- Monitor operations
- Review anomalies
- Configure system

---

## Field Officer

- View assigned consumers
- Capture readings
- Upload images
- OCR verification
- Offline synchronization
- Reading history

---

## LCR Team

- Review anomaly cases
- View AI predictions
- Correct OCR
- Approve readings
- Reject readings
- Request revisit

Every API endpoint is protected using role-based authorization.

---

# 🛠 Technology Stack

## Mobile

- Flutter
- SQLite

## Backend

- FastAPI
- Python
- REST APIs
- JWT Authentication

## Database

- Supabase PostgreSQL
- Supabase Storage
- Supabase Authentication

## AI

- OCR
- Blur Detection
- Image Classification

## Dashboard

- React
- TypeScript
- Material UI
- Redux Toolkit
- Recharts

---

# 📂 Project Structure

```text
MeterVision/

├── backend/
│   ├── app/
│   ├── database/
│   └── requirements.txt
│
├── frontend/
│   ├── metervision_app/
│   └── dashboard/
│
├── docs/
│
└── README.md
```

---

# 📊 Database Design

The platform uses PostgreSQL with normalized relational tables.

Core entities include:

- Users
- Consumers
- Officer Assignments
- Meter Readings
- Meter Images
- OCR Results
- Anomalies
- LCR Cases
- Notifications
- Sync Queue
- Audit Logs

---

# 🔄 Workflow

```text
Field Officer

↓

Login

↓

Download Assigned Consumers

↓

Capture Meter Image

↓

Blur Detection

↓

OCR

↓

AI Classification

↓

Submit Reading

↓

Backend Validation

↓

Store Reading

↓

Anomaly Detection

↓

LCR Review (if required)

↓

Dashboard Updates
```

---

# 📊 Future Enhancements

- Live WebSocket updates
- GIS-based officer tracking
- Predictive anomaly detection
- AI model version comparison
- Multi-region deployment
- Push notifications
- Automated billing integration
- Advanced analytics
- Heatmaps
- Performance forecasting

---

# 📄 License

This project is developed for educational and research purposes.
