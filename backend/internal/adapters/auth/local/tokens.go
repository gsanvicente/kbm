// Package local implements JWT issuance/verification for local
// development — see
// docs/adr/0013-jwt-session-authentication.md. In AWS, this is where
// Cognito would take over (see internal/adapters/auth/cognito), but the
// token *shape* (Claims below) stays the same either way so the rest of
// the app never needs to know which one issued it.
package local

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// SubjectType distingue las dos identidades que este backend conoce —
// nunca se emite un token sin uno de estos dos, ver
// docs/adr/0013-jwt-session-authentication.md.
type SubjectType string

const (
	SubjectStaff      SubjectType = "staff"
	SubjectCardholder SubjectType = "cardholder"
)

// ttl — duración de sesión, igual para ambos tipos por simplicidad en
// esta etapa del proyecto (ver la ADR, "Alternativas consideradas" sobre
// por qué no hay refresh tokens todavía).
const ttl = 12 * time.Hour

// Claims — el mismo shape para un token de staff o de Tarjetahabiente;
// los campos que no aplican quedan vacíos. ClientID es nil solo para
// Super Admin (alcance global) o, del lado Tarjetahabiente, nunca (todo
// Tarjetahabiente pertenece a un Cliente).
type Claims struct {
	jwt.RegisteredClaims
	Type         SubjectType `json:"typ"`
	Role         string      `json:"role,omitempty"`
	ClientID     *string     `json:"clientId,omitempty"`
	CardholderID string      `json:"cardholderId,omitempty"`
}

var ErrInvalidToken = errors.New("invalid or expired token")

type TokenIssuer struct {
	secret []byte
}

func NewTokenIssuer(secret string) *TokenIssuer {
	return &TokenIssuer{secret: []byte(secret)}
}

// IssueStaff — subject es el user id (users.id). role es el string del
// enum de staff.Role ("super_admin", etc.). clientID nil para Super
// Admin.
func (i *TokenIssuer) IssueStaff(subject, role string, clientID *string) (string, error) {
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   subject,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
		Type:     SubjectStaff,
		Role:     role,
		ClientID: clientID,
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(i.secret)
}

// IssueCardholder — subject y cardholderID son el mismo valor
// (cardholders.id) — CardholderID queda explícito además de Subject para
// que los handlers no tengan que saber que, para este tipo de token,
// "subject" significa "cardholder id".
func (i *TokenIssuer) IssueCardholder(cardholderID, clientID string) (string, error) {
	now := time.Now()
	claims := Claims{
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   cardholderID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
		},
		Type:         SubjectCardholder,
		ClientID:     &clientID,
		CardholderID: cardholderID,
	}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString(i.secret)
}

// Verify — nunca distingue "expirado" de "firma inválida" de
// "malformado" en el error que devuelve (mismo criterio de mensaje
// genérico que el resto de la plataforma, ver
// docs/security/threat-model.md) — todo colapsa a ErrInvalidToken.
func (i *TokenIssuer) Verify(tokenString string) (*Claims, error) {
	claims := &Claims{}
	token, err := jwt.ParseWithClaims(tokenString, claims, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, ErrInvalidToken
		}
		return i.secret, nil
	})
	if err != nil || !token.Valid {
		return nil, ErrInvalidToken
	}
	return claims, nil
}
