package com.blackshadowsoftware.micro_seller

import io.flutter.embedding.android.FlutterFragmentActivity

// `local_auth` requires a FragmentActivity (not a plain FlutterActivity)
// to host its BiometricPrompt — without this, biometric calls throw
// `no_fragment_activity` at runtime.
class MainActivity : FlutterFragmentActivity()
