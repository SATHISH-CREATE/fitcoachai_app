import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  print("Starting test...");
  try {
    final g = GoogleSignIn();
    print("Created GoogleSignIn instance with standard constructor.");
    print("Scopes: ${g.scopes}");
  } catch (e) {
    print("Error creating instance: $e");
  }
}
