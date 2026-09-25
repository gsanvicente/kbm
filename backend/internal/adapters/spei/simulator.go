// Package spei implementa ports.SPEIGateway sin ningún proveedor real
// elegido todavía — mismo molde que internal/adapters/processor
// (docs/adr/0011-processor-integration-architecture-and-postgres-default.md),
// aplicado a SPEI por docs/adr/0021-conector-spei.md. Este Simulator es
// el único adaptador que existe hoy: sirve para desarrollar y probar
// toda la lógica de negocio (Cuenta Individual, Beneficiario de Pago,
// approval_rules) sin depender de STP/Banorte/Arcus/etc. Nunca se usa
// contra dinero real.
package spei

import (
	"context"
	"crypto/rand"
	"fmt"
	"math/big"
	"time"

	"github.com/koons/kbm/backend/internal/domain/beneficiary"
	"github.com/koons/kbm/backend/internal/domain/clabe"
	"github.com/koons/kbm/backend/internal/domain/speipayment"
)

// simulatorBankCode — "846" en internal/domain/clabe, reservado para
// "KBM (simulador de pruebas)". Nunca corresponde a un banco real; una
// CLABE con este prefijo nunca debe aceptarse como beneficiario externo
// legítimo fuera de este simulador (el catálogo la resuelve igual que
// cualquier otra, a propósito, para no tratar al simulador distinto del
// resto del código).
const simulatorBankCode = "846"

type Simulator struct{}

func NewSimulator() *Simulator { return &Simulator{} }

// ProvisionCLABE genera una CLABE sintética, formalmente válida
// (dígito verificador correcto, banco del catálogo) pero sin ninguna
// cuenta bancaria real detrás. Un proveedor real pediría una a su API.
func (s *Simulator) ProvisionCLABE(_ context.Context, _ string) (string, error) {
	prefix := simulatorBankCode + randomDigits(14)
	digit, err := clabe.CheckDigit(prefix)
	if err != nil {
		return "", err
	}
	return prefix + string(digit), nil
}

// DispatchPayment — el molde real (docs/adr/0021-conector-spei.md,
// "Consecuencias") es asíncrono vía outbox/queue/worker; hasta que haya
// un proveedor de verdad, este simulador corre síncrono y siempre
// confirma de inmediato.
func (s *Simulator) DispatchPayment(_ context.Context, _ speipayment.Payment, _ beneficiary.Beneficiary) (string, error) {
	return fmt.Sprintf("SIM-%d", time.Now().UnixNano()), nil
}

func randomDigits(n int) string {
	digits := make([]byte, n)
	for i := range digits {
		d, err := rand.Int(rand.Reader, big.NewInt(10))
		if err != nil {
			// crypto/rand solo falla si el lector del sistema falla —
			// nunca en un entorno sano; 0 es un dígito válido cualquiera.
			d = big.NewInt(0)
		}
		digits[i] = byte('0') + byte(d.Int64())
	}
	return string(digits)
}
