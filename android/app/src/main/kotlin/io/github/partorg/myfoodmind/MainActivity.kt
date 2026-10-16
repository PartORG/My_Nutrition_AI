package io.github.partorg.myfoodmind

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FragmentActivity: required by local_auth (fingerprint unlock).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Cook mode: the screen stays on while the user cooks with wet hands.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myfoodmind/screen").setMethodCallHandler { call, result ->
            if (call.method == "keepOn") {
                if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
