package com.luanlourenco.sentinela

import android.app.Application
import java.io.PrintWriter
import java.io.StringWriter

const val VERSAO_APP = "1.0"

/**
 * Captura crashes não tratados e salva a mensagem para exibir na próxima abertura
 * (em vez de o app só "fechar"). Diagnóstico sem precisar de logcat — lição da Faxina.
 */
class App : Application() {
    override fun onCreate() {
        super.onCreate()
        val anterior = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, erro ->
            try {
                val sw = StringWriter()
                erro.printStackTrace(PrintWriter(sw))
                getSharedPreferences("sentinela", MODE_PRIVATE).edit()
                    .putString("ultimo_erro", "Sentinela v$VERSAO_APP\n$erro\n\n$sw").apply()
            } catch (_: Throwable) { /* nunca falhar dentro do handler */ }
            anterior?.uncaughtException(thread, erro)
        }
    }
}
