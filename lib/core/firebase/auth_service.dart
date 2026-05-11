import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Wraps Firebase Auth + the three login providers we support.
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? google})
      : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null; // user cancelled
    final googleAuth = await account.authentication;
    final cred = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(cred);
    return result.user;
  }

  Future<User?> signInWithApple() async {
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauth = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      accessToken: apple.authorizationCode,
    );
    final result = await _auth.signInWithCredential(oauth);
    return result.user;
  }

  /// Email magic-link (passwordless). Caller is responsible for handling the
  /// deep link returned by Firebase Auth on the device.
  Future<void> sendMagicLink({
    required String email,
    required String dynamicLinkUrl,
  }) async {
    final actionCode = ActionCodeSettings(
      url: dynamicLinkUrl,
      handleCodeInApp: true,
      androidPackageName: 'com.gaayana',
      androidInstallApp: true,
      androidMinimumVersion: '21',
      iOSBundleId: 'com.gaayana',
    );
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCode,
    );
  }

  Future<User?> completeMagicLink(String email, String emailLink) async {
    if (!_auth.isSignInWithEmailLink(emailLink)) return null;
    final result = await _auth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    return result.user;
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
