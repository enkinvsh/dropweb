package ca

import (
	"crypto/x509"
	"errors"
	"fmt"
	"strings"
	"time"
)

// NewNameCertVerifier создаёт функцию проверки цепочки сертификатов для указанного имени.
// Если dnsName начинается с "*." (например, "*.meybz.asia" для пулов pool-join),
// проверяет цепочку доверия УЦ и принадлежность SAN сертификата базовому домену.
func NewNameCertVerifier(dnsName string, roots *x509.CertPool, now func() time.Time) func([]*x509.Certificate) error {
	wildcardSuffix := ""
	if strings.HasPrefix(dnsName, "*.") && len(dnsName) > 2 {
		wildcardSuffix = strings.ToLower(dnsName[1:])
	}
	return func(certificates []*x509.Certificate) error {
		if len(certificates) == 0 {
			return errors.New("tls: no peer certificates")
		}

		intermediates := x509.NewCertPool()
		for _, certificate := range certificates[1:] {
			intermediates.AddCert(certificate)
		}
		verifyOptions := x509.VerifyOptions{
			Roots:         roots,
			Intermediates: intermediates,
			DNSName:       dnsName,
		}
		if wildcardSuffix != "" {
			verifyOptions.DNSName = ""
		}
		if now != nil {
			verifyOptions.CurrentTime = now()
		}
		if _, err := certificates[0].Verify(verifyOptions); err != nil {
			return err
		}
		if wildcardSuffix != "" {
			if !matchesBaseDomainSuffix(certificates[0], wildcardSuffix) {
				return fmt.Errorf("x509: certificate %v is not valid for %s", certificates[0].DNSNames, dnsName)
			}
		}
		return nil
	}
}

func matchesBaseDomainSuffix(cert *x509.Certificate, suffix string) bool {
	base := strings.TrimPrefix(suffix, ".")
	for _, san := range cert.DNSNames {
		s := strings.ToLower(strings.TrimSuffix(san, "."))
		if s == base || strings.HasSuffix(s, suffix) {
			return true
		}
	}
	cn := strings.ToLower(strings.TrimSuffix(cert.Subject.CommonName, "."))
	return cn == base || strings.HasSuffix(cn, suffix)
}
