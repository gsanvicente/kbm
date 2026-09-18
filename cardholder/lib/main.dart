import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/http/kbm_backend_client.dart';

void main() {
  runApp(KbmCardholderApp(backendClient: KbmBackendClient()));
}
