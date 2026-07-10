package com.example.orbit.widget

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.action.actionParametersOf
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
import androidx.glance.text.TextDecoration
import androidx.glance.unit.ColorProvider
import com.example.orbit.MainActivity

class TasksWidget : GlanceAppWidget() {
    override val stateDefinition = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val tasks = TasksWidgetUpdater.getTasks(context)
            TasksWidgetContent(context, tasks)
        }
    }

    @Composable
    private fun TasksWidgetContent(context: Context, tasks: List<TaskItem>) {
        val darkBgColor = Color(0x66111214) // Translucent background (40% opacity)
        val cardColor = Color(0xCC1C1D21) // Translucent card background (80% opacity)
        val textSecondaryColor = Color(0xFF9EA1AC)
        val textPrimaryColor = Color.White
        val accentColor = Color(0xFF5A84F2)

        val deepLinkIntent_tasks = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("orbit://app/home/tasks")
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
                // Header Title: Centered, tapping deep links into the app
                Box(
                    modifier = GlanceModifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .clickable(actionStartActivity(deepLinkIntent_tasks)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Today's Tasks",
                        style = TextStyle(
                            color = ColorProvider(textPrimaryColor),
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Bold
                        )
                    )
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
                if (tasks.isEmpty()) {
                    Box(
                        modifier = GlanceModifier
                            .fillMaxSize()
                            .clickable(actionStartActivity(deepLinkIntent_tasks)),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "No Tasks Today 🎉",
                            style = TextStyle(
                                color = ColorProvider(textSecondaryColor),
                                fontSize = 15.sp,
                                fontWeight = FontWeight.Medium
                            )
                        )
                    }
                } else {
                    LazyColumn(modifier = GlanceModifier.fillMaxSize()) {
                        items(tasks) { item ->
                            Box(
                                modifier = GlanceModifier.padding(bottom = 10.dp)
                            ) {
                                TaskItemRow(
                                    item = item,
                                    cardBg = cardColor,
                                    textPrimary = textPrimaryColor,
                                    textSecondary = textSecondaryColor,
                                    accent = accentColor,
                                    launchIntent = deepLinkIntent_tasks
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @Composable
    private fun TaskItemRow(
        item: TaskItem,
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
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Circular Checkbox
                Box(
                    modifier = GlanceModifier
                        .width(24.dp)
                        .height(24.dp)
                        .cornerRadius(12.dp)
                        .background(if (item.isCompleted) accent else Color(0xFF33353C))
                        .clickable(actionRunCallback<ToggleTaskStatusAction>(
                            actionParametersOf(
                                ToggleTaskStatusAction.taskIdKey to item.id,
                                ToggleTaskStatusAction.isCompletedKey to !item.isCompleted
                            )
                        )),
                    contentAlignment = Alignment.Center
                ) {
                    if (item.isCompleted) {
                        Text(
                            text = "✓",
                            style = TextStyle(
                                color = ColorProvider(Color.White),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Bold
                            )
                        )
                    }
                }

                Spacer(modifier = GlanceModifier.width(12.dp))

                // Task Title
                Text(
                    text = item.title,
                    maxLines = 2,
                    style = TextStyle(
                        color = ColorProvider(if (item.isCompleted) textSecondary else textPrimary),
                        fontSize = 14.sp,
                        fontWeight = if (item.isCompleted) FontWeight.Normal else FontWeight.Medium,
                        textDecoration = if (item.isCompleted) TextDecoration.LineThrough else null
                    )
                )
            }
        }
    }
}
