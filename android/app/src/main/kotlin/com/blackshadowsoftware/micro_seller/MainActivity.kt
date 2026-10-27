package com.blackshadowsoftware.micro_seller

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// `local_auth` requires a FragmentActivity (not a plain FlutterActivity)
// to host its BiometricPrompt — without this, biometric calls throw
// `no_fragment_activity` at runtime.
class MainActivity : FlutterFragmentActivity() {
    private var deviceChannel: DeviceChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Registers the plugins first.
        super.configureFlutterEngine(flutterEngine)
        deviceChannel = DeviceChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        deviceChannel?.dispose()
        deviceChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
