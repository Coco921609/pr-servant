import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔒 Verrouillage en mode PORTRAIT uniquement (Ignoré automatiquement sur le Web)
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Style de la barre système (barre de statut avec un fond sombre pour une visibilité maximale de l'heure et de la batterie)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF121212), // Fond assorti à l'application pour détacher l'heure/batterie
      statusBarIconBrightness: Brightness.light, // Icônes blanches (Android)
      statusBarBrightness: Brightness.dark, // Icônes claires (iOS)
    ),
  );

  // Initialisation de Supabase
  // Comme les données sont enregistrées dans la base de données distante Supabase,
  // la suppression ou la désinstallation de l'application n'efface rien.
  // Tout est sauvegardé et sera automatiquement retrouvé au ré-alunissage de l'application.
  // Quand première fois on ouvre l'application il y a la page login.screen pour créer un compte.
  // Quand on y retourne la deuxième fois, ça affiche le mot de passe et le prénom pour se connecter.
  // Si on supprime ou désinstalle l'application, cela n'efface rien sur les comptes.
  await Supabase.initialize(
    url: 'https://bwwzrofzbjelcspivlhp.supabase.co',
    anonKey: 'sb_publishable_8Tt410qhjElaxjbauLIh2Q_JinIaoCz',
  );

  runApp(
    const ProviderScope(
      child: EftekadApp(),
    ),
  );
}