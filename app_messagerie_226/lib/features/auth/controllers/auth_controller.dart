import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final currentUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final userProfileProvider = StreamProvider.family<Map<String, dynamic>?, String>(
  (ref, uid) {
    return ref
        .watch(firestoreProvider)
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.data());
  },
);

enum AuthStep { idle, loading, error }

class AuthState {
  final AuthStep step;
  final String? errorMessage;
  const AuthState({this.step = AuthStep.idle, this.errorMessage});
  AuthState copyWith({AuthStep? step, String? errorMessage}) =>
      AuthState(step: step ?? this.step, errorMessage: errorMessage ?? this.errorMessage);
}

class AuthController extends StateNotifier<AuthState> {
  final FirebaseAuth _auth;

  AuthController(this._auth) : super(const AuthState());

  Future<void> signInWithGoogle() async {
    state = state.copyWith(step: AuthStep.loading);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        state = state.copyWith(step: AuthStep.idle);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      state = state.copyWith(step: AuthStep.idle);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(step: AuthStep.error, errorMessage: e.message ?? 'Erreur connexion');
    } catch (e) {
      state = state.copyWith(step: AuthStep.error, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    state = const AuthState();
  }

  void reset() => state = const AuthState();
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(firebaseAuthProvider));
});
