package com.example1.roadeyeai

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Fix black screen
        window?.setBackgroundDrawableResource(android.R.color.transparent)
    }
}