package com.focushaven.app

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HavenSystemAssistantAndroidNativeCopyTest {
    @Test
    fun copyAllowlistContainsExactlyTwentyEightReviewedKeys() {
        val keys = HavenSystemAssistantAndroidNativeCopyKey.entries

        assertEquals(28, keys.size)
        assertEquals(28, keys.map { it.resourceId }.toSet().size)
        assertTrue(keys.all { it.resourceId > 0 })
    }

    @Test
    fun everyTextFreeRouteMapsToDistinctReviewedCopy() {
        val mappings = HavenSystemAssistantAndroidRoute.entries.map { it.nativeCopyKeys }

        assertEquals(5, mappings.size)
        assertEquals(5, mappings.map { it.shortLabel }.toSet().size)
        assertEquals(5, mappings.map { it.longLabel }.toSet().size)
        assertEquals(5, mappings.map { it.invocationExample }.toSet().size)
    }

    @Test
    fun resourceLookupReturnsOnlyCompletePlaceholderFreeCopy() {
        val expectedId =
            HavenSystemAssistantAndroidNativeCopyKey.REVIEW_REQUIRED_RESULT.resourceId
        val copy =
            HavenSystemAssistantAndroidNativeCopy { resourceId ->
                if (resourceId == expectedId) {
                    "Open FocusHaven to review this request. Nothing has happened yet."
                } else {
                    null
                }
            }

        assertEquals(
            "Open FocusHaven to review this request. Nothing has happened yet.",
            copy.text(HavenSystemAssistantAndroidNativeCopyKey.REVIEW_REQUIRED_RESULT),
        )
        assertNull(copy.text(HavenSystemAssistantAndroidNativeCopyKey.REJECTED_RESULT))
    }

    @Test
    fun malformedOrParameterizedCopyFailsClosed() {
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid(""))
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid(" leading"))
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid("trailing "))
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid("line\nbreak"))
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid("duration %1\$s"))
        assertFalse(HavenSystemAssistantAndroidNativeCopy.isValid("task {task}"))
        assertFalse(
            HavenSystemAssistantAndroidNativeCopy.isValid(
                "a".repeat(HavenSystemAssistantAndroidNativeCopy.MAXIMUM_TEXT_UTF8_LENGTH + 1),
            ),
        )
        assertTrue(HavenSystemAssistantAndroidNativeCopy.isValid("Review in FocusHaven"))
    }

    @Test
    fun accessorOwnsCopyOnlyAndCannotRegisterOrSubmit() {
        val sourcePath =
            listOf(
                File(
                    "app/src/main/kotlin/com/focushaven/app/" +
                        "HavenSystemAssistantAndroidNativeCopy.kt",
                ),
                File(
                    "src/main/kotlin/com/focushaven/app/" +
                        "HavenSystemAssistantAndroidNativeCopy.kt",
                ),
            ).first(File::isFile)
        val source = sourcePath.readText()

        assertFalse(source.contains("ShortcutInfo"))
        assertFalse(source.contains("shortcuts.xml"))
        assertFalse(source.contains("Capability"))
        assertFalse(source.contains("queryPatterns"))
        assertFalse(source.contains("Intent("))
        assertFalse(source.contains(".submit("))
        assertFalse(source.contains("FlutterMethodChannel"))
        assertTrue(source.contains("Regex(\"\"\"\\{[^}]+\\}\"\"\")"))
        assertFalse(source.contains("Regex(\"\"\"\\{[^}]+}\"\"\")"))
    }
}
