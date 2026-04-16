import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final adminRoleProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    return false;
  }
  return ref.watch(authRepositoryProvider).isAdmin(user.uid);
});

class LoginFormState {
  const LoginFormState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  LoginFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LoginFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LoginFormController extends StateNotifier<LoginFormState> {
  LoginFormController(this._ref) : super(const LoginFormState());

  final Ref _ref;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password.trim());
      final isAdmin = await _ref.read(adminRoleProvider.future);
      if (!isAdmin) {
        await _ref.read(authRepositoryProvider).logout();
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'auth.invalidRole',
        );
        return false;
      }
      state = state.copyWith(isLoading: false, clearError: true);
      return true;
    } on FirebaseAuthException {
      state = state.copyWith(isLoading: false, errorMessage: 'auth.loginFailed');
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'auth.loginFailed');
      return false;
    }
  }
}

final loginFormControllerProvider =
    StateNotifierProvider<LoginFormController, LoginFormState>((ref) {
      return LoginFormController(ref);
    });
