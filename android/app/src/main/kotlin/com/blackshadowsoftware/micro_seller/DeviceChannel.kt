package com.blackshadowsoftware.micro_seller

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// The app's own channel, micro_seller/device (lib/data/services/
// device_channel.dart): what the plugins don't tell. Registered by
// MainActivity.configureFlutterEngine. minSdk is 24, so the Activity's own
// permission APIs (API 23) do without androidx.
class DeviceChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, NAME)

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "cameraStatus" -> result.success(cameraStatus())
            "openAppSettings" -> result.success(openAppSettings())
            // Android can't tell a face from a fingerprint.
            "biometryType" -> result.success("unknown")
            else -> result.notImplemented()
        }
    }

    // Android has no "asked before" flag: a camera that was never asked for
    // reports permanentlyDenied too. Dart reads this after a refusal, when
    // the rationale flag tells "ask again" from "don't ask again".
    private fun cameraStatus(): String = when {
        activity.checkSelfPermission(Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED -> "granted"
        activity.shouldShowRequestPermissionRationale(Manifest.permission.CAMERA) ->
            "denied"
        else -> "permanentlyDenied"
    }

    // This app's page in the system's Settings (Permissions → Camera).
    private fun openAppSettings(): Boolean {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.fromParts("package", activity.packageName, null),
        ).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_NO_HISTORY or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
        )
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val NAME = "micro_seller/device"
    }
}
