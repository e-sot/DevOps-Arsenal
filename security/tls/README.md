# TLS Certificate Management

## Overview

This directory contains TLS certificate management tools and configurations for the ETO Group infrastructure. All certificates are managed using OpenSSL and follow security best practices.

## Directory Structure

security/tls/
├── ca/ # Certificate Authority files
│ ├── ca.crt # CA certificate
│ ├── ca.key # CA private key (restricted access)
│ └── ca.srl # Serial number tracking
├── webapp/ # Web application certificates
│ ├── webapp.crt # Web application certificate
│ ├── webapp.key # Private key
│ └── webapp.csr # Certificate signing request
├── openssl.cnf # OpenSSL configuration
├── certs.conf # Certificate extensions configuration
├── generate-certs.sh # Certificate generation script
├── renew-certs.sh # Certificate renewal script
└── verify-certs.sh # Certificate verification script

text

## Certificate Specifications

### Root CA Certificate
- Validity: 10 years
- Key Size: 4096 bits
- Signature Algorithm: sha512WithRSAEncryption
- Key Usage: Certificate Sign, CRL Sign
- Basic Constraints: CA:TRUE

### Web Application Certificate
- Validity: 1 year
- Key Size: 4096 bits
- Signature Algorithm: sha512WithRSAEncryption
- Key Usage: Digital Signature, Key Encipherment
- Extended Key Usage: Server Authentication, Client Authentication
- Subject Alternative Names: Configured per environment

## Security Measures

### Private Key Protection
- All private keys are stored with 0600 permissions
- Access restricted to root and ssl-cert group
- Keys are never transmitted over networks
- Regular key rotation enforced

### Certificate Management
- Automated certificate generation
- Regular validation checks
- Expiration monitoring
- Secure backup procedures

## Usage Instructions

### Generate New Certificates
```bash
./generate-certs.sh

Renew Certificates

bash
./renew-certs.sh

Verify Certificates

bash
./verify-certs.sh

Certificate Renewal Process

    Preparation
        Check current certificate expiration
        Verify CA certificate validity
        Backup existing certificates
    Generation
        Generate new key pair
        Create Certificate Signing Request
        Sign with CA certificate
    Validation
        Verify certificate chain
        Check key permissions
        Validate configurations
    Deployment
        Update Kubernetes secrets
        Roll out to services
        Verify service health

Emergency Procedures
Certificate Compromise

    Revoke compromised certificate
    Generate new certificate
    Update CRL
    Deploy emergency updates

CA Compromise

    Generate new CA
    Reissue all certificates
    Deploy root certificate updates
    Update trust stores

Monitoring and Maintenance
Regular Checks

    Daily certificate validation
    Weekly expiration checks
    Monthly security audit

Alerts

    Certificate expiration warnings
    Validation failures
    Security anomalies

Troubleshooting
Common Issues

    Certificate chain validation failures
    Permission problems
    Key mismatches

Verification Commands

bash
# Verify certificate
openssl verify -CAfile ca/ca.crt webapp/webapp.crt

# Check certificate info
openssl x509 -in webapp/webapp.crt -text -noout

# Verify private key
openssl rsa -in webapp/webapp.key -check

Security Contacts

    Security Team: security@eto-group.local
    Emergency Contact: emergency@eto-group.local
    Certificate Management: certs@eto-group.local
