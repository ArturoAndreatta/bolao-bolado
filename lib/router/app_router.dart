import 'package:bolao_bolado/models/sala.dart';
import 'package:bolao_bolado/pages/admin/painel_admin.dart';
import 'package:bolao_bolado/pages/auth/forgot_password.dart';
import 'package:bolao_bolado/pages/auth/register.dart';
import 'package:bolao_bolado/pages/auth/signup.dart';
import 'package:bolao_bolado/pages/cadastrar_sala/cadastrar_sala_router.dart';
import 'package:bolao_bolado/pages/consultar_salas.dart';
import 'package:bolao_bolado/pages/home_page.dart';
import 'package:bolao_bolado/pages/informar_aposta.dart';
import 'package:bolao_bolado/pages/participants.dart';
import 'package:bolao_bolado/pages/sala_detalhes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class AppRoutes {
  static const home = '/home';
  static const signup = '/signup';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const participants = '/participantes';
  static const informarAposta = '/minha-aposta';
  static const cadastrarSala = '/cadastrar-sala';
  static const consultarSalas = '/consultar-salas';
  static const salaDetalhes = '/sala-detalhes';
  static const painelAdmin = '/painel-admin';
}

// Rotas públicas: acessíveis a qualquer um, logado ou não.
const _publicRoutes = [
  AppRoutes.home,
  AppRoutes.signup,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.participants,
];

// Rotas que não fazem sentido para quem já está logado de verdade.
const _guestOnlyRoutes = [AppRoutes.home, AppRoutes.signup, AppRoutes.register];

// Página sem transição, replicando o PageRouteBuilder com
// transitionDuration: Duration.zero usado em todo o app antes da migração.
CustomTransitionPage<void> _noTransitionPage(
  Widget child,
  GoRouterState state,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, _, _, child) => child,
  );
}

final routeObserver = RouteObserver<PageRoute>();

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  observers: [routeObserver],
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final path = state.matchedLocation;

    if (!isLoggedIn && !_publicRoutes.contains(path)) {
      return AppRoutes.home;
    }
    if (isLoggedIn && _guestOnlyRoutes.contains(path)) {
      return AppRoutes.participants;
    }
    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.home,
      pageBuilder: (context, state) =>
          _noTransitionPage(const HomePage(), state),
    ),
    GoRoute(
      path: AppRoutes.signup,
      pageBuilder: (context, state) => _noTransitionPage(const Signup(), state),
    ),
    GoRoute(
      path: AppRoutes.register,
      pageBuilder: (context, state) => _noTransitionPage(
        Register(email: state.uri.queryParameters['email']),
        state,
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      pageBuilder: (context, state) => _noTransitionPage(
        RecuperarSenha(email: state.uri.queryParameters['email']),
        state,
      ),
    ),
    GoRoute(
      path: AppRoutes.participants,
      pageBuilder: (context, state) =>
          _noTransitionPage(const Participants(), state),
    ),
    GoRoute(
      path: AppRoutes.informarAposta,
      pageBuilder: (context, state) => _noTransitionPage(const Login(), state),
    ),
    GoRoute(
      path: AppRoutes.cadastrarSala,
      pageBuilder: (context, state) => _noTransitionPage(
        CadastrarSala(salaId: state.uri.queryParameters['salaId']),
        state,
      ),
    ),
    GoRoute(
      path: AppRoutes.consultarSalas,
      pageBuilder: (context, state) =>
          _noTransitionPage(const ConsultarSalas(), state),
    ),
    GoRoute(
      path: AppRoutes.salaDetalhes,
      pageBuilder: (context, state) =>
          _noTransitionPage(SalaDetalhes(sala: state.extra as Sala), state),
    ),
    GoRoute(
      path: AppRoutes.painelAdmin,
      pageBuilder: (context, state) =>
          _noTransitionPage(const PainelAdmin(), state),
    ),
  ],
);
