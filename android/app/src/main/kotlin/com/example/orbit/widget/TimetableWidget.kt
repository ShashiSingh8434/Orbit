package com.example.orbit.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.example.orbit.MainActivity


class TimetableWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<Preferences>()
            val selectedDayKey = stringPreferencesKey("widget_selected_day")
            val lastSelectedDateKey = stringPreferencesKey("widget_last_selected_date")

            val todayDateString = java.text.SimpleDateFormat("yyyy-MM-d", java.util.Locale.US).format(java.util.Date())
            val calendar = java.util.Calendar.getInstance()
            val dayOfWeek = calendar.get(java.util.Calendar.DAY_OF_WEEK)
            val todayWeekday = when (dayOfWeek) {
                java.util.Calendar.MONDAY -> "Monday"
                java.util.Calendar.TUESDAY -> "Tuesday"
                java.util.Calendar.WEDNESDAY -> "Wednesday"
                java.util.Calendar.THURSDAY -> "Thursday"
                java.util.Calendar.FRIDAY -> "Friday"
                java.util.Calendar.SATURDAY -> "Saturday"
                java.util.Calendar.SUNDAY -> "Sunday"
                else -> "Monday"
            }

            val lastSelectedDate = prefs[lastSelectedDateKey] ?: ""
            val selectedDay = if (lastSelectedDate == todayDateString) {
                prefs[selectedDayKey] ?: todayWeekday
            } else {
                todayWeekday
            }

            val classes = TimetableWidgetUpdater.getClassesForDay(context, selectedDay)
            val state = TimetableWidgetState(selectedDay, classes)

            TimetableWidgetContent(context, state)
        }
    }

    @Composable
    private fun TimetableWidgetContent(context: Context, state: TimetableWidgetState) {
        val darkBgColor = Color(0x66111214) // Translucent background (40% opacity)
        val cardColor = Color(0xCC1C1D21) // Translucent card background (80% opacity)
        val textSecondaryColor = Color(0xFF9EA1AC)
        val textPrimaryColor = Color.White
        val accentColor = Color(0xFF5A84F2)

        val deepLinkIntent_academic = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("orbit://app/home/academic")
        ).apply {
            setClass(context, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(darkBgColor)
                .cornerRadius(16.dp)
                .padding(12.dp)
        ) {
            Column(modifier = GlanceModifier.fillMaxSize()) {
                // Header Day Navigation
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Prev Day Button: 56dp tap target for comfortable touch
                    Box(
                        modifier = GlanceModifier
                            .width(56.dp)
                            .height(56.dp)
                            .cornerRadius(28.dp)
                            .clickable(actionRunCallback<PrevDayAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = " ← ",
                            style = TextStyle(
                                color = ColorProvider(textSecondaryColor),
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }

                    // Weekday Title: Centered, tapping deep links into the app
                    Box(
                        modifier = GlanceModifier
                            .defaultWeight()
                            .height(56.dp)
                            .clickable(actionStartActivity(deepLinkIntent_academic)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = state.selectedDay,
                            style = TextStyle(
                                color = ColorProvider(textPrimaryColor),
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }

                    // Reload Button: Resets to today's day and refreshes widget data
                    Box(
                        modifier = GlanceModifier
                            .width(56.dp)
                            .height(56.dp)
                            .cornerRadius(28.dp)
                            .clickable(actionRunCallback<ResetDayAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "↶",
                            style = TextStyle(
                                color = ColorProvider(textSecondaryColor),
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }

                    // Next Day Button: 56dp tap target for comfortable touch
                    Box(
                        modifier = GlanceModifier
                            .width(56.dp)
                            .height(56.dp)
                            .cornerRadius(28.dp)
                            .clickable(actionRunCallback<NextDayAction>()),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "→ ",
                            style = TextStyle(
                                color = ColorProvider(textSecondaryColor),
                                fontSize = 22.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.height(4.dp))
                // Separator Line
                Box(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .height(1.dp)
                        .background(Color(0x4D232529)) // Translucent separator
                ) {}
                Spacer(modifier = GlanceModifier.height(8.dp))

                // Schedule list display
                if (state.classes.isEmpty()) {
                    Box(
                        modifier = GlanceModifier
                            .fillMaxSize()
                            .clickable(actionStartActivity(deepLinkIntent_academic)),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            Text(
                                text = "No Classes Today 🎉",
                                style = TextStyle(
                                    color = ColorProvider(textSecondaryColor),
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Medium
                                )
                            )
                        }
                    }
                } else {
                    LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                        items(state.classes) { item ->
                            Box(
                                modifier = GlanceModifier.padding(bottom = 10.dp)
                            ) {
                                ClassItemRow(
                                    item = item,
                                    cardBg = cardColor,
                                    textPrimary = textPrimaryColor,
                                    textSecondary = textSecondaryColor,
                                    accent = accentColor,
                                    launchIntent = deepLinkIntent_academic
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun ClassItemRow(
        item: ClassSessionItem,
        cardBg: Color,
        textPrimary: Color,
        textSecondary: Color,
        accent: Color,
        launchIntent: Intent
    ) {
        Box(
            modifier = GlanceModifier
                .fillMaxWidth()
                .background(cardBg)
                .cornerRadius(12.dp)
                .padding(14.dp)
                .clickable(actionStartActivity(launchIntent))
        ) {
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                // Course Name (Bold, 2 lines max, Ellipsis handled by system)
                Text(
                    text = item.name,
                    maxLines = 2,
                    style = TextStyle(
                        color = ColorProvider(textPrimary),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                )

                Spacer(modifier = GlanceModifier.height(8.dp))

                // Slot, Venue and timings
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    // Timings (Left)
                    Text(
                        text = "${item.startTime} - ${item.endTime}",
                        style = TextStyle(
                            color = ColorProvider(textSecondary),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Normal
                        )
                    )

                    Spacer(modifier = GlanceModifier.defaultWeight())

                    // Venue (Centered)
                    Text(
                        text = item.room.ifEmpty { "N/A" },
                        style = TextStyle(
                            color = ColorProvider(textSecondary),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    )

                    Spacer(modifier = GlanceModifier.defaultWeight())

                    // Slot (Right)
                    Text(
                        text = item.slot,
                        style = TextStyle(
                            color = ColorProvider(accent),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
                    
                }
            }
        }
    }
}
