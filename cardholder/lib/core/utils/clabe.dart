/// Validación de CLABE (formato + banco) del lado del cliente, para dar
/// una vista previa instantánea del banco detectado antes de guardar un
/// Beneficiario — ver
/// docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md.
///
/// Puerto directo de `backend/internal/domain/clabe/clabe.go` (mismo
/// algoritmo público del dígito verificador, mismo catálogo) — sin
/// código de runtime compartido entre `backend` y `cardholder` (lenguajes
/// distintos) ni entre `admin` y `cardholder` (ver ADR-0002), así que se
/// duplica a propósito. **Si el catálogo de bancos cambia en el backend,
/// debe actualizarse aquí también** — la validación real y definitiva
/// siempre es la del servidor al guardar; esto es solo una vista previa
/// para ayudar a detectar errores de captura antes de intentarlo.
library;

const Map<String, String> _bankNameByCode = {
  '002': 'Banamex',
  '006': 'Bancomext',
  '009': 'Banobras',
  '012': 'BBVA México',
  '014': 'Santander',
  '019': 'Banjercito',
  '021': 'HSBC',
  '030': 'Banco del Bajío',
  '036': 'Inbursa',
  '042': 'Mifel',
  '044': 'Scotiabank',
  '058': 'Banregio',
  '059': 'Invex',
  '072': 'Banorte',
  '106': 'Bank of America',
  '127': 'Azteca',
  '128': 'Autofin',
  '130': 'Compartamos',
  '137': 'Bankaool',
  '138': 'Multiva',
  '646': 'STP (SPEI)',
  '846': 'KBM (simulador de pruebas)',
};

const List<int> _weights = [3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7];

bool _isAllDigits(String s) => s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s);

/// El dígito verificador para un prefijo de 17 dígitos, o null si
/// [prefix] no tiene exactamente 17 dígitos.
int? clabeCheckDigit(String prefix) {
  if (prefix.length != 17 || !_isAllDigits(prefix)) return null;
  var sum = 0;
  for (var i = 0; i < _weights.length; i++) {
    final digit = prefix.codeUnitAt(i) - '0'.codeUnitAt(0);
    sum += (digit * _weights[i]) % 10;
  }
  return (10 - (sum % 10)) % 10;
}

/// true si [clabeNumber] tiene 18 dígitos y un dígito verificador
/// correcto — no consulta el catálogo de bancos, ver [clabeBankName].
bool isValidClabeChecksum(String clabeNumber) {
  if (clabeNumber.length != 18 || !_isAllDigits(clabeNumber)) return false;
  final digit = clabeCheckDigit(clabeNumber.substring(0, 17));
  if (digit == null) return false;
  return digit == clabeNumber.codeUnitAt(17) - '0'.codeUnitAt(0);
}

/// El nombre del banco para los primeros 3 dígitos de [clabeNumber], o
/// null si el código no está en el catálogo.
String? clabeBankName(String clabeNumber) {
  if (clabeNumber.length < 3) return null;
  return _bankNameByCode[clabeNumber.substring(0, 3)];
}
