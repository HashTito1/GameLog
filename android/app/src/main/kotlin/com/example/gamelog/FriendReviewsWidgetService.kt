package com.example.gamelog

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.net.URL
import kotlinx.coroutines.*

class FriendReviewsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return FriendReviewsRemoteViewsFactory(this.applicationContext)
    }
}

class FriendReviewsRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var reviews = ArrayList<ReviewItem>()

    data class ReviewItem(
        val username: String,
        val gameTitle: String,
        val rating: Double,
        val likeCount: Int,
        val reviewText: String,
        val coverUrl: String,
        val profileImage: String
    )

    override fun onCreate() {
        // Initialize
    }

    override fun onDataSetChanged() {
        // Load data from shared preferences
        val widgetData = HomeWidgetPlugin.getData(context)
        val reviewsJson = widgetData.getString("reviews_data", "[]")
        
        reviews.clear()
        
        try {
            val reviewsArray = JSONArray(reviewsJson)
            for (i in 0 until reviewsArray.length()) {
                val review = reviewsArray.getJSONObject(i)
                reviews.add(
                    ReviewItem(
                        username = review.getString("username"),
                        gameTitle = review.getString("gameTitle"),
                        rating = review.getDouble("rating"),
                        likeCount = review.getInt("likeCount"),
                        reviewText = review.getString("review"),
                        coverUrl = review.optString("coverUrl", ""),
                        profileImage = review.optString("profileImage", "")
                    )
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        reviews.clear()
    }

    override fun getCount(): Int {
        return reviews.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_review_item)
        
        if (position < reviews.size) {
            val review = reviews[position]
            
            // Set rating
            views.setTextViewText(R.id.rating_value, String.format("%.0f", review.rating))
            
            // Set like count
            views.setTextViewText(R.id.like_count, review.likeCount.toString())
            
            // Set review text
            if (review.reviewText.isNotEmpty()) {
                views.setTextViewText(R.id.review_text, review.reviewText)
            } else {
                views.setTextViewText(R.id.review_text, "No review text")
            }
            
            // Set username
            views.setTextViewText(R.id.username, review.username)
            
            // Load game cover image
            if (review.coverUrl.isNotEmpty()) {
                try {
                    val bitmap = loadImageFromUrl(review.coverUrl)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.game_cover, bitmap)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            
            // Load user profile image
            if (review.profileImage.isNotEmpty()) {
                try {
                    val bitmap = loadImageFromUrl(review.profileImage)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.user_avatar, bitmap)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
            
            // Set up click intent to open the app
            val fillInIntent = Intent()
            fillInIntent.putExtra("gameId", review.gameTitle)
            views.setOnClickFillInIntent(R.id.game_cover, fillInIntent)
        }
        
        return views
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

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }
}
