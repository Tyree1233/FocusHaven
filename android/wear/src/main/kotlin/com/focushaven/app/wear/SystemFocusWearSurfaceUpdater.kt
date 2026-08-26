package com.focushaven.app.wear

import android.content.ComponentName
import android.content.Context
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester

internal object SystemFocusWearSurfaceUpdater {
    fun request(context: Context) {
        TileService.getUpdater(context)
            .requestUpdate(SystemFocusWearTileService::class.java)
        ComplicationDataSourceUpdateRequester.create(
            context,
            ComponentName(context, SystemFocusWearComplicationDataSourceService::class.java),
        ).requestUpdateAll()
    }
}
