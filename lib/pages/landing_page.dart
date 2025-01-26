import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:eco_walk/main.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  var _loading = false;

  void _signInWithGoogleButton() async {
    setState(() => _loading = true);
    try {
      if (FirebaseAuth.instance.currentUser != null) await FirebaseAuth.instance.signOut();
      if (fakeSignIn) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'test1@test.com', password: 'password');
        } catch (_) {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: 'test1@test.com', password: 'password');
        }
      } else {
        final googleUser = await GoogleSignIn().signIn();
        final googleAuth = await googleUser?.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _signInAnonymouslyButton() async {
    setState(() => _loading = true);
    try {
      if (FirebaseAuth.instance.currentUser != null) await FirebaseAuth.instance.signOut();
      if (fakeSignIn) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: 'test2@test.com', password: 'password');
        } catch (_) {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(email: 'test2@test.com', password: 'password');
        }
      } else {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Align(
          alignment: const Alignment(0.0, 0.1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text(
                    appName,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontSize: 96.0,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 56.0),
              FilledButton.icon(
                onPressed: _loading ? null : _signInWithGoogleButton,
                icon: const Icon(BoxIcons.bxl_google),
                label: const Text('Sign in with Google'),
              ),
              // FilledButton.tonalIcon(
              //   onPressed: _loading ? null : _signInWithAppleButton,
              //   icon: const Icon(BoxIcons.bxl_apple),
              //   label: const Text('Sign in with Apple'),
              // ),
              FilledButton.tonalIcon(
                onPressed: _loading ? null : _signInAnonymouslyButton,
                icon: const Icon(BoxIcons.bx_ghost),
                label: const Text('Sign in Anonymously'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
