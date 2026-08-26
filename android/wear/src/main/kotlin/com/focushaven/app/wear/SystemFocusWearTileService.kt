package com.focushaven.app.wear

import android.content.ComponentName
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ResourceBuilders.Resources
import androidx.wear.protolayout.TimelineBuilders.Timeline
import androidx.wear.protolayout.material3.Typography.BODY_LARGE
import androidx.wear.protolayout.material3.Typography.BODY_MEDIUM
import androidx.wear.protolayout.material3.materialScope
import androidx.wear.protolayout.material3.primaryLayout
import androidx.wear.protolayout.material3.text
import androidx.wear.protolayout.modifiers.clickable
import androidx.wear.protolayout.types.layoutString
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.RequestBuilders.ResourcesRequest
import androidx.wear.tiles.TileBuilders.Tile
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures

/** A private, read-only timer Tile. Timer commands remain inside the full Watch app. */
class SystemFocusWearTileService : TileService() {
    override fun onTileRequest(requestParams: RequestBuilders.TileRequest) =
        Futures.immediateFuture(
            Tile.Builder()
                .setResourcesVersion(RESOURCES_VERSION)
                .setFreshnessIntervalMillis(FRESHNESS_INTERVAL_MILLIS)
                .setTileTimeline(
                    Timeline.fromLayoutElement(
                        materialScope(this, requestParams.deviceConfiguration) {
                            val content =
                                SystemFocusWearSnapshotStore(this@SystemFocusWearTileService)
                                    .read()
                                    ?.let(SystemFocusWearGlanceContent::from)
                            primaryLayout(
                                onClick = clickable(ActionBuilders.launchAction(openAppComponent)),
                                titleSlot = {
                                    text(
                                        getString(R.string.tile_title).layoutString,
                                        typography = BODY_MEDIUM,
                                    )
                                },
                                mainSlot = {
                                    if (content == null) {
                                        text(
                                            getString(R.string.tile_sync_required).layoutString,
                                            typography = BODY_LARGE,
                                        )
                                    } else {
                                        LayoutElementBuilders.Column.Builder()
                                            .addContent(
                                                text(
                                                    content.compactTime.layoutString,
                                                    typography = BODY_LARGE,
                                                ),
                                            )
                                            .addContent(
                                                text(
                                                    getString(content.session.labelResource)
                                                        .layoutString,
                                                    typography = BODY_MEDIUM,
                                                ),
                                            )
                                            .addContent(
                                                text(
                                                    getString(content.activity.labelResource)
                                                        .layoutString,
                                                    typography = BODY_MEDIUM,
                                                ),
                                            )
                                            .build()
                                    }
                                },
                                bottomSlot = {
                                    text(
                                        getString(R.string.tile_open_app).layoutString,
                                        typography = BODY_MEDIUM,
                                    )
                                },
                            )
                        },
                    ),
                )
                .build(),
        )

    override fun onTileResourcesRequest(requestParams: ResourcesRequest) =
        Futures.immediateFuture(
            Resources.Builder().setVersion(RESOURCES_VERSION).build(),
        )

    private val openAppComponent: ComponentName
        get() = ComponentName(this, FocusHavenWearActivity::class.java)

    private val SystemFocusWearSession.labelResource: Int
        get() =
            when (this) {
                SystemFocusWearSession.FOCUS -> R.string.session_focus
                SystemFocusWearSession.SHORT_BREAK -> R.string.session_short_break
                SystemFocusWearSession.LONG_BREAK -> R.string.session_long_break
            }

    private val SystemFocusWearActivity.labelResource: Int
        get() =
            when (this) {
                SystemFocusWearActivity.READY -> R.string.activity_ready
                SystemFocusWearActivity.RUNNING -> R.string.activity_running
                SystemFocusWearActivity.PAUSED -> R.string.activity_paused
                SystemFocusWearActivity.COMPLETED -> R.string.activity_completed
                SystemFocusWearActivity.PENDING_RESUME -> R.string.activity_pending_resume
            }

    private companion object {
        const val RESOURCES_VERSION = "1"
        const val FRESHNESS_INTERVAL_MILLIS = 60_000L
    }
}
