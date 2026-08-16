package com.focushaven.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/** Private trampoline that validates a widget tap before opening Flutter. */
class FocusHavenWidgetCommandActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val queued =
            SystemFocusPendingCommandStore.enqueue(
                applicationContext,
                intent.getStringExtra(EXTRA_ACTION),
                intent.getStringExtra(EXTRA_SNAPSHOT_GENERATED_AT),
            )
        if (queued) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    flags =
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
            )
        }
        finish()
    }

    companion object {
        const val EXTRA_ACTION = "systemFocusAction"
        const val EXTRA_SNAPSHOT_GENERATED_AT = "systemFocusSnapshotGeneratedAt"
    }
}
