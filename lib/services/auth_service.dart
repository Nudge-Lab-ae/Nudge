import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nudge/services/api_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
// import 'package:facebook_auth/facebook_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

   Stream<User?> get user {
    return _auth.authStateChanges();
  }

  // Get current user
 User? get currentUser {
    return _auth.currentUser;
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseException catch (e) {
      print(e); print(' is the error');
      return null;
    }
  }

  // Register with email and password
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }


  // Sign in with Google

  // Future<User?> signInWithGoogle() async {
  //    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
  //    await googleSignIn.initialize(
  //   serverClientId: '764964903709-3ohmbtvnmona7jl8kd6hv2omingargv8.apps.googleusercontent.com',
  // );
  //    GoogleSignInAccount signInAccount =
  //       await googleSignIn.authenticate();
  //   GoogleSignInAuthentication signInAuthentication = signInAccount.authentication;

  //   final  credential = GoogleAuthProvider.credential(
  //     accessToken: signInAuthentication.idToken,
  //     idToken: signInAuthentication.idToken,
  //   );

  //   UserCredential cred = await _auth.signInWithCredential(credential);
  //   dynamic user = cred.user;
  //   // User? theUser = user as User?;
  //   return user;
  // }

   Future<User?> signInWithGoogle() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final GoogleSignIn googleSignIn = GoogleSignIn.instance;
    print('stagea');
    if (Platform.isAndroid || Platform.isIOS) {
      await googleSignIn.initialize(
        serverClientId: '40187814474-5n0oil6qublvnso4km97sl0q6sh5im24.apps.googleusercontent.com',
      );
    }
    print('stageb');

   try {
    // Initiate the Google Sign-In process. A pop-up will appear for the user.
    final GoogleSignInAccount googleUser = await googleSignIn.authenticate();

    print('stage1');

    // If the user cancelled the sign-in flow, googleUser will be null.
    
     final GoogleSignInAuthentication auth =  googleUser.authentication;

     print('stage2');

    // Create Firebase credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );

    print('stage3');

    // Sign in to Firebase
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;

  } catch (error) {
    // Handle any exceptions that occur during the sign-in process.
    print('error signing in with google');
    return null;
  }
}

  // Sign in with Apple
  Future<User?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      UserCredential result = await _auth.signInWithCredential(oauthCredential);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> storeFCMToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final apiService = ApiService();
        String? token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await apiService.updateUser({'fcmToken': token});
          print('FCM token stored for user: ${user.uid}');
        }
      }
    } catch (e) {
      print('Error storing FCM token: $e');
    }
  }

  Future<User?> modifiedAppleSignIn() async {
    print('stage0');
    UserCredential? credential;
    print('stage1');
    try {
      // credential = await SignInWithApple.getAppleIDCredential(
      //   scopes: [
      //     AppleIDAuthorizationScopes.email,
      //     // AppleIDAuthorizationScopes.fullName,
      //   ],
      //   webAuthenticationOptions: WebAuthenticationOptions(
      //     clientId: 'com.services.nudge', // e.g., com.example.app.service
      //     redirectUri: Uri.parse('https://nudge-965c2.firebaseapp.com/__/auth/handler'),
      //   ),
      // );
      final appleProvider = AppleAuthProvider()
        .addScope('email')
        .addScope('name');

    credential = await FirebaseAuth.instance.signInWithProvider(appleProvider);
      print('stage2');
    } catch (e) {
      print(e); print('is the error');
      return null;
    }

    print('stage3');

    OAuthProvider oAuthProvider = OAuthProvider('apple.com');
    final AuthCredential authCredential = oAuthProvider.credential(
        accessToken: credential.credential!.accessToken,
        idToken: credential.credential!.token.toString());
    print('stage4');
    User? user = null;
    try {
      user = (await _auth.signInWithCredential(authCredential)).user!;
    } catch (e) {
      print('Errorrrr'); print(e.toString());
      return null;
    }
    print('stage5');
    return user;
  }

  // Sign in with Facebook
  // Future<User?> signInWithFacebook() async {
  //   try {
  //     // Login to Facebook
  //     final loginResult = await FacebookAuth.instance.login();
      
  //     // Check if login was successful and we have an access token
  //     if (loginResult.status == LoginStatus.success && loginResult.accessToken != null) {
  //       // Create a credential from the access token
  //       final firebase_auth.OAuthCredential facebookAuthCredential = 
  //           firebase_auth.FacebookAuthProvider.credential(loginResult.accessToken!.token);
        
  //       // Sign in to Firebase with the Facebook credential
  //       firebase_auth.UserCredential result = 
  //           await _auth.signInWithCredential(facebookAuthCredential);
  //       return result.user;
  //     } else {
  //       // Handle login failure
  //       print('Facebook login failed: ${loginResult.status}');
  //       print('Facebook login message: ${loginResult.message}');
  //       return null;
  //     }
  //   } catch (e) {
  //     print('Facebook login error: ${e.toString()}');
  //     return null;
  //   }
  // }

  // Sign out
  Future<void> signOut() async {
    try {
      return await _auth.signOut();
    } catch (e) {
      print(e.toString());
      return null;
    }
  }
}