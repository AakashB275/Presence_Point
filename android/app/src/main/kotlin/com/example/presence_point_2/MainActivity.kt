package com.sagar.presence_point_2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.activity.OnBackPressedCallback
import androidx.activity.OnBackPressedDispatcher

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.sagar.presence_point_2/backButton"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            result.success(null)
        }
        
        // Add a callback to the back button dispatcher
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("backButtonPressed", null)
            }
        })
    }
}