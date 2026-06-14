package com.luanlourenco.sentinela

import android.util.Base64
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Criptografia do cofre. Tudo derivado da SENHA do usuário — sem a senha, o
 * conteúdo é matematicamente inacessível (não há "porta dos fundos" no app).
 *
 * - Chave: PBKDF2-HMAC-SHA256 (120k iterações) sobre a senha + salt aleatório.
 * - Conteúdo: AES-256/GCM (autenticado) com IV aleatório por arquivo.
 * A chave derivada vive só em memória após o desbloqueio; nunca é gravada.
 */
object Cripto {
    private const val ITERACOES = 120_000
    private const val TAM_CHAVE = 256
    private const val TAM_IV = 12     // bytes (recomendado para GCM)
    private const val TAM_TAG = 128   // bits

    private val rng = SecureRandom()

    fun aleatorio(n: Int): ByteArray = ByteArray(n).also { rng.nextBytes(it) }

    fun derivarChave(senha: CharArray, salt: ByteArray): SecretKey {
        val spec = PBEKeySpec(senha, salt, ITERACOES, TAM_CHAVE)
        val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
            .generateSecret(spec).encoded
        spec.clearPassword()
        return SecretKeySpec(bytes, "AES")
    }

    /** Retorna IV(12) || ciphertext(+tag). */
    fun cifrar(chave: SecretKey, claro: ByteArray): ByteArray {
        val iv = aleatorio(TAM_IV)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, chave, GCMParameterSpec(TAM_TAG, iv))
        val ct = c.doFinal(claro)
        return iv + ct
    }

    /** Espera IV(12) || ciphertext. Lança se a chave (senha) estiver errada. */
    fun decifrar(chave: SecretKey, dados: ByteArray): ByteArray {
        val iv = dados.copyOfRange(0, TAM_IV)
        val ct = dados.copyOfRange(TAM_IV, dados.size)
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, chave, GCMParameterSpec(TAM_TAG, iv))
        return c.doFinal(ct)
    }

    fun paraBase64(b: ByteArray): String = Base64.encodeToString(b, Base64.NO_WRAP)
    fun deBase64(s: String): ByteArray = Base64.decode(s, Base64.NO_WRAP)
}
