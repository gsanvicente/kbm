package clabe

import "testing"

// checksumFor construye una CLABE de fixture válida a partir de un
// prefijo de 17 dígitos, usando el propio CheckDigit bajo prueba.
func checksumFor(t *testing.T, prefix string) string {
	t.Helper()
	digit, err := CheckDigit(prefix)
	if err != nil {
		t.Fatalf("CheckDigit: %v", err)
	}
	return prefix + string(digit)
}

func TestValidChecksum_AcceptsWellFormedCLABE(t *testing.T) {
	got := checksumFor(t, "84600001183597193"[:17])
	if !ValidChecksum(got) {
		t.Fatalf("expected a freshly computed checksum to validate, got %q", got)
	}
}

func TestValidChecksum_RejectsWrongLength(t *testing.T) {
	if ValidChecksum("12345") {
		t.Fatalf("expected a too-short CLABE to be rejected")
	}
}

func TestValidChecksum_RejectsNonDigits(t *testing.T) {
	if ValidChecksum("84600001183597A193") {
		t.Fatalf("expected a non-numeric CLABE to be rejected")
	}
}

func TestValidChecksum_RejectsTamperedDigit(t *testing.T) {
	good := checksumFor(t, "84600001183597193"[:17])
	tampered := []byte(good)
	digit := int(tampered[5] - '0')
	tampered[5] = byte('0' + (digit+1)%10) // cambia un dígito interno, nunca el verificador
	if ValidChecksum(string(tampered)) {
		t.Fatalf("expected a tampered CLABE to fail checksum, got %q", tampered)
	}
}

func TestBankName_KnownAndUnknownCodes(t *testing.T) {
	if name, ok := BankName("072" + "00001183597193"[:14]); !ok || name != "Banorte" {
		t.Fatalf("expected Banorte for code 072, got %q, ok=%v", name, ok)
	}
	if _, ok := BankName("999" + "00001183597193"[:14]); ok {
		t.Fatalf("expected code 999 to be unknown")
	}
}
