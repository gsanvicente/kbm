/// Catálogo curado de nacionalidades para el combo de captura de un
/// Tarjetahabiente — ver
/// docs/feature/alta-y-gestion-de-tarjetahabientes/README.md, "Catálogo
/// de nacionalidades". No es la lista completa de países: la base de
/// clientes de Koons es mayoritariamente mexicana, y "Otra" es un
/// catch-all explícito (no habilita texto libre en esta iteración).
const List<String> nationalityOptions = [
  'Mexicana',
  'Estadounidense',
  'Canadiense',
  'Española',
  'Colombiana',
  'Argentina',
  'Otra',
];

/// Determina si CURP es requerido — ver docs/business/kyc-tarjetahabiente.md.
bool isMexicanNationality(String nationality) => nationality == 'Mexicana';
