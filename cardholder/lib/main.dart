import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/http/kbm_backend_client.dart';

void main() {
  // Default (127.0.0.1) sirve para web, macOS/iOS y un simulador de iOS —
  // todos comparten el loopback de esta máquina. Un emulador de Android
  // necesita 10.0.2.2 en su lugar (su propia red virtual, no una
  // excepción a docs/security/threat-model.md punto 15 — el backend
  // sigue en loopback, solo cambia cómo el emulador lo alcanza); un
  // dispositivo físico necesitaría la IP de LAN de esta máquina, lo cual
  // sí requiere decidir si el backend escucha fuera de loopback. Ver
  // "Probar en mobile" en cardholder/README.md.
  const baseUrl = String.fromEnvironment('KBM_BACKEND_URL', defaultValue: 'http://127.0.0.1:8080');
  runApp(KbmCardholderApp(backendClient: KbmBackendClient(baseUrl: baseUrl)));
}
