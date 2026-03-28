package crypto

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
	"os"
)

// key returns the 32-byte AES-256 encryption key from the environment.
// Falls back to a dev-only default so local development works without config.
//
// SECURITY WARNING (edge case 13): In production, the ENCRYPTION_KEY env var
// MUST be set to a unique, randomly generated 32-byte value. The hardcoded
// dev fallback is publicly known in the source code. Any agent (or person)
// with access to the source code can decrypt medical data if the default key
// is used in production. Set ENCRYPTION_KEY before deploying.
func key() []byte {
	k := os.Getenv("ENCRYPTION_KEY")
	if k == "" {
		// Dev-only fallback — 32 bytes for AES-256.
		// WARNING: Do NOT use this default in production. See comment above.
		k = "highlander-dev-key-change-in-prod!"[:32]
	}
	b := []byte(k)
	if len(b) != 32 {
		panic("ENCRYPTION_KEY must be exactly 32 bytes for AES-256")
	}
	return b
}

// Encrypt encrypts plaintext using AES-256-GCM and returns a base64 string.
func Encrypt(plaintext string) (string, error) {
	if plaintext == "" {
		return "", nil
	}
	block, err := aes.NewCipher(key())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts a base64-encoded AES-256-GCM ciphertext back to plaintext.
func Decrypt(encoded string) (string, error) {
	if encoded == "" {
		return "", nil
	}
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", errors.New("ciphertext too short")
	}
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}
