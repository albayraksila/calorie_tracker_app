// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// EMAIL KAYIT
  /// - Kullanıcı oluşturur
  /// - Doğrulama maili gönderir
  /// - Varsayılan: signOut YAPMAZ (VerifyEmailScreen currentUser ister)
  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    bool signOutAfterSend = false, // ✅ DEĞİŞEN TEK SATIR
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
      if (signOutAfterSend) {
        await _auth.signOut();
      }
    }

    return user;
  }

  /// EMAIL GİRİŞ
  /// - Giriş yaptırır
  /// - emailVerified değilse:
  ///    * isterse tekrar doğrulama maili yollar
  ///    * isteğe bağlı signOut yapar
  ///    * FirebaseAuthException('email-not-verified') fırlatır
  Future<User?> signInWithEmail({
    required String email,
    required String password,
    bool signOutIfNotVerified = false,
    bool resendVerificationIfNeeded = false,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) return null;

    // En güncel durum
    await user.reload();
    final freshUser = _auth.currentUser;

    if (freshUser != null && !freshUser.emailVerified) {
      if (resendVerificationIfNeeded) {
        await freshUser.sendEmailVerification();
      }
      if (signOutIfNotVerified) {
        await _auth.signOut();
      }

      // UI tarafında yakalayacağın özel hata kodu:
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'E-posta doğrulanmamış. Lütfen e-postanı doğrula.',
      );
    }

    return freshUser;
  }

  /// GOOGLE GİRİŞ (genelde verified olur)
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // kullanıcı iptal etti

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  /// Doğrulama mailini yeniden gönder
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'Aktif kullanıcı yok.',
      );
    }
    await user.sendEmailVerification();
  }

  /// Mevcut kullanıcının emailVerified durumunu güncelle ve döndür
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  //Şifremi Unuttum
  Future<void> sendPasswordResetEmail(String email) async {
  await _auth.sendPasswordResetEmail(email: email.trim());
}
//Kullanıcı varsa Şifremi Unuttum
Future<bool> isEmailRegistered(String email) async {
  final methods = await _auth.fetchSignInMethodsForEmail(email.trim());
  return methods.isNotEmpty;
}
Future<void> sendPasswordResetSmart(String email) async {
  final methods = await _auth.fetchSignInMethodsForEmail(email.trim());

  // 1) Kayıt yok
  if (methods.isEmpty) {
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.',
    );
  }

  // 2) Email/Password hesabı ise → reset gönder
  if (methods.contains('password')) {
    await _auth.sendPasswordResetEmail(email: email.trim());
    return;
  }

  // 3) Kayıt var ama şifreli giriş yok (Google/Apple vb.)
  throw FirebaseAuthException(
    code: 'no-password-provider',
    message: 'Bu hesap şifre ile giriş kullanmıyor.',
  );
}


}
