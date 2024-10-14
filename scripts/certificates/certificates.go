package main

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"log"
	"math/big"
	"os"
	"time"
)

// This is quickly hacked together
func main() {
	rootPrivateKey, rootTemplate, err := createCertificateTemplate("root.linkerd.cluster.local")
	if err != nil {
		log.Fatal(err)
	}

	rootCert, rootCertPem, rootKeyPem, err := createCertificate(rootTemplate, rootTemplate, rootPrivateKey, rootPrivateKey)
	if err != nil {
		log.Fatal(err)
	}

	intermediatePrivateKey, intermediateTemplate, err := createCertificateTemplate("identity.linkerd.cluster.local")
	if err != nil {
		log.Fatal(err)
	}

	_, intermediateCertPem, intermediateKeyPem, err := createCertificate(intermediateTemplate, rootCert, intermediatePrivateKey, rootPrivateKey)
	if err != nil {
		log.Fatal(err)
	}

	if err := os.Mkdir("./.certificates", 0700); err != nil {
		log.Fatal(err)
	}

	table := []struct {
		filename string
		data     []byte
	}{
		{filename: "./.certificates/ca.crt", data: rootCertPem},
		{filename: "./.certificates/ca.key", data: rootKeyPem},
		{filename: "./.certificates/issuer.crt", data: intermediateCertPem},
		{filename: "./.certificates/issuer.key", data: intermediateKeyPem},
	}
	for _, t := range table {
		if err = os.WriteFile(t.filename, t.data, 0755); err != nil {
			log.Fatal(err)
		}
	}

	log.Println("successfully generated certificates")
}

func createCertificateTemplate(commonName string) (*ecdsa.PrivateKey, *x509.Certificate, error) {
	privateKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, nil, err
	}

	template := &x509.Certificate{
		SerialNumber: big.NewInt(1),
		Subject: pkix.Name{
			CommonName: commonName,
		},
		NotBefore:             time.Now(),
		NotAfter:              time.Now().Add(time.Hour * 24 * 365 * 10),
		KeyUsage:              x509.KeyUsageCertSign | x509.KeyUsageCRLSign | x509.KeyUsageDigitalSignature,
		MaxPathLen:            1,
		IsCA:                  true,
		BasicConstraintsValid: true,
	}

	return privateKey, template, nil
}

func createCertificate(template, parent *x509.Certificate, issuerPrivateKey, rootPrivateKey *ecdsa.PrivateKey) (*x509.Certificate, []byte, []byte, error) {
	certBytes, err := x509.CreateCertificate(rand.Reader, template, parent, issuerPrivateKey.Public(), rootPrivateKey)
	if err != nil {
		return nil, nil, nil, fmt.Errorf("failed to create certificate: %w", err)
	}

	cert, err := x509.ParseCertificate(certBytes)
	if err != nil {
		return nil, nil, nil, err
	}

	rootCrtPem, rootKeyPem, err := createPEM(certBytes, issuerPrivateKey)
	if err != nil {
		return nil, nil, nil, err
	}

	return cert, rootCrtPem, rootKeyPem, nil
}

func createPEM(cert []byte, privateKey *ecdsa.PrivateKey) ([]byte, []byte, error) {
	crt := &bytes.Buffer{}
	if err := pem.Encode(crt, &pem.Block{Type: "CERTIFICATE", Bytes: cert}); err != nil {
		return nil, nil, err
	}

	key := &bytes.Buffer{}
	privateBytes, err := x509.MarshalECPrivateKey(privateKey)
	if err != nil {
		return nil, nil, err
	}

	if err = pem.Encode(key, &pem.Block{Type: "EC PRIVATE KEY", Bytes: privateBytes}); err != nil {
		return nil, nil, err
	}

	return crt.Bytes(), key.Bytes(), nil
}
