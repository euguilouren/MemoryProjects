# Sentinela — Privacidade e Proteção (Android)

App Android pessoal, focado em **privacidade e proteção**, instalado por sideload (APK do GitHub). Sucessor focado do projeto Faxina (que misturava limpeza + segurança e ficou frágil).

## O que faz

- **Cofre criptografado:** importa fotos/arquivos para uma área privada do app, cifrados com **AES-256/GCM** a partir da sua senha (PBKDF2). Somem da galeria; sem a senha, ninguém abre.
- **Senha mestra + bloqueio:** errou 3 vezes → tranca e esconde por alguns minutos (sem câmera). Não há senha-mestra de recuperação — proteção honesta.
- **Detector de espião:** mostra apps com **Acessibilidade**, **acesso a notificações** e **administração do dispositivo** ativos — os vetores reais de stalkerware. Você revisa e revoga.
- **Postura do aparelho + Score:** bloqueio de tela, depuração USB, patch de segurança; nota de privacidade com pendências que abrem direto a tela certa do sistema.

## O que NÃO faz (honestidade técnica)

- **Não é antivírus** — o Android isola apps por sandbox; não há motor de assinaturas confiável para terceiros.
- **Não apaga outros apps sozinho** — impossível para um app comum (precisaria de root ou Device Owner).
- **Não tranca outros apps** (cadeado) na v1 — fica para a v2 (exige Acessibilidade/overlay).

## Privacidade por construção

- **Sem permissão de INTERNET** — o app não envia nada para lugar nenhum.
- **Sem câmera, sem acesso amplo à mídia** — o cofre usa o seletor do sistema (SAF).
- **Única permissão:** `QUERY_ALL_PACKAGES`, só para exibir nomes legíveis no detector de espião.

## Stack

Kotlin 1.9.24 + Jetpack Compose (Material 3). minSdk 30, targetSdk 34, AGP 8.5, Gradle 8.7, JDK 17. Sem backend. Release **não-depurável**; R8 desligado até validação no aparelho.

**Versão atual:** 1.1 (`versionCode 2`). O cadeado de apps (Acessibilidade/overlay) segue como evolução futura.

## Build

- **Local:** `cd sentinela && ./gradlew assembleRelease` (Gradle wrapper fixado em 8.7 — não precisa instalar Gradle).
- **CI:** GitHub Actions (`.github/workflows/android-sentinela.yml`) compila via wrapper e publica o APK como artefato; tag `v*` anexa ao Release.

Criado por Luan Guilherme Lourenço. Uso sujeito à [LICENSE](../LICENSE) (proprietária — todos os direitos reservados).
