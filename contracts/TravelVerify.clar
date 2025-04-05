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



(define-map BlacklistedDocuments
    { document-id: (string-ascii 32) }
    { 
        reason: (string-ascii 100),
        blacklist-date: uint
    }
)

(define-public (blacklist-document 
    (document-id (string-ascii 32))
    (reason (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set BlacklistedDocuments
            {document-id: document-id}
            {
                reason: reason,
                blacklist-date: stacks-block-height
            }
        )
        (ok true)
    )
)

(define-map EmergencyContacts
    { user-id: (string-ascii 32) }
    {
        contact-name: (string-ascii 50),
        contact-relation: (string-ascii 20),
        contact-number: (string-ascii 20)
    }
)

(define-public (add-emergency-contact
    (user-id (string-ascii 32))
    (contact-name (string-ascii 50))
    (contact-relation (string-ascii 20))
    (contact-number (string-ascii 20)))
    (begin
        (map-set EmergencyContacts
            {user-id: user-id}
            {
                contact-name: contact-name,
                contact-relation: contact-relation,
                contact-number: contact-number
            }
        )
        (ok true)
    )
)


(define-map VerificationHistory
    { verification-id: (string-ascii 32) }
    {
        document-id: (string-ascii 32),
        verified-by: principal,
        verification-time: uint,
        verification-location: (string-ascii 50)
    }
)

(define-public (record-verification
    (verification-id (string-ascii 32))
    (document-id (string-ascii 32))
    (verification-location (string-ascii 50)))
    (begin
        (map-set VerificationHistory
            {verification-id: verification-id}
            {
                document-id: document-id,
                verified-by: tx-sender,
                verification-time: stacks-block-height,
                verification-location: verification-location
            }
        )
        (ok true)
    )
)

(define-map InsurancePolicies
    { policy-id: (string-ascii 32) }
    {
        holder-id: (string-ascii 32),
        coverage-type: (string-ascii 20),
        start-date: uint,
        end-date: uint,
        coverage-amount: uint
    }
)

(define-public (register-insurance-policy
    (policy-id (string-ascii 32))
    (holder-id (string-ascii 32))
    (coverage-type (string-ascii 20))
    (start-date uint)
    (end-date uint)
    (coverage-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set InsurancePolicies
            {policy-id: policy-id}
            {
                holder-id: holder-id,
                coverage-type: coverage-type,
                start-date: start-date,
                end-date: end-date,
                coverage-amount: coverage-amount
            }
        )
        (ok true)
    )
)

(define-map DocumentTranslations
    { 
        document-id: (string-ascii 32),
        language: (string-ascii 10)
    }
    {
        translated-content: (string-ascii 500)
    }
)

(define-public (add-translation
    (document-id (string-ascii 32))
    (language (string-ascii 10))
    (translated-content (string-ascii 500)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set DocumentTranslations
            {
                document-id: document-id,
                language: language
            }
            {
                translated-content: translated-content
            }
        )
        (ok true)
    )
)


(define-map RenewalReminders
    { document-id: (string-ascii 32) }
    {
        reminder-date: uint,
        reminder-sent: bool,
        reminder-type: (string-ascii 20)
    }
)

(define-public (set-renewal-reminder
    (document-id (string-ascii 32))
    (reminder-date uint)
    (reminder-type (string-ascii 20)))
    (begin
        (map-set RenewalReminders
            {document-id: document-id}
            {
                reminder-date: reminder-date,
                reminder-sent: false,
                reminder-type: reminder-type
            }
        )
        (ok true)
    )
)

(define-map TravelRestrictions
    { country: (string-ascii 30) }
    {
        restriction-level: uint,
        requirements: (string-ascii 200),
        last-updated: uint
    }
)

(define-public (update-travel-restrictions
    (country (string-ascii 30))
    (restriction-level uint)
    (requirements (string-ascii 200)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set TravelRestrictions
            {country: country}
            {
                restriction-level: restriction-level,
                requirements: requirements,
                last-updated: stacks-block-height
            }
        )
        (ok true)
    )
)

(define-map VerifierRatings
    { verifier: principal }
    {
        total-ratings: uint,
        average-score: uint,
        review-count: uint
    }
)

(define-public (submit-verification-rating
    (verifier principal)
    (rating uint))
    (begin
        (asserts! (<= rating u5) (err u105))
        (match (map-get? VerifierRatings {verifier: verifier})
            existing-rating (map-set VerifierRatings
                {verifier: verifier}
                {
                    total-ratings: (+ (get total-ratings existing-rating) rating),
                    average-score: (/ (+ (get total-ratings existing-rating) rating) 
                                    (+ (get review-count existing-rating) u1)),
                    review-count: (+ (get review-count existing-rating) u1)
                }
            )
            (map-set VerifierRatings
                {verifier: verifier}
                {
                    total-ratings: rating,
                    average-score: rating,
                    review-count: u1
                }
            )
        )
        (ok true)
    )
)