package middleware

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/koons/kbm/backend/internal/adapters/auth/local"
)

type claimsCtxKey struct{}

// RequireAuth verifica el header `Authorization: Bearer <token>` en cada
// petición protegida — ver
// docs/adr/0013-jwt-session-authentication.md. Nunca distingue "sin
// token" de "token inválido" de "token expirado" en la respuesta (mismo
// criterio de mensaje genérico que el resto de la plataforma).
func RequireAuth(issuer *local.TokenIssuer) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			header := r.Header.Get("Authorization")
			tokenString, ok := strings.CutPrefix(header, "Bearer ")
			if !ok || tokenString == "" {
				writeUnauthorized(w)
				return
			}
			claims, err := issuer.Verify(tokenString)
			if err != nil {
				writeUnauthorized(w)
				return
			}
			ctx := context.WithValue(r.Context(), claimsCtxKey{}, claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func writeUnauthorized(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusUnauthorized)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "no autorizado"})
}

func writeForbidden(w http.ResponseWriter) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusForbidden)
	_ = json.NewEncoder(w).Encode(map[string]string{"message": "no autorizado"})
}

// RequireStaff se monta después de RequireAuth (nunca antes — necesita
// que ya haya claims en el contexto) para las rutas que administra
// admin/ y que ningún Tarjetahabiente debería poder alcanzar aunque
// tuviera un token válido de su propia sesión. Ver
// docs/adr/0013-jwt-session-authentication.md.
func RequireStaff(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims, ok := ClaimsFromContext(r.Context())
		if !ok || claims.Type != local.SubjectStaff {
			writeForbidden(w)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ClaimsFromContext — los handlers lo usan para saber quién hizo la
// petición (ya verificado) y decidir si puede operar sobre el recurso
// pedido (ver internal/adapters/http/handler/authz.go). Un handler
// montado bajo RequireAuth siempre encuentra claims aquí — el segundo
// valor solo es false si alguien lo llama fuera de esa cadena de
// middleware (error de programación, no un caso de negocio real).
func ClaimsFromContext(ctx context.Context) (*local.Claims, bool) {
	claims, ok := ctx.Value(claimsCtxKey{}).(*local.Claims)
	return claims, ok
}
