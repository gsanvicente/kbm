## Resumen
<!-- Qué cambia y por qué, en 1-3 frases. -->

## Documentación que sustenta este cambio (obligatorio)
Regla del proyecto: **no hay desarrollo sin documentación que lo
sustente** (ver `README.md` raíz). Marca lo que aplique y enlaza el
archivo exacto:

- [ ] ADR: `docs/adr/____`
- [ ] TDR: `<componente>/docs/tdr/____`
- [ ] Feature: `docs/feature/____`
- [ ] Actualicé `docs/business/` (si el cambio afecta una regla de negocio)
- [ ] Actualicé `docs/security/` (si el cambio afecta superficie de
      autorización, datos sensibles, o integración externa)

Si ningún punto aplica, explica aquí por qué este cambio no requiere
documentación previa:

## Checklist técnico
- [ ] El dominio (`internal/domain` / lógica de negocio en Flutter) sigue
      sin depender de frameworks/infraestructura externa
- [ ] Agregué o actualicé pruebas relevantes
- [ ] Si toqué autorización o multi-tenancy: verifiqué que la regla
      también está reflejada en RLS (defensa en profundidad, ver
      `docs/adr/0003-multitenancy-rls-hierarchy.md`)
- [ ] Si agregué una operación que muta `balance_operations`/`cards`/
      ledger: emite el evento de auditoría correspondiente
