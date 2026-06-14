package com.luanlourenco.sentinela

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.text.SimpleDateFormat
import java.util.Locale

// ---------- Modelos ----------

enum class Nivel { OK, ATENCAO, CRITICO }

data class Risco(
    val titulo: String,
    val detalhe: String,
    val nivel: Nivel,
    val rotuloAcao: String? = null,
    val abrir: ((Context) -> Unit)? = null,
)

// ---------- Detector de espião (vetores reais de stalkerware/malware) ----------

/** Nome legível do pacote, ou o próprio pacote se não achar. */
private fun rotulo(ctx: Context, pkg: String): String =
    runCatching {
        val pm = ctx.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    }.getOrDefault(pkg)

/** Apps com serviço de Acessibilidade ATIVO (podem ler tela e simular toques). */
fun appsComAcessibilidade(ctx: Context): List<String> {
    val raw = Settings.Secure.getString(
        ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
    )
    if (raw.isNullOrBlank()) return emptyList()
    return raw.split(':').mapNotNull { it.substringBefore('/').trim().ifBlank { null } }
        .distinct().map { rotulo(ctx, it) }
}

/** Apps com acesso à leitura de NOTIFICAÇÕES (podem ler tudo que chega: SMS, OTP, mensagens). */
fun appsComAcessoNotificacoes(ctx: Context): List<String> {
    val raw = Settings.Secure.getString(ctx.contentResolver, "enabled_notification_listeners")
    if (raw.isNullOrBlank()) return emptyList()
    return raw.split(':').mapNotNull {
        ComponentName.unflattenFromString(it.trim())?.packageName
    }.distinct().map { rotulo(ctx, it) }
}

/** Apps que são ADMINISTRADORES do dispositivo (podem bloquear/limpar o aparelho). */
fun appsAdminDispositivo(ctx: Context): List<String> {
    val dpm = ctx.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        ?: return emptyList()
    val ativos = runCatching { dpm.activeAdmins }.getOrNull() ?: return emptyList()
    return ativos.map { it.packageName }.distinct().map { rotulo(ctx, it) }
}

// ---------- Postura do aparelho + Score ----------

private fun mesesDesde(patch: String): Int? = runCatching {
    val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
    val d = fmt.parse(patch) ?: return null
    val dias = (System.currentTimeMillis() - d.time) / 86_400_000L
    (dias / 30).toInt()
}.getOrNull()

private fun usbDepuracaoLigada(ctx: Context): Boolean =
    runCatching {
        Settings.Global.getInt(ctx.contentResolver, Settings.Global.ADB_ENABLED, 0) == 1
    }.getOrDefault(false)

/** Lista de riscos da postura + espiões. Ordenada por gravidade. Cada um pode ter ação de correção. */
fun diagnostico(ctx: Context): List<Risco> {
    val out = mutableListOf<Risco>()

    val km = ctx.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    if (km.isDeviceSecure) {
        out.add(Risco("Bloqueio de tela", "Ativo (PIN, padrão ou biometria).", Nivel.OK))
    } else {
        out.add(Risco("Sem bloqueio de tela", "Qualquer um que pegue o aparelho entra. Ative agora.",
            Nivel.CRITICO, "Configurar") { abrirSeguranca(it) })
    }

    if (usbDepuracaoLigada(ctx)) {
        out.add(Risco("Depuração USB ligada", "Permite acesso via cabo/ADB. Desligue se não estiver usando.",
            Nivel.ATENCAO, "Opções do desenvolvedor") { abrirOpcoesDesenvolvedor(it) })
    } else {
        out.add(Risco("Depuração USB", "Desligada.", Nivel.OK))
    }

    val acess = appsComAcessibilidade(ctx)
    if (acess.isNotEmpty()) {
        out.add(Risco("Acessibilidade ativa (${acess.size})",
            "Apps que podem ver sua tela e tocar por você: ${acess.joinToString(", ")}. " +
                "Confirme se você reconhece todos.",
            Nivel.CRITICO, "Revisar") { abrirAcessibilidade(it) })
    } else {
        out.add(Risco("Acessibilidade", "Nenhum app com acesso.", Nivel.OK))
    }

    val notif = appsComAcessoNotificacoes(ctx)
    if (notif.isNotEmpty()) {
        out.add(Risco("Leem suas notificações (${notif.size})",
            "Podem ler SMS, códigos e mensagens que chegam: ${notif.joinToString(", ")}.",
            Nivel.ATENCAO, "Revisar") { abrirAcessoNotificacoes(it) })
    } else {
        out.add(Risco("Acesso a notificações", "Nenhum app com acesso.", Nivel.OK))
    }

    val admins = appsAdminDispositivo(ctx)
    if (admins.isNotEmpty()) {
        out.add(Risco("Administradores do dispositivo (${admins.size})",
            "Podem bloquear ou apagar o aparelho: ${admins.joinToString(", ")}. " +
                "Apps de trabalho/antifurto são normais; o resto, desconfie.",
            Nivel.ATENCAO, "Revisar") { abrirAdminDispositivo(it) })
    }

    val meses = mesesDesde(Build.VERSION.SECURITY_PATCH)
    when {
        meses == null -> {}
        meses >= 6 -> out.add(Risco("Patch de segurança antigo",
            "Última atualização há ~$meses meses (${Build.VERSION.SECURITY_PATCH}). Procure atualizações.",
            Nivel.ATENCAO, "Atualizações") { abrirSeguranca(it) })
        else -> out.add(Risco("Patch de segurança",
            "Recente (${Build.VERSION.SECURITY_PATCH}).", Nivel.OK))
    }

    return out.sortedBy { it.nivel.ordinal }.reversed()
}

/** Score 0–100 a partir dos riscos (cada CRÍTICO pesa mais que ATENÇÃO). */
fun calcularScore(riscos: List<Risco>): Int {
    var s = 100
    riscos.forEach {
        when (it.nivel) {
            Nivel.CRITICO -> s -= 25
            Nivel.ATENCAO -> s -= 10
            Nivel.OK -> {}
        }
    }
    return s.coerceIn(0, 100)
}

// ---------- Atalhos do sistema (cada correção abre a tela certa) ----------

private fun abrir(ctx: Context, intent: Intent, fallback: String? = null) {
    runCatching { ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
        .onFailure { if (fallback != null) runCatching {
            ctx.startActivity(Intent(fallback).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } }
}

fun abrirSeguranca(ctx: Context) = abrir(ctx, Intent(Settings.ACTION_SECURITY_SETTINGS), Settings.ACTION_SETTINGS)
fun abrirAcessibilidade(ctx: Context) = abrir(ctx, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS), Settings.ACTION_SETTINGS)
fun abrirOpcoesDesenvolvedor(ctx: Context) =
    abrir(ctx, Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS), Settings.ACTION_SETTINGS)
fun abrirAdminDispositivo(ctx: Context) = abrir(ctx, Intent().setClassName(
    "com.android.settings", "com.android.settings.DeviceAdminSettings"), Settings.ACTION_SECURITY_SETTINGS)
fun abrirAcessoNotificacoes(ctx: Context) {
    val i = if (Build.VERSION.SDK_INT >= 30) Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
    else Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS")
    abrir(ctx, i, Settings.ACTION_SETTINGS)
}
fun abrirDetalhesApp(ctx: Context, pkg: String) =
    abrir(ctx, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$pkg")))
fun abrirPlayProtect(ctx: Context) =
    abrir(ctx, Intent("com.google.android.gms.settings.VERIFY_APPS_SETTINGS"), Settings.ACTION_SETTINGS)
