# Bolão Bolado

Organize e participe de bolões com seus amigos de forma simples e divertida.

Aplicação Flutter multiplataforma (web, Android, iOS, desktop) para criação e
gerenciamento de bolões: cadastro de salas, controle de participantes, registro
de apostas, chat e painel administrativo — com backend em Firebase.

## 📱 Funcionalidades

- Autenticação de usuários (cadastro, login, recuperação de senha)
- Criação e configuração de salas de bolão
- Inscrição e gerenciamento de participantes
- Registro e simulação de apostas
- Estatísticas de participantes
- Chat em tempo real por sala
- Painel administrativo
- Layout responsivo (mobile e desktop)

## 🛠️ Tecnologias

- [Flutter](https://flutter.dev) / Dart
- [Firebase](https://firebase.google.com) — Authentication, Cloud Firestore, Hosting
- [go_router](https://pub.dev/packages/go_router) — navegação declarativa
- [Cloud Functions](https://firebase.google.com/docs/functions) (`/functions`)

## ✅ Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal stable)
- [Firebase CLI](https://firebase.google.com/docs/cli) (`npm install -g firebase-tools`)
- Uma conta e projeto configurados no [Firebase Console](https://console.firebase.google.com)

## 📦 Instalação

```bash
# Clone o repositório
git clone <url-do-repositorio>
cd bolao-bolado

# Instale as dependências
flutter pub get
```

Configure o Firebase para o projeto (gera `lib/firebase_options.dart` e os
arquivos nativos necessários):

```bash
flutterfire configure
```

## 🚀 Executando o projeto

```bash
# Web
flutter run -d chrome

# Android/iOS (com emulador ou dispositivo conectado)
flutter run

# Desktop (Windows/macOS/Linux)
flutter run -d windows
```

## 🗂️ Estrutura do projeto

```
lib/
├── components/     # Widgets e componentes de UI reutilizáveis
├── core/            # Utilitários centrais (ex.: responsividade)
├── dev/             # Ferramentas e simulações para desenvolvimento
├── models/          # Modelos de dados
├── pages/           # Telas do aplicativo
├── router/          # Configuração de rotas (go_router)
├── services/        # Integração com Firebase e regras de negócio
├── widgets/          # Widgets compostos específicos de telas
├── bolao_bolado.dart # Widget raiz do app
└── main.dart         # Ponto de entrada
```

## 🔥 Firebase

Regras do Firestore e índices ficam em `firestore.rules` e
`firestore.indexes.json` na raiz do projeto. Para publicar alterações:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Para build e deploy do hosting web:

```bash
flutter build web
firebase deploy --only hosting
```

## 🧪 Testes

```bash
flutter test
```

## 📄 Licença

Projeto privado — todos os direitos reservados.
