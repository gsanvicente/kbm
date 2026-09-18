/// Vista mínima del propio Tarjetahabiente que necesita esta app — nada
/// de KYC/domicilio (eso es exclusivo de `admin/`, el staff lo captura).
/// `clientId` nunca se muestra en pantalla, solo se usa para acotar la
/// búsqueda de destino de una transferencia C2C al mismo Cliente — ver
/// docs/feature/transferencia-c2c-tarjetahabiente/README.md, "Alcance".
class Cardholder {
  final String id;
  final String clientId;
  final String fullName;
  final String email;
  final bool isActive;

  const Cardholder({
    required this.id,
    required this.clientId,
    required this.fullName,
    required this.email,
    this.isActive = true,
  });
}
