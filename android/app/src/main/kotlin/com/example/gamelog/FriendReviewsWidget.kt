package com.example.gamelog

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import android.app.PendingIntent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.net.URL

class FriendReviewsWidget : AppWidgetProvider() {
    
    companion object {
        private const val ACTION_NEXT_REVIEW = "com.example.gamelog.ACTION_NEXT_REVIEW"
        private const val ACTION_PREV_REVIEW = "com.example.gamelog.ACTION_PREV_REVIEW"
        private const val ACTION_OPEN_GAME = "com.example.gamelog.ACTION_OPEN_GAME"
        private const val EXTRA_GAME_ID = "gameId"
        private var currentReviewIndex = 0
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, FriendReviewsWidget::class.java)
        )
        
        when (intent.action) {
            ACTION_NEXT_REVIEW -> {
                // Cycle to next review
                val widgetData = HomeWidgetPlugin.getData(context)
                val reviewsCount = widgetData.getInt("reviews_count", 0)
                if (reviewsCount > 0) {
                    currentReviewIndex = (currentReviewIndex + 1) % reviewsCount
                }
                
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_PREV_REVIEW -> {
                // Cycle to previous review
                val widgetData = HomeWidgetPlugin.getData(context)
                val reviewsCount = widgetData.getInt("reviews_count", 0)
                if (reviewsCount > 0) {
                    currentReviewIndex = if (currentReviewIndex == 0) {
                        reviewsCount - 1
                    } else {
                        currentReviewIndex - 1
                    }
                }
                
                for (appWidgetId in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_OPEN_GAME -> {
                // Open the app and navigate to game detail
                val gameId = intent.getStringExtra(EXTRA_GAME_ID)
                val launchIntent = Intent(context, MainActivity::class.java)
                launchIntent.apply {
                    action = Intent.ACTION_VIEW
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("gameId", gameId)
                    putExtra("openGameDetail", true)
                }
                context.startActivity(launchIntent)
            }
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val reviewsJson = widgetData.getString("reviews_data", "[]")
        val reviewsCount = widgetData.getInt("reviews_count", 0)
        val state = widgetData.getString("state", "loading")

        val views = RemoteViews(context.packageName, R.layout.friend_reviews_widget)

        when (state) {
            "no_reviews", "no_user" -> {
                // Show empty state
                views.setViewVisibility(R.id.review_card, View.GONE)
                views.setViewVisibility(R.id.empty_state, View.VISIBLE)
                views.setTextViewText(R.id.widget_subtitle, "")
            }
            "has_reviews" -> {
                // Show review card
                views.setViewVisibility(R.id.empty_state, View.GONE)
                views.setViewVisibility(R.id.review_card, View.VISIBLE)
                views.setTextViewText(R.id.widget_subtitle, "from friends ($reviewsCount)")

                try {
                    val reviewsArray = JSONArray(reviewsJson)
                    if (reviewsArray.length() > 0) {
                        // Ensure index is within bounds
                        if (currentReviewIndex >= reviewsArray.length()) {
                            currentReviewIndex = 0
                        }
                        
                        val review = reviewsArray.getJSONObject(currentReviewIndex)
                        val username = review.getString("username")
                        val gameTitle = review.getString("gameTitle")
                        val rating = review.getDouble("rating")
                        val likeCount = review.getInt("likeCount")
                        val reviewText = review.getString("review")
                        val coverUrl = review.optString("coverUrl", "")
                        val profileImage = review.optString("profileImage", "")

                        // Update game title
                        views.setTextViewText(R.id.game_title, gameTitle)
                        
                        // Update page indicator
                        views.setTextViewText(
                            R.id.page_indicator, 
                            "${currentReviewIndex + 1} of ${reviewsArray.length()}"
                        )
                        views.setViewVisibility(R.id.page_indicator, View.VISIBLE)

                        // Update rating
                        views.setTextViewText(R.id.rating_value, String.format("%.0f", rating))

                        // Update like count
                        views.setTextViewText(R.id.like_count, likeCount.toString())

                        // Update review text
                        if (reviewText.isNotEmpty()) {
                            views.setTextViewText(R.id.review_text, reviewText)
                        } else {
                            views.setTextViewText(R.id.review_text, "No review text")
                        }

                        // Update username
                        views.setTextViewText(R.id.username, username)
                        
                        // Set up previous button
                        val prevIntent = Intent(context, FriendReviewsWidget::class.java)
                        prevIntent.action = ACTION_PREV_REVIEW
                        val prevPendingIntent = PendingIntent.getBroadcast(
                            context,
                            1,
                            prevIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.prev_button, prevPendingIntent)
                        
                        // Set up next button
                        val nextIntent = Intent(context, FriendReviewsWidget::class.java)
                        nextIntent.action = ACTION_NEXT_REVIEW
                        val nextPendingIntent = PendingIntent.getBroadcast(
                            context,
                            2,
                            nextIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.next_button, nextPendingIntent)
                        
                        // Set up card click to open game in app
                        val openGameIntent = Intent(context, FriendReviewsWidget::class.java)
                        openGameIntent.action = ACTION_OPEN_GAME
                        openGameIntent.putExtra(EXTRA_GAME_ID, review.getString("gameId"))
                        val openGamePendingIntent = PendingIntent.getBroadcast(
                            context,
                            3,
                            openGameIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        views.setOnClickPendingIntent(R.id.review_card, openGamePendingIntent)
                        
                        // Show/hide navigation buttons based on review count
                        if (reviewsArray.length() > 1) {
                            views.setViewVisibility(R.id.prev_button, View.VISIBLE)
                            views.setViewVisibility(R.id.next_button, View.VISIBLE)
                        } else {
                            views.setViewVisibility(R.id.prev_button, View.GONE)
                            views.setViewVisibility(R.id.next_button, View.GONE)
                        }
                        
                        // Load game cover image
                        if (coverUrl.isNotEmpty()) {
                            Thread {
                                try {
                                    val bitmap = loadImageFromUrl(coverUrl)
                                    if (bitmap != null) {
                                        views.setImageViewBitmap(R.id.game_cover, bitmap)
                                        appWidgetManager.updateAppWidget(appWidgetId, views)
                                    }
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }.start()
                        }
                        
                        // Load user profile image
                        if (profileImage.isNotEmpty()) {
                            Thread {
                                try {
                                    val bitmap = loadImageFromUrl(profileImage)
                                    if (bitmap != null) {
                                        views.setImageViewBitmap(R.id.user_avatar, bitmap)
                                        appWidgetManager.updateAppWidget(appWidgetId, views)
                                    }
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }.start()
                        }
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    views.setTextViewText(R.id.review_text, "Error loading reviews")
                }
            }
            else -> {
                // Loading state
                views.setViewVisibility(R.id.review_card, View.VISIBLE)
                views.setViewVisibility(R.id.empty_state, View.GONE)
                views.setTextViewText(R.id.widget_subtitle, "Loading...")
                views.setTextViewText(R.id.review_text, "Fetching friend reviews...")
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    private fun loadImageFromUrl(urlString: String): Bitmap? {
        return try {
            val url = URL(urlString)
            BitmapFactory.decodeStream(url.openConnection().getInputStream())
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    override fun onEnabled(context: Context) {
        currentReviewIndex = 0
    }

    override fun onDisabled(context: Context) {
        currentReviewIndex = 0
    }
}
