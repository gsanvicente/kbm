package middleware

import "net/http"

// NoStore agrega `Cache-Control: no-store` a toda respuesta — ninguna
// respuesta de esta API es cacheable, ni por el navegador ni por un
// proxy intermedio: son datos financieros con sesión, y varias
// pantallas (agregar un Beneficiario, enviar un pago SPEI) dependen de
// volver a pedir la misma URL inmediatamente después de escribir y
// obtener el dato fresco, no una copia vieja. Se detectaron dos casos
// reales en vivo donde la pantalla no reflejaba lo que el propio
// usuario acababa de guardar — no se pudo aislar con certeza si la
// causa era caché de navegador sobre un GET sin este header, pero
// agregarlo elimina la duda de raíz y es buena práctica de todos modos
// para una API que nunca debería servir una respuesta vieja a nadie más
// que el propio navegador que la pidió. Ver
// docs/adr/0025-vista-previa-de-banco-antes-de-guardar-beneficiario.md
// y docs/adr/0027-validacion-de-saldo-y-estatus-de-pago-spei.md.
func NoStore(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}
