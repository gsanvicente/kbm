import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:kbm_admin/core/http/kbm_backend_client.dart';
import 'package:kbm_admin/features/spei/http_spei_repository.dart';

/// `flutter test` nunca ejercita este parseo (usa `FakeSpeiRepository`,
/// nunca JSON real) — por eso un DTO al que le faltaba `clientId` pasó
/// desapercibido hasta que se vio en vivo en "Reportes" > "Pagos SPEI"
/// ("TypeError: null: type 'Null' is not a subtype of type 'String'").
/// Estas pruebas fijan la forma real del JSON que manda el backend
/// (`dto.SPEIPayment`/`SPEIDeposit`/`BeneficiaryDirectoryEntry`) para que
/// una regresión así truene aquí, no en producción.
void main() {
  test('listAllByClients parses a real-shaped SPEIPayment JSON payload, including clientId', () async {
    final client = KbmBackendClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'p1',
              'clientId': 'c1',
              'accountId': 'a1',
              'beneficiaryId': 'b1',
              'amount': 100.0,
              'status': 'executed',
              'resolvedByEmail': null,
              'resolutionNotes': null,
              'providerReference': 'SIM-1',
              'beneficiaryAlias': 'Mamá',
              'beneficiaryClabe': '****2302',
              'requestedByFullName': 'Juan Perez',
              'createdAt': '2026-09-24T21:13:38.050179-06:00',
              'updatedAt': '2026-09-24T21:13:38.059427-06:00',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repo = HttpSpeiRepository(client: client);

    final payments = await repo.listAllByClients(['c1']);

    expect(payments, hasLength(1));
    expect(payments.first.clientId, 'c1');
    expect(payments.first.beneficiaryAlias, 'Mamá');
  });

  test('listDepositsByClients parses a real-shaped SPEIDeposit JSON payload, including clientId', () async {
    final client = KbmBackendClient(
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'id': 'd1',
              'clientId': 'c1',
              'accountId': 'a1',
              'amount': 500.0,
              'providerReference': 'SIM-2',
              'createdAt': '2026-09-24T21:13:38.050179-06:00',
              'cardholderFullName': 'Juan Perez',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repo = HttpSpeiRepository(client: client);

    final deposits = await repo.listDepositsByClients(['c1']);

    expect(deposits, hasLength(1));
    expect(deposits.first.clientId, 'c1');
  });
}
