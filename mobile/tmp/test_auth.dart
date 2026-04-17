import 'package:google_sign_in/google_sign_in.dart';

class MyAuth {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  Future<void> test() async {
    final user = await _googleSignIn.signIn();
    if (user != null) {
      final auth = await user.authentication;
      print(auth.accessToken);
    }
  }
}

void main() {}
