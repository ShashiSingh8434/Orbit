package com.example.orbit.widget

/**
 * Model representing a single class session parsed from Flutter timetable JSON payload.
 */
data class ClassSessionItem(
    val name: String,
    val code: String,
    val slot: String,
    val room: String,
    val startTime: String,
    val endTime: String
)

/**
 * State representing the currently displayed widget page (selected day and class sessions list).
 */
data class TimetableWidgetState(
    val selectedDay: String,
    val classes: List<ClassSessionItem>
)
