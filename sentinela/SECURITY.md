# Modelo de segurança — Sentinela

## Princípios

1. **Menor privilégio:** uma única permissão (`QUERY_ALL_PACKAGES`). Sem internet, câmera ou acesso amplo à mídia.
2. **Sem exfiltração:** sem `INTERNET` no manifest — o app é incapaz de enviar dados para fora, por construção.
3. **Não-depurável:** release com `isDebuggable = false` (impede `adb run-as` ler os dados do app em aparelho não-rooteado).
4. **Sem backup:** `allowBackup=false` e `hasFragileUserData=false` — o cofre não vaza por backup do sistema.

## Criptografia do cofre

- Chave derivada da senha por **PBKDF2-HMAC-SHA256**, 120.000 iterações, salt aleatório de 16 bytes.
- Conteúdo cifrado com **AES-256/GCM** (autenticado), IV aleatório de 12 bytes por arquivo.
- A chave existe **apenas em memória** após o desbloqueio; nunca é persistida.
- Verificação de senha por **verificador cifrado** (não há hash de senha separado nem senha-mestra de fábrica).
- Arquivos guardados em `filesDir/cofre` (armazenamento privado do app), invisíveis a outros apps.

## Resposta a tentativa de intrusão

- 3 senhas erradas → bloqueio temporizado (esconde o conteúdo). Sem foto/câmera por opção de design.
- Não há desinstalação automática: um app comum não pode apagar a si mesmo nem outro app sem confirmação do sistema.

## Limites assumidos (honestos)

- Em aparelho **rooteado**, a área privada do app pode ser lida — nenhuma proteção de app sobrevive a root.
- O app não detecta malware por assinatura; foca em **permissões perigosas concedidas** (o vetor real).
- R8/ofuscação desligado nesta versão; ativar só após validação de runtime no aparelho.
