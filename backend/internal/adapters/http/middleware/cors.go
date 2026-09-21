package middleware

import "net/http"

// allowedOrigins — nunca un wildcard. Ver
// docs/security/threat-model.md punto 15: este backend recibe el PAN
// completo en el cuerpo de /v1/transfers/resolve, así que un CORS
// abierto dejaría a cualquier sitio web con JavaScript hacerle
// peticiones si este proceso alguna vez quedara alcanzable fuera de
// loopback.
var allowedOrigins = map[string]bool{
	"http://127.0.0.1:8765": true, // admin/
	"http://127.0.0.1:8766": true, // cardholder/
}

// CORS solo habilita los dos orígenes de desarrollo de Flutter web — ver
// docs/adr/0010-in-memory-shared-backend-for-cards-and-ledger.md, punto 5.
func CORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if allowedOrigins[origin] {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			// PUT/DELETE — desde Configuración de cliente (límites y reglas
			// de aprobación), ver
			// docs/feature/configuracion-de-cliente/README.md.
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			// Authorization añadido con la sesión JWT — ver
			// docs/adr/0013-jwt-session-authentication.md. Sin esto el
			// navegador bloquea el header en la petición real tras el
			// preflight (admin/ y cardholder/ corren en un origen
			// distinto al backend).
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		}
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
