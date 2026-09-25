// Package clabe valida CLABEs mexicanas (18 dígitos) sin depender de
// ningún proveedor SPEI — ver docs/adr/0021-conector-spei.md,
// "Seguridad". Dos candados independientes: el dígito verificador
// (algoritmo público, nunca requiere red) y un catálogo de bancos por
// los primeros 3 dígitos (detecta typos y bancos inexistentes). Ninguno
// de los dos sustituye una validación real de PLD/OFAC — eso requiere un
// proveedor, ver el ADR.
package clabe

import (
	"fmt"
	"unicode"
)

// bankNameByCode — catálogo ilustrativo de instituciones mexicanas
// comunes, no el catálogo oficial completo de Banxico. Suficiente para
// rechazar typos y códigos inventados; se reemplaza por el catálogo real
// del proveedor elegido cuando exista uno.
var bankNameByCode = map[string]string{
	"002": "Banamex",
	"006": "Bancomext",
	"009": "Banobras",
	"012": "BBVA México",
	"014": "Santander",
	"019": "Banjercito",
	"021": "HSBC",
	"030": "Banco del Bajío",
	"036": "Inbursa",
	"042": "Mifel",
	"044": "Scotiabank",
	"058": "Banregio",
	"059": "Invex",
	"072": "Banorte",
	"106": "Bank of America",
	"127": "Azteca",
	"128": "Autofin",
	"130": "Compartamos",
	"137": "Bankaool",
	"138": "Multiva",
	"646": "STP (SPEI)",
	"846": "KBM (simulador de pruebas)",
}

// weights — pesos módulo 10 (3-7-1 repetido) para los primeros 17
// dígitos, algoritmo público de la CLABE.
var weights = [17]int{3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7, 1, 3, 7}

func isAllDigits(s string) bool {
	for _, r := range s {
		if !unicode.IsDigit(r) {
			return false
		}
	}
	return true
}

// CheckDigit calcula el dígito verificador para un prefijo de 17 dígitos
// — usado tanto por ValidChecksum como por internal/adapters/spei (el
// simulador) para generar CLABEs sintéticas válidas.
func CheckDigit(prefix string) (byte, error) {
	if len(prefix) != 17 || !isAllDigits(prefix) {
		return 0, fmt.Errorf("clabe: prefix must be 17 digits, got %q", prefix)
	}
	sum := 0
	for i, w := range weights {
		digit := int(prefix[i] - '0')
		sum += (digit * w) % 10
	}
	verifier := (10 - (sum % 10)) % 10
	return byte('0' + verifier), nil
}

// ValidChecksum valida el formato (18 dígitos) y el dígito verificador.
// No consulta ningún catálogo — ver BankName para eso.
func ValidChecksum(clabeNumber string) bool {
	if len(clabeNumber) != 18 || !isAllDigits(clabeNumber) {
		return false
	}
	digit, err := CheckDigit(clabeNumber[:17])
	if err != nil {
		return false
	}
	return digit == clabeNumber[17]
}

// BankName devuelve el nombre del banco para los primeros 3 dígitos de
// [clabeNumber], o ("", false) si el código no está en el catálogo — un
// código desconocido es motivo de rechazo (nunca "banco desconocido"
// silencioso).
func BankName(clabeNumber string) (string, bool) {
	if len(clabeNumber) < 3 {
		return "", false
	}
	name, ok := bankNameByCode[clabeNumber[:3]]
	return name, ok
}
