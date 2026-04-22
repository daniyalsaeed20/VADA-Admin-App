import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/contacts_repository.dart';
import '../domain/contact.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(firestoreProvider));
});

final contactsStreamProvider = StreamProvider<List<Contact>>((ref) {
  return ref.watch(contactsRepositoryProvider).watchContacts();
});

class ContactMutationState {
  const ContactMutationState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  ContactMutationState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ContactMutationState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ContactMutationController extends StateNotifier<ContactMutationState> {
  ContactMutationController(this._ref) : super(const ContactMutationState());

  final Ref _ref;

  Future<void> create({
    required String name,
    required String phone,
    required String email,
    required String address,
    required String role,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(contactsRepositoryProvider).createContact(
            name: name,
            phone: phone,
            email: email,
            address: address,
            role: role,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'contacts.createSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'contacts.unknownError',
      );
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required String phone,
    required String email,
    required String address,
    required String role,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _ref.read(contactsRepositoryProvider).updateContact(
            id: id,
            name: name,
            phone: phone,
            email: email,
            address: address,
            role: role,
          );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'contacts.updateSuccess',
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'contacts.unknownError',
      );
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final contactMutationControllerProvider =
    StateNotifierProvider<ContactMutationController, ContactMutationState>((
  ref,
) {
  return ContactMutationController(ref);
});
