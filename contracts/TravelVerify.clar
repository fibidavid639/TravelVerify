;; TravelVerify - Travel Document Verification Platform
;; Handles verification of travel documents, visas, and health certificates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-expired (err u103))
(define-constant err-invalid-status (err u104))

;; Data Variables
(define-data-var service-active bool true)
(define-data-var verification-fee uint u100)
(define-data-var total-verifications uint u0)

;; Data Maps
(define-map TravelDocuments
    { document-id: (string-ascii 32) }
    {
        holder-name: (string-ascii 50),
        document-type: (string-ascii 20),
        issuing-country: (string-ascii 30),
        issue-date: uint,
        expiry-date: uint,
        status: (string-ascii 10)
    }
)

(define-map VisaRecords
    { visa-id: (string-ascii 32) }
    {
        holder-id: (string-ascii 32),
        type: (string-ascii 20),
        country: (string-ascii 30),
        issue-date: uint,
        expiry-date: uint,
        entries-allowed: uint,
        entries-used: uint
    }
)

(define-map HealthCertificates
    { certificate-id: (string-ascii 32) }
    {
        holder-id: (string-ascii 32),
        test-type: (string-ascii 30),
        test-date: uint,
        result: (string-ascii 10),
        issuing-facility: (string-ascii 50),
        validity-period: uint
    }
)

(define-map VerifiedUsers
    { user-id: (string-ascii 32) }
    {
        travel-history: (list 10 (string-ascii 50)),
        verification-count: uint,
        last-verified: uint
    }
)

;; Public Functions

(define-public (register-travel-document 
    (document-id (string-ascii 32))
    (holder-name (string-ascii 50))
    (document-type (string-ascii 20))
    (issuing-country (string-ascii 30))
    (issue-date uint)
    (expiry-date uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-none (map-get? TravelDocuments {document-id: document-id})) err-already-exists)
        (map-set TravelDocuments
            {document-id: document-id}
            {
                holder-name: holder-name,
                document-type: document-type,
                issuing-country: issuing-country,
                issue-date: issue-date,
                expiry-date: expiry-date,
                status: "ACTIVE"
            }
        )
        (ok true)
    )
)

(define-public (add-visa-record
    (visa-id (string-ascii 32))
    (holder-id (string-ascii 32))
    (visa-type (string-ascii 20))
    (country (string-ascii 30))
    (issue-date uint)
    (expiry-date uint)
    (entries-allowed uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set VisaRecords
            {visa-id: visa-id}
            {
                holder-id: holder-id,
                type: visa-type,
                country: country,
                issue-date: issue-date,
                expiry-date: expiry-date,
                entries-allowed: entries-allowed,
                entries-used: u0
            }
        )
        (ok true)
    )
)

(define-public (register-health-certificate
    (certificate-id (string-ascii 32))
    (holder-id (string-ascii 32))
    (test-type (string-ascii 30))
    (test-date uint)
    (result (string-ascii 10))
    (issuing-facility (string-ascii 50))
    (validity-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set HealthCertificates
            {certificate-id: certificate-id}
            {
                holder-id: holder-id,
                test-type: test-type,
                test-date: test-date,
                result: result,
                issuing-facility: issuing-facility,
                validity-period: validity-period
            }
        )
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (verify-travel-document (document-id (string-ascii 32)))
    (match (map-get? TravelDocuments {document-id: document-id})
        doc (ok doc)
        err-not-found
    )
)

(define-read-only (check-visa-validity (visa-id (string-ascii 32)))
    (match (map-get? VisaRecords {visa-id: visa-id})
        visa (ok visa)
        err-not-found
    )
)

(define-read-only (verify-health-certificate (certificate-id (string-ascii 32)))
    (match (map-get? HealthCertificates {certificate-id: certificate-id})
        cert (ok cert)
        err-not-found
    )
)

;; Private Functions

(define-private (check-document-expiry (expiry-date uint))
    (> expiry-date stacks-block-height)
)

(define-private (update-verification-count)
    (var-set total-verifications (+ (var-get total-verifications) u1))
)

