package io.github.partorg.myfoodmind

import android.content.Intent
import android.net.Uri
import android.provider.Settings
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
        // Camera denied: the app's own settings page, where the permission is turned back on.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "myfoodmind/system").setMethodCallHandler { call, result ->
            if (call.method == "appSettings") {
                startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}
