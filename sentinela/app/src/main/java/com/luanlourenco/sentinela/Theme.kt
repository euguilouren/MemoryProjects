package com.luanlourenco.sentinela

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val EsquemaEscuro = darkColorScheme(
    primary = Color(0xFF5BD6A8),    // verde-escudo
    secondary = Color(0xFF7CC5FF),
    tertiary = Color(0xFFFFD678),
    background = Color(0xFF0E1512),
    surface = Color(0xFF161E1A),
    error = Color(0xFFFF8A80),
)

private val EsquemaClaro = lightColorScheme(
    primary = Color(0xFF006C4E),
    secondary = Color(0xFF00629D),
    tertiary = Color(0xFF7A5900),
)

@Composable
fun SentinelaTheme(content: @Composable () -> Unit) {
    val escuro = isSystemInDarkTheme()
    val ctx = LocalContext.current
    val esquema = when {
        Build.VERSION.SDK_INT >= 31 ->
            if (escuro) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        escuro -> EsquemaEscuro
        else -> EsquemaClaro
    }
    MaterialTheme(colorScheme = esquema, content = content)
}
