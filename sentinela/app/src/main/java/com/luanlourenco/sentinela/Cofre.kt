package com.luanlourenco.sentinela

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID
import javax.crypto.SecretKey

// ---------- Modelos ----------

data class ItemCofre(
    val id: String,
    val nome: String,
    val mime: String,
    val tamanho: Long,
    val data: Long,
)

/** Resultado de importar: o item criado e se o original foi removido do armazenamento aberto. */
data class ResultadoImport(val item: ItemCofre?, val originalApagado: Boolean)

/** Chave da sessão: existe só enquanto o cofre está desbloqueado, só em memória. */
object Sessao {
    @Volatile var chave: SecretKey? = null
    /** Suspende o auto-bloqueio por uma ida ao segundo plano (ex.: seletor de arquivos do sistema). */
    @Volatile var pausarAutoLock: Boolean = false
    val desbloqueado: Boolean get() = chave != null
    fun bloquear() { chave = null }
}

/**
 * Estado de acesso (senha mestra + tentativas + bloqueio). Guarda no SharedPreferences
 * apenas o salt e um VERIFICADOR cifrado — nunca a senha. Sem a senha certa, o
 * verificador não decifra e a chave não se forma.
 */
object Acesso {
    private const val PREF = "sentinela"
    private const val SALT = "salt"
    private const val VERIF = "verificador"
    private const val TENT = "tentativas"
    private const val BLOQ_ATE = "bloqueio_ate"
    private const val MAX_TENT = 3
    private const val BLOQUEIO_MS = 5 * 60_000L          // 5 min de espera após estourar
    private val CONST = "sentinela-ok".toByteArray()

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREF, Context.MODE_PRIVATE)

    fun senhaDefinida(ctx: Context): Boolean = prefs(ctx).getString(SALT, null) != null

    fun definirSenha(ctx: Context, senha: CharArray) {
        val salt = Cripto.aleatorio(16)
        val chave = Cripto.derivarChave(senha, salt)
        val verificador = Cripto.cifrar(chave, CONST)
        prefs(ctx).edit()
            .putString(SALT, Cripto.paraBase64(salt))
            .putString(VERIF, Cripto.paraBase64(verificador))
            .putInt(TENT, 0)
            .putLong(BLOQ_ATE, 0L)
            .apply()
        Sessao.chave = chave
    }

    /** Milissegundos restantes de bloqueio (0 = liberado). */
    fun bloqueioRestante(ctx: Context): Long =
        (prefs(ctx).getLong(BLOQ_ATE, 0L) - System.currentTimeMillis()).coerceAtLeast(0L)

    fun tentativasRestantes(ctx: Context): Int =
        (MAX_TENT - prefs(ctx).getInt(TENT, 0)).coerceAtLeast(0)

    sealed class Resultado {
        object Ok : Resultado()
        data class Errou(val restantes: Int) : Resultado()
        data class Bloqueado(val msRestante: Long) : Resultado()
    }

    fun desbloquear(ctx: Context, senha: CharArray): Resultado {
        val falta = bloqueioRestante(ctx)
        if (falta > 0) return Resultado.Bloqueado(falta)
        val salt = prefs(ctx).getString(SALT, null)?.let { Cripto.deBase64(it) }
            ?: return Resultado.Errou(MAX_TENT)
        val verif = prefs(ctx).getString(VERIF, null)?.let { Cripto.deBase64(it) }
            ?: return Resultado.Errou(MAX_TENT)
        val chave = Cripto.derivarChave(senha, salt)
        val ok = runCatching { Cripto.decifrar(chave, verif).contentEquals(CONST) }.getOrDefault(false)
        return if (ok) {
            Sessao.chave = chave
            prefs(ctx).edit().putInt(TENT, 0).apply()
            Resultado.Ok
        } else {
            val tent = prefs(ctx).getInt(TENT, 0) + 1
            val e = prefs(ctx).edit().putInt(TENT, tent)
            if (tent >= MAX_TENT) {
                e.putLong(BLOQ_ATE, System.currentTimeMillis() + BLOQUEIO_MS).putInt(TENT, 0)
                e.apply()
                Resultado.Bloqueado(BLOQUEIO_MS)
            } else {
                e.apply()
                Resultado.Errou(MAX_TENT - tent)
            }
        }
    }
}

/**
 * O cofre em si: arquivos cifrados em armazenamento PRIVADO do app (filesDir/cofre),
 * invisíveis para a galeria e outros apps. Índice em JSON (sem dados sensíveis no claro).
 */
object Cofre {
    private fun dir(ctx: Context): File = File(ctx.filesDir, "cofre").apply { mkdirs() }
    private fun indiceArq(ctx: Context): File = File(dir(ctx), "indice.json")

    fun listar(ctx: Context): List<ItemCofre> {
        val arq = indiceArq(ctx)
        if (!arq.exists()) return emptyList()
        return runCatching {
            val arr = JSONArray(arq.readText())
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                ItemCofre(
                    o.getString("id"), o.getString("nome"), o.optString("mime", "*/*"),
                    o.optLong("tamanho", 0), o.optLong("data", 0),
                )
            }.sortedByDescending { it.data }
        }.getOrDefault(emptyList())
    }

    private fun salvarIndice(ctx: Context, itens: List<ItemCofre>) {
        val arr = JSONArray()
        itens.forEach {
            arr.put(JSONObject().apply {
                put("id", it.id); put("nome", it.nome); put("mime", it.mime)
                put("tamanho", it.tamanho); put("data", it.data)
            })
        }
        indiceArq(ctx).writeText(arr.toString())
    }

    /**
     * MOVE o conteúdo para o cofre: lê (SAF), cifra, guarda e **apaga o original**
     * do armazenamento de origem. Se não conseguir apagar (provedor não permite),
     * o item é guardado mesmo assim e avisamos para apagar manualmente.
     */
    fun importar(ctx: Context, uri: Uri): ResultadoImport {
        val chave = Sessao.chave ?: return ResultadoImport(null, false)
        val item = runCatching {
            val (nome, tamanho) = metadados(ctx, uri)
            val mime = ctx.contentResolver.getType(uri) ?: "*/*"
            val claro = ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: return ResultadoImport(null, false)
            val id = UUID.randomUUID().toString()
            File(dir(ctx), "$id.enc").writeBytes(Cripto.cifrar(chave, claro))
            val it = ItemCofre(id, nome, mime, tamanho.takeIf { t -> t > 0 } ?: claro.size.toLong(),
                System.currentTimeMillis())
            salvarIndice(ctx, listar(ctx) + it)
            it
        }.getOrNull() ?: return ResultadoImport(null, false)

        // Tenta remover o original (move, não copia). Best-effort: depende do provedor SAF.
        val apagado = runCatching {
            DocumentsContract.deleteDocument(ctx.contentResolver, uri)
        }.getOrDefault(false)
        return ResultadoImport(item, apagado)
    }

    /** Conteúdo decifrado (para visualizar imagem ou exportar). Null se senha/chave ausente. */
    fun conteudo(ctx: Context, id: String): ByteArray? {
        val chave = Sessao.chave ?: return null
        val arq = File(dir(ctx), "$id.enc")
        if (!arq.exists()) return null
        return runCatching { Cripto.decifrar(chave, arq.readBytes()) }.getOrNull()
    }

    fun remover(ctx: Context, id: String) {
        File(dir(ctx), "$id.enc").delete()
        salvarIndice(ctx, listar(ctx).filterNot { it.id == id })
    }

    private fun metadados(ctx: Context, uri: Uri): Pair<String, Long> {
        var nome = "arquivo"
        var tamanho = 0L
        runCatching {
            ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
                val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val si = c.getColumnIndex(OpenableColumns.SIZE)
                if (c.moveToFirst()) {
                    if (ni >= 0) nome = c.getString(ni) ?: nome
                    if (si >= 0 && !c.isNull(si)) tamanho = c.getLong(si)
                }
            }
        }
        return nome to tamanho
    }
}
