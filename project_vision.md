# Student Daily Life Helper - Project Vision

This document outlines the vision and brainstorming for a mobile application designed to be a frictionless, AI-powered daily assistant for college students. 

## 🎯 The Core Vision
To build a highly frequently used, practical daily life helper for students. It shouldn't be a massive, bloated ERP system, but rather a personal, smart companion that handles the cognitive load of college life (classes, food, tasks, and reflection).

## ✨ Core Features

### 1. AI-Powered Daily Diary & Task Manager
* **Frictionless Entry:** A simple interface to log daily thoughts, events, and what happened during the day.
* **AI Task Extraction:** As the user writes (e.g., "I have a DBMS assignment due this Friday and I need to buy groceries tomorrow"), the AI automatically parses the text and adds these to a structured "Upcoming Tasks" list with due dates.
* **Weekly Analysis:** The AI reviews the week's entries to generate a personalized progress report, highlighting achievements, tracking mood/stress, and offering actionable life suggestions (e.g., "You've been pulling a lot of late nights, try to rest this weekend").

### 2. Smart Academic Timetable
* **Image-to-Schedule:** The user simply takes a photo of the college-provided timetable.
* **AI Vision Extraction:** The app uses vision models to extract subjects, times, and room numbers, converting the image into a structured digital schedule.
* **Daily Flow:** A clean UI showing "What's next?" so the student always knows where they need to be without checking a messy gallery image.

### 3. Mess / Cafeteria Menu Tracker
* **Image-to-Menu:** Similar to the timetable, the user uploads a picture of the hostel/mess menu.
* **Structured Data:** The AI structures this into Breakfast, Lunch, Snacks, and Dinner for each day of the week.
* **Quick Glance:** A home screen widget or dashboard card showing exactly what is being served for the next meal.

---

## 🛠️ Recommended Technology Stack

Since this is a mobile application that will rely heavily on AI, here is a recommended modern stack:

* **Frontend:** **Flutter** or **React Native**. These frameworks allow you to build for both Android and iOS from a single codebase. Flutter is highly recommended for building beautiful, custom UIs quickly.
* **Backend & Database:** **Firebase** or **Supabase**. Perfect for open-source projects. They provide authentication, real-time databases, and cloud storage (for the uploaded images).
* **AI Provider:** **Google Gemini API**. Gemini is exceptionally good at multimodal tasks—meaning it can handle the text analysis (Diary) AND the vision tasks (extracting data from Timetable/Menu images) using a single, unified API.
* **Local Storage:** It's crucial that things like the timetable and mess menu are available offline. We can use local databases like SQLite (or Hive/Isar in Flutter) to cache this data.

---

## 🗺️ Step-by-Step Roadmap

To build this slowly and sustainably, we should follow a phased approach:

### Phase 1: The AI Diary Foundation
* Setup the basic mobile app shell and navigation.
* Build the Daily Diary writing interface.
* Integrate the AI API to process diary entries and automatically extract Tasks and Due Dates.
* Build a simple Task List UI to display the extracted tasks.

### Phase 2: The Vision Features
* Build image upload capabilities.
* Prompt engineering: Design the AI prompts to accurately extract Timetable and Mess Menu data from images into structured JSON.
* Build the UI to display the daily schedule and current meals.

### Phase 3: The Unified Dashboard
* Create a master "Home" screen that acts as the ultimate daily dashboard.
* It should show: "Current Meal", "Next Class", "Pending Tasks", and a prompt to "Write today's diary".

### Phase 4: Weekly Insights & Polish
* Implement the background AI logic to generate weekly summaries and life suggestions from the diary history.
* UI polish, animations, and preparing for open-source release.

---

## 💡 App Name Ideas (For Fun!)

**Short & Punchy**
* **Sync** - Simple and implies getting everything organized.
* **Node** - A central point for all your college info.
* **Orbit** - Managing the things revolving around your day.
* **Pulse** - Keeping a finger on the pulse of your daily life.

**Academic & Campus Focused**
* **ScholarSync**
* **UniNode**
* **UniSync**
* **CampusCompanion**

**Daily Routine & Diary Focused**
* **DailyMind**
* **MindLog**
* **DaySync**
* **StudentFlow**
* **RoutineAI**
* **DailyScholar**
