package com.luanlourenco.sentinela

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.security.GeneralSecurityException

/**
 * Testes unitarios JVM do nucleo de criptografia do cofre — rodam sem emulador
 * (so javax.crypto/java.security; nao tocam android.util.Base64). Sao a rede de
 * seguranca que sustenta refatorar o Cripto sem regredir a garantia de sigilo.
 */
class CriptoTest {

    private val salt = Cripto.aleatorio(16)

    @Test
    fun `chave derivada tem 256 bits`() {
        val chave = Cripto.derivarChave("senha-do-cofre".toCharArray(), salt)
        assertEquals(32, chave.encoded.size) // 256 bits
        assertEquals("AES", chave.algorithm)
    }

    @Test
    fun `mesma senha e salt derivam a mesma chave`() {
        val a = Cripto.derivarChave("senha".toCharArray(), salt)
        val b = Cripto.derivarChave("senha".toCharArray(), salt)
        assertArrayEquals(a.encoded, b.encoded)
    }

    @Test
    fun `salt diferente muda a chave`() {
        val a = Cripto.derivarChave("senha".toCharArray(), salt)
        val b = Cripto.derivarChave("senha".toCharArray(), Cripto.aleatorio(16))
        assertFalse(a.encoded.contentEquals(b.encoded))
    }

    @Test
    fun `cifrar e decifrar devolve o texto original`() {
        val chave = Cripto.derivarChave("senha".toCharArray(), salt)
        val claro = "conteudo secreto do cofre".toByteArray(Charsets.UTF_8)
        val recuperado = Cripto.decifrar(chave, Cripto.cifrar(chave, claro))
        assertArrayEquals(claro, recuperado)
    }

    @Test
    fun `saida tem IV de 12 e tag de 16 alem do texto`() {
        val chave = Cripto.derivarChave("senha".toCharArray(), salt)
        val claro = ByteArray(40)
        val saida = Cripto.cifrar(chave, claro)
        assertEquals(12 + claro.size + 16, saida.size)
    }

    @Test
    fun `IV aleatorio faz duas cifras do mesmo texto diferirem`() {
        val chave = Cripto.derivarChave("senha".toCharArray(), salt)
        val claro = "repetido".toByteArray()
        assertFalse(Cripto.cifrar(chave, claro).contentEquals(Cripto.cifrar(chave, claro)))
    }

    @Test
    fun `senha errada nao decifra`() {
        val certa = Cripto.derivarChave("certa".toCharArray(), salt)
        val errada = Cripto.derivarChave("errada".toCharArray(), salt)
        val cifrado = Cripto.cifrar(certa, "segredo".toByteArray())
        assertThrows(GeneralSecurityException::class.java) { Cripto.decifrar(errada, cifrado) }
    }

    @Test
    fun `conteudo adulterado e rejeitado pela autenticacao GCM`() {
        val chave = Cripto.derivarChave("senha".toCharArray(), salt)
        val cifrado = Cripto.cifrar(chave, "integro".toByteArray())
        cifrado[cifrado.size - 1] = (cifrado[cifrado.size - 1].toInt() xor 0x01).toByte()
        assertThrows(GeneralSecurityException::class.java) { Cripto.decifrar(chave, cifrado) }
    }

    @Test
    fun `texto vazio faz round-trip`() {
        val chave = Cripto.derivarChave("senha".toCharArray(), salt)
        assertEquals(0, Cripto.decifrar(chave, Cripto.cifrar(chave, ByteArray(0))).size)
    }

    @Test
    fun `aleatorio devolve o tamanho pedido e nao se repete`() {
        assertEquals(12, Cripto.aleatorio(12).size)
        assertFalse(Cripto.aleatorio(16).contentEquals(Cripto.aleatorio(16)))
    }
}
