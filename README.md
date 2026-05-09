# SafeQuest 🛡️
**Plataforma Gamificada de Treino em Cibersegurança**

Uma aplicação móvel que utiliza mecânicas de gamificação, feedback alimentado por Inteligência Artificial (IA) e funcionalidades sociais para ensinar cibersegurança de forma envolvente e interativa.

---

## 📖 Visão Geral
O SafeQuest é uma aplicação móvel construída em Flutter desenhada para ensinar conceitos de cibersegurança através de questionários (quizzes), missões diárias, batalhas de clãs e feedback personalizado impulsionado por IA. A plataforma destina-se a utilizadores sem experiência técnica prévia, guiando-os progressivamente por tópicos como Phishing, Gestão de Palavras-passe, Segurança nas Redes Sociais e Segurança Web.

A aplicação assenta numa arquitetura serverless (sem servidor) utilizando o Firebase como backend, eliminando a necessidade de infraestrutura dedicada e mantendo a sincronização em tempo real entre todos os utilizadores.

---

## ❗ Declaração do Problema
O treino tradicional de consciencialização em cibersegurança é passivo, denso em texto e difícil de reter. Os utilizadores têm pouca motivação para interagir com conteúdo estático e as organizações têm dificuldade em acompanhar o progresso individual ou identificar lacunas de conhecimento.

O SafeQuest resolve isto transformando a aprendizagem num jogo — recompensando respostas corretas, sequências de vitórias (streaks) e missões concluídas com moedas, crachás (badges) e posições na tabela de classificação, tornando a educação em segurança acessível e num hábito.

---

## 💡 Solução e Abordagem
O sistema combina um motor de quizzes com três níveis de dificuldade e três tipos de quiz (Normal, Time Attack, Verdadeiro/Falso), uma camada de gamificação (XP, níveis, moedas, sequências, combos) e um assistente de IA alimentado pelo Gemini 2.0 Flash que analisa o desempenho do utilizador e recomenda quizzes específicos com base nos seus pontos fracos.

As funcionalidades sociais — clãs, chat de clã, batalhas de quizzes e uma tabela de classificação de amigos — adicionam uma dimensão competitiva que incentiva o envolvimento diário.

---

## ✨ Funcionalidades
*   **Classificação Avançada:** Classifica os quizzes por tema, dificuldade e tipo.
*   **Sistema de Multiplicador de Combo:** ×1.2 / ×1.5 / ×2.0 para respostas corretas consecutivas.
*   **Missões Diárias:** Com recompensas em moedas, renovadas à meia-noite.
*   **Acompanhamento de Sequências (Streaks):** Com celebração animada no primeiro quiz diário.
*   **Mentor IA (Gemini 2.0 Flash):** Para análise de desempenho personalizada e recomendação de quizzes.
*   **Assistente IA:** Para perguntas de cibersegurança em formato livre.
*   **Sistema de Clãs:** Com chat em tempo real, batalhas de quizzes e hierarquia de papéis (Líder, Co-Líder, Ancião, Membro).
*   **Tabelas de Classificação:** Leaderboard de amigos em paralelo com classificações globais de jogadores e clãs.
*   **Loja Virtual:** Avatares e banners com itens cosméticos desbloqueáveis de acordo com o nível.
*   **Crachás (Badges):** 30 itens desbloqueáveis com base no desempenho nos quizzes e marcos alcançados.
*   **Notificações Push:** Via Firebase Cloud Messaging (FCM), respeitando as preferências do utilizador.
*   **E-mails Automatizados:** Lembretes de missões diárias e resumos semanais com a mascote animada do dragão em SVG.
*   **Sessão Persistente:** Os utilizadores mantêm a sessão iniciada mesmo após o fecho ou reinício da aplicação.
*   **Suporte Offline:** O conteúdo dos quizzes está disponível sem internet; as funcionalidades de IA apresentam um aviso de conectividade.

---

## 🛠️ Pilha Tecnológica (Tech Stack)

| Categoria | Tecnologia |
| :--- | :--- |
| **Linguagem** | Dart |
| **Framework** | Flutter 3.x |
| **Autenticação** | Firebase Auth (e-mail/palavra-passe + Google Sign-In) |
| **Base de Dados** | Cloud Firestore (NoSQL, em tempo real) |
| **Notificações Push** | Firebase Cloud Messaging (FCM) |
| **Automação de E-mail** | Extensão Firebase — Trigger Email + Cloud Functions (Node.js) |
| **IA / ML** | Google Gemini 2.5 Flash API |
| **Gestão de Estado** | Provider |
| **Armazenamento Local** | SharedPreferences |
| **Média** | ImagePicker (galeria de avatares) |
| **Áudio** | AudioPlayers (efeitos sonoros dos quizzes) |
| **Ambiente** | flutter_dotenv (ficheiro `.env` para chaves API) |
| **Ferramentas** | Firebase CLI, Git, VS Code |
| **Plataforma Alvo** | Android 8.0+ (API 26+) |

---

## 🏗️ Arquitetura
A aplicação segue uma arquitetura serverless com quatro componentes principais:
1.  **Aplicação Móvel Flutter:** Interface de utilizador (UI), gestão de estado, motor de quizzes, animações e todas as interações do utilizador.
2.  **Backend Firebase:** Firestore para persistência de dados, Firebase Auth para identidade, FCM para notificações push.
3.  **API Gemini:** Assistente de IA (via SDK) e análise de desempenho (via HTTP REST).
4.  **Cloud Functions (Node.js):** Notificações agendadas (18h) e relatórios semanais por e-mail; todas respeitando as preferências de notificação individuais guardadas no Firestore.

---

## 🗄️ Estrutura de Dados do Firestore
*   `users/{uid}` → perfil, pontos, moedas, sequência (streak), avatar, banner, clanId, definições de privacidade
*   `users/{uid}/quiz_results` → resultados por quiz com tema, percentagem, combo, perguntas
*   `users/{uid}/notifications` → notificações in-app (título, corpo, tipo, lida)
*   `users/{uid}/daily_missions/{date}` → progresso da missão diária e recompensas resgatadas
*   `clans/{id}` → informações do clã, memberIds, papéis, pontos
*   `clans/{id}/messages` → mensagens de chat em tempo real e cartões de batalha
*   `clan_battles/{id}` → registos de batalhas abertas / em curso / concluídas
*   `mail` → fila de e-mail (processada pela extensão Trigger Email)

---

## ⚠️ Limitações
*   A aplicação não foi testada num ambiente de produção em grande escala; o desequilíbrio de classes entre utilizadores ativos e inativos pode afetar a relevância das notificações.
*   A análise por IA requer uma ligação ativa à internet e uma chave de API do Gemini válida configurada no ficheiro `.env`.
*   As notificações push requerem os Google Play Services; alguns dispositivos Huawei podem experienciar funcionalidades limitadas.
*   O suporte para iOS requer a compilação em macOS com o Xcode; uma versão compilada para Web (Flutter Web) pode ser utilizada como alternativa para testes em dispositivos da Apple.

---

## 🚀 Melhorias Futuras
*   **Página de revisão de erros:** Permitir rever as questões respondidas incorretamente.
*   **Cache de quizzes offline:** Armazenar as perguntas mais recentes localmente via `SharedPreferences` para permitir jogar sem internet.
*   **Versões iOS / Web:** Expandir o suporte da plataforma para além do Android.
*   **Missões semanais de clã:** Objetivos coletivos partilhados com recompensas de grupo.
*   **Certificado em PDF:** Gerado automaticamente ao concluir todos os temas com 100% de sucesso.
*   **Modo escuro:** Alternância de tema automática consoante as definições do sistema.

---

## 🔒 Considerações de Segurança
*   A autenticação de utilizadores é totalmente gerida pelo Firebase Auth, suportando um sistema seguro de e-mail/palavra-passe e OAuth 2.0 através do Google Sign-In.
*   As chaves API (Gemini) são armazenadas num ficheiro `.env` excluído do controlo de versões através do `.gitignore`.
*   As definições de privacidade do utilizador (público / apenas amigos / privado) são aplicadas ao nível da aplicação ao renderizar os perfis.
*   As preferências de notificação (`pushNotifs`, `emailNotifs`) são armazenadas no Firestore e verificadas pelas Cloud Functions antes do envio de qualquer comunicação.
*   Os requisitos de palavra-passe exigem um mínimo de 8 caracteres, pelo menos uma letra maiúscula e pelo menos um número.
