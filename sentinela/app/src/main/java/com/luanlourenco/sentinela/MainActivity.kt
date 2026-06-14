package com.luanlourenco.sentinela

import android.graphics.BitmapFactory
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { SentinelaTheme { Raiz() } }
    }
}

private enum class Aba(val titulo: String) { COFRE("Cofre"), PROTECAO("Proteção"), SOBRE("Sobre") }

@Composable
private fun Raiz() {
    val ctx = LocalContext.current
    val prefs = ctx.getSharedPreferences("sentinela", android.content.Context.MODE_PRIVATE)
    var erro by remember { mutableStateOf(prefs.getString("ultimo_erro", null)) }
    var desbloqueado by remember { mutableStateOf(Sessao.desbloqueado) }

    // Auto-bloqueio: ao ir para o segundo plano, fecha o cofre (reabrir exige senha).
    // Guard: não tranca quando a ida ao fundo foi causada pelo seletor de arquivos do sistema.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val obs = LifecycleEventObserver { _, evento ->
            if (evento == Lifecycle.Event.ON_STOP) {
                if (Sessao.pausarAutoLock) Sessao.pausarAutoLock = false
                else { Sessao.bloquear(); desbloqueado = false }
            }
        }
        lifecycleOwner.lifecycle.addObserver(obs)
        onDispose { lifecycleOwner.lifecycle.removeObserver(obs) }
    }

    when {
        erro != null -> TelaErro(erro!!) {
            prefs.edit().remove("ultimo_erro").apply(); erro = null
        }
        !desbloqueado -> TelaBloqueio { desbloqueado = true }
        else -> TelaPrincipal(aoBloquear = { Sessao.bloquear(); desbloqueado = false })
    }
}

// ---------- Tela de bloqueio (criar / inserir senha) ----------

@Composable
private fun TelaBloqueio(aoEntrar: () -> Unit) {
    val ctx = LocalContext.current
    val criando = remember { !Acesso.senhaDefinida(ctx) }
    var senha by remember { mutableStateOf("") }
    var confirma by remember { mutableStateOf("") }
    var msg by remember { mutableStateOf<String?>(null) }
    var bloqueioMs by remember { mutableStateOf(Acesso.bloqueioRestante(ctx)) }

    LaunchedEffect(Unit) {
        while (true) { bloqueioMs = Acesso.bloqueioRestante(ctx); delay(1000) }
    }

    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Filled.Shield, null, Modifier.size(64.dp), tint = MaterialTheme.colorScheme.primary)
        Spacer(Modifier.height(12.dp))
        Text("Sentinela", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text(if (criando) "Crie uma senha mestra" else "Digite sua senha",
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(24.dp))

        val bloqueado = bloqueioMs > 0
        OutlinedTextField(
            value = senha, onValueChange = { senha = it }, label = { Text("Senha") },
            singleLine = true, enabled = !bloqueado,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            modifier = Modifier.fillMaxWidth(),
        )
        if (criando) {
            Spacer(Modifier.height(8.dp))
            OutlinedTextField(
                value = confirma, onValueChange = { confirma = it }, label = { Text("Confirmar senha") },
                singleLine = true, visualTransformation = PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        msg?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MaterialTheme.colorScheme.error)
        }
        if (bloqueado) {
            Spacer(Modifier.height(8.dp))
            Text("Muitas tentativas. Aguarde ${bloqueioMs / 1000}s.",
                color = MaterialTheme.colorScheme.error)
        }

        Spacer(Modifier.height(20.dp))
        Button(
            onClick = {
                if (criando) {
                    when {
                        senha.length < 4 -> msg = "Use ao menos 4 caracteres."
                        senha != confirma -> msg = "As senhas não conferem."
                        else -> { Acesso.definirSenha(ctx, senha.toCharArray()); aoEntrar() }
                    }
                } else {
                    when (val r = Acesso.desbloquear(ctx, senha.toCharArray())) {
                        is Acesso.Resultado.Ok -> aoEntrar()
                        is Acesso.Resultado.Errou -> { msg = "Senha incorreta. Restam ${r.restantes}."; senha = "" }
                        is Acesso.Resultado.Bloqueado -> { msg = null; senha = "" }
                    }
                }
            },
            enabled = !bloqueado && senha.isNotEmpty(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text(if (criando) "Criar e entrar" else "Desbloquear") }

        if (criando) {
            Spacer(Modifier.height(12.dp))
            Text("A senha protege o cofre por criptografia. Se você esquecê-la, o conteúdo não pode ser recuperado — não há senha-mestra de fábrica.",
                fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

// ---------- Tela principal (abas) ----------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TelaPrincipal(aoBloquear: () -> Unit) {
    var aba by remember { mutableStateOf(Aba.COFRE) }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Sentinela") },
                actions = {
                    IconButton(onClick = aoBloquear) {
                        Icon(Icons.Filled.Lock, contentDescription = "Bloquear")
                    }
                },
            )
        },
        bottomBar = {
            NavigationBar {
                val icones = mapOf(
                    Aba.COFRE to Icons.Filled.Lock,
                    Aba.PROTECAO to Icons.Filled.Shield,
                    Aba.SOBRE to Icons.Filled.Info,
                )
                Aba.entries.forEach { a ->
                    NavigationBarItem(
                        selected = aba == a,
                        onClick = { aba = a },
                        icon = { Icon(icones[a]!!, contentDescription = a.titulo) },
                        label = { Text(a.titulo) },
                    )
                }
            }
        },
    ) { pad ->
        Box(Modifier.padding(pad)) {
            when (aba) {
                Aba.COFRE -> AbaCofre()
                Aba.PROTECAO -> AbaProtecao()
                Aba.SOBRE -> AbaSobre()
            }
        }
    }
}

// ---------- Aba Cofre ----------

@Composable
private fun AbaCofre() {
    val ctx = LocalContext.current
    var itens by remember { mutableStateOf(Cofre.listar(ctx)) }
    var preview by remember { mutableStateOf<androidx.compose.ui.graphics.ImageBitmap?>(null) }
    var aRemover by remember { mutableStateOf<ItemCofre?>(null) }
    var alvoExport by remember { mutableStateOf<ItemCofre?>(null) }
    val snackbar = remember { SnackbarHostState() }
    val escopo = androidx.compose.runtime.rememberCoroutineScope()

    fun atualizar() { itens = Cofre.listar(ctx) }

    val importador = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenMultipleDocuments()
    ) { uris ->
        var guardados = 0
        var apagados = 0
        uris.forEach {
            val r = Cofre.importar(ctx, it)
            if (r.item != null) { guardados++; if (r.originalApagado) apagados++ }
        }
        atualizar()
        val msg = when {
            guardados == 0 -> "Nada importado."
            guardados == apagados -> "$guardados movido(s) para o cofre — originais apagados."
            else -> "$guardados no cofre; ${guardados - apagados} original(is) não pôde(ram) ser apagado(s) — apague na origem."
        }
        escopo.launchSnack(snackbar, msg)
    }

    val exportador = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("*/*")
    ) { uri ->
        val item = alvoExport
        if (uri != null && item != null) {
            val ok = runCatching {
                val bytes = Cofre.conteudo(ctx, item.id) ?: return@runCatching false
                ctx.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }; true
            }.getOrDefault(false)
            escopo.launchSnack(snackbar, if (ok) "Exportado." else "Falha ao exportar.")
        }
        alvoExport = null
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbar) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { Sessao.pausarAutoLock = true; runCatching { importador.launch(arrayOf("*/*")) } },
                icon = { Icon(Icons.Filled.Add, null) },
                text = { Text("Importar") },
            )
        },
    ) { pad ->
        if (itens.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(pad).padding(32.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Icon(Icons.Filled.Lock, null, Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                Text("Cofre vazio", fontWeight = FontWeight.Bold)
                Text("Toque em Importar: o arquivo é cifrado no cofre e o original é apagado da origem. Some da galeria e só abre com sua senha.",
                    fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            LazyColumn(Modifier.fillMaxSize().padding(pad).padding(horizontal = 12.dp)) {
                items(itens, key = { it.id }) { item ->
                    ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                if (item.mime.startsWith("image")) Icons.Filled.Image
                                else if (item.mime.startsWith("video")) Icons.Filled.Movie
                                else Icons.Filled.Description,
                                null, tint = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(item.nome, fontWeight = FontWeight.Medium, maxLines = 1)
                                Text(formatarBytes(item.tamanho), fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            if (item.mime.startsWith("image")) {
                                IconButton(onClick = {
                                    val b = Cofre.conteudo(ctx, item.id)
                                    if (b != null) runCatching {
                                        BitmapFactory.decodeByteArray(b, 0, b.size)?.let {
                                            preview = it.asImageBitmap()
                                        }
                                    }
                                }) { Icon(Icons.Filled.Visibility, "Ver") }
                            }
                            IconButton(onClick = { alvoExport = item; Sessao.pausarAutoLock = true; runCatching { exportador.launch(item.nome) } }) {
                                Icon(Icons.Filled.Download, "Exportar")
                            }
                            IconButton(onClick = { aRemover = item }) {
                                Icon(Icons.Filled.Delete, "Remover", tint = MaterialTheme.colorScheme.error)
                            }
                        }
                    }
                }
            }
        }
    }

    preview?.let { img ->
        AlertDialog(
            onDismissRequest = { preview = null },
            confirmButton = { TextButton(onClick = { preview = null }) { Text("Fechar") } },
            text = { Image(img, contentDescription = null, Modifier.fillMaxWidth()) },
        )
    }

    aRemover?.let { item ->
        AlertDialog(
            onDismissRequest = { aRemover = null },
            title = { Text("Remover do cofre?") },
            text = { Text("\"${item.nome}\" será apagado do cofre. Exporte antes se quiser manter.") },
            confirmButton = {
                TextButton(onClick = {
                    Cofre.remover(ctx, item.id); itens = Cofre.listar(ctx); aRemover = null
                }) { Text("Remover") }
            },
            dismissButton = { TextButton(onClick = { aRemover = null }) { Text("Cancelar") } },
        )
    }
}

// ---------- Aba Proteção ----------

@Composable
private fun AbaProtecao() {
    val ctx = LocalContext.current
    var riscos by remember { mutableStateOf(emptyList<Risco>()) }
    var carregou by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        riscos = runCatching { diagnostico(ctx) }.getOrDefault(emptyList()); carregou = true
    }

    val score = calcularScore(riscos)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        ElevatedCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Score de privacidade", color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text("$score", fontSize = 56.sp, fontWeight = FontWeight.Bold, color = corScore(score))
                Text(when {
                    !carregou -> "Analisando..."
                    score >= 85 -> "Bem protegido"
                    score >= 60 -> "Alguns pontos a corrigir"
                    else -> "Atenção: riscos importantes"
                }, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(12.dp))

        riscos.forEach { r ->
            ElevatedCard(Modifier.fillMaxWidth().padding(vertical = 5.dp)) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        when (r.nivel) {
                            Nivel.OK -> Icons.Filled.CheckCircle
                            Nivel.ATENCAO -> Icons.Filled.Warning
                            Nivel.CRITICO -> Icons.Filled.Error
                        },
                        null, tint = corNivel(r.nivel),
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(Modifier.weight(1f)) {
                        Text(r.titulo, fontWeight = FontWeight.Medium)
                        Text(r.detalhe, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (r.abrir != null && r.rotuloAcao != null) {
                        Spacer(Modifier.width(8.dp))
                        TextButton(onClick = { r.abrir.invoke(ctx) }) { Text(r.rotuloAcao) }
                    }
                }
            }
        }

        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = { abrirPlayProtect(ctx) }, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.VerifiedUser, null); Spacer(Modifier.width(8.dp)); Text("Abrir o Play Protect")
        }
        Spacer(Modifier.height(8.dp))
        Text("A análise é 100% local. Nada sai do aparelho.",
            fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ---------- Aba Sobre ----------

@Composable
private fun AbaSobre() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text("Sentinela", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        Text("Versão $VERSAO_APP", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(16.dp))
        TextoSobre("Privacidade real",
            "Sem internet, sem câmera, sem rastreio. O app não envia nada para lugar nenhum — não há para onde enviar.")
        TextoSobre("Cofre criptografado",
            "Importar MOVE o arquivo: ele é cifrado com AES-256 a partir da sua senha (PBKDF2) e o original é apagado da origem. Some da galeria, fica em área privada do app. Sem a senha, ninguém abre — nem você, nem nós, nem um app malicioso.")
        TextoSobre("Tranca sozinho",
            "Ao sair do app ou apagar a tela, o cofre fecha automaticamente. Reabrir exige a senha de novo — deixar aberto não expõe o conteúdo.")
        TextoSobre("Sem porta dos fundos",
            "Não existe senha-mestra de recuperação. Se esquecer a senha, o conteúdo cifrado é perdido. É o preço de uma proteção honesta.")
        TextoSobre("Detector de espião",
            "A aba Proteção mostra apps com Acessibilidade, acesso a notificações e administração do dispositivo — os caminhos reais de stalkerware. Você revisa e revoga.")
        TextoSobre("O que ele NÃO faz",
            "Não é antivírus (o Android isola apps por sandbox) e não apaga outros apps sozinho (impossível para um app comum). Foca no que realmente protege.")
        Spacer(Modifier.height(16.dp))
        Text("Criado por Luan Guilherme Lourenço", fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun TextoSobre(titulo: String, corpo: String) {
    Column(Modifier.padding(bottom = 14.dp)) {
        Text(titulo, fontWeight = FontWeight.Bold)
        Text(corpo, fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ---------- Tela de erro (crash anterior) ----------

@Composable
private fun TelaErro(texto: String, aoFechar: () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {
        Text("Ocorreu um erro", fontSize = 20.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.error)
        Text("Tire um print desta tela para diagnóstico e toque em Continuar.",
            fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(12.dp))
        Surface(
            color = MaterialTheme.colorScheme.surfaceVariant,
            shape = RoundedCornerShape(8.dp),
        ) {
            Text(texto, Modifier.padding(12.dp), fontSize = 11.sp)
        }
        Spacer(Modifier.height(16.dp))
        Button(onClick = aoFechar, Modifier.fillMaxWidth()) { Text("Continuar") }
    }
}

// ---------- Auxiliares de UI ----------

private fun formatarBytes(b: Long): String {
    if (b <= 0) return "0 B"
    val u = arrayOf("B", "KB", "MB", "GB")
    val i = (Math.log10(b.toDouble()) / 3).toInt().coerceIn(0, 3)
    return String.format(java.util.Locale.getDefault(), "%.1f %s", b / Math.pow(1000.0, i.toDouble()), u[i])
}

@Composable private fun corNivel(n: Nivel): Color = when (n) {
    Nivel.OK -> MaterialTheme.colorScheme.primary
    Nivel.ATENCAO -> Color(0xFFFFB300)
    Nivel.CRITICO -> MaterialTheme.colorScheme.error
}

@Composable private fun corScore(s: Int): Color = when {
    s >= 85 -> MaterialTheme.colorScheme.primary
    s >= 60 -> Color(0xFFFFB300)
    else -> MaterialTheme.colorScheme.error
}

private fun kotlinx.coroutines.CoroutineScope.launchSnack(host: SnackbarHostState, msg: String) {
    launch { host.showSnackbar(msg) }
}
