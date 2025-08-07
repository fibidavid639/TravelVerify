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


(define-map DelegatedVerifiers
    { verifier: principal }
    {
        delegation-date: uint,
        access-level: uint,
        is-active: bool
    }
)

(define-constant LEVEL-STANDARD u1)
(define-constant LEVEL-ADVANCED u2)
(define-constant LEVEL-ADMIN u3)

(define-public (delegate-verifier 
    (verifier principal)
    (access-level uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (or (is-eq access-level LEVEL-STANDARD) 
                     (is-eq access-level LEVEL-ADVANCED)
                     (is-eq access-level LEVEL-ADMIN)) 
                 (err u106))
        (map-set DelegatedVerifiers
            {verifier: verifier}
            {
                delegation-date: stacks-block-height,
                access-level: access-level,
                is-active: true
            }
        )
        (ok true)
    )
)

(define-public (revoke-verifier (verifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set DelegatedVerifiers
            {verifier: verifier}
            {
                delegation-date: (get delegation-date (unwrap! (map-get? DelegatedVerifiers {verifier: verifier}) err-not-found)),
                access-level: (get access-level (unwrap! (map-get? DelegatedVerifiers {verifier: verifier}) err-not-found)),
                is-active: false
            }
        )
        (ok true)
    )
)


(define-map DocumentBundles
    { bundle-id: (string-ascii 32) }
    {
        primary-document: (string-ascii 32),
        related-documents: (list 5 (string-ascii 32)),
        creation-date: uint,
        last-verified: uint,
        bundle-status: (string-ascii 10)
    }
)

(define-public (create-document-bundle
    (bundle-id (string-ascii 32))
    (primary-document (string-ascii 32))
    (related-documents (list 5 (string-ascii 32))))
    (begin
        (asserts! (is-none (map-get? DocumentBundles {bundle-id: bundle-id})) err-already-exists)
        (asserts! (is-some (map-get? TravelDocuments {document-id: primary-document})) err-not-found)
        (map-set DocumentBundles
            {bundle-id: bundle-id}
            {
                primary-document: primary-document,
                related-documents: related-documents,
                creation-date: stacks-block-height,
                last-verified: u0,
                bundle-status: "ACTIVE"
            }
        )
        (ok true)
    )
)

(define-read-only (get-bundle-details (bundle-id (string-ascii 32)))
    (match (map-get? DocumentBundles {bundle-id: bundle-id})
        bundle (ok bundle)
        err-not-found
    )
)


(define-public (update-bundle-status
    (bundle-id (string-ascii 32))
    (new-status (string-ascii 10)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set DocumentBundles
            {bundle-id: bundle-id}
            {
                primary-document: (get primary-document (unwrap! (map-get? DocumentBundles {bundle-id: bundle-id}) err-not-found)),
                related-documents: (get related-documents (unwrap! (map-get? DocumentBundles {bundle-id: bundle-id}) err-not-found)),
                creation-date: (get creation-date (unwrap! (map-get? DocumentBundles {bundle-id: bundle-id}) err-not-found)),
                last-verified: stacks-block-height,
                bundle-status: new-status
            }
        )
        (ok true)
    )
)

(define-map ExpiryMonitoring
    { document-id: (string-ascii 32) }
    {
        expiry-score: uint,
        warning-level: uint,
        last-checked: uint,
        notification-sent: bool
    }
)

(define-map ExpiryNotifications
    { notification-id: (string-ascii 32) }
    {
        document-id: (string-ascii 32),
        holder-id: (string-ascii 32),
        notification-type: (string-ascii 20),
        created-date: uint,
        is-acknowledged: bool
    }
)

(define-data-var expiry-warning-threshold uint u30)
(define-data-var expiry-critical-threshold uint u7)
(define-data-var total-notifications uint u0)

(define-constant WARNING-LEVEL-SAFE u0)
(define-constant WARNING-LEVEL-CAUTION u1)
(define-constant WARNING-LEVEL-WARNING u2)
(define-constant WARNING-LEVEL-CRITICAL u3)

(define-public (calculate-expiry-score (document-id (string-ascii 32)))
    (let (
        (document-data (unwrap! (map-get? TravelDocuments {document-id: document-id}) err-not-found))
        (expiry-date (get expiry-date document-data))
        (current-block stacks-block-height)
        (days-until-expiry (if (> expiry-date current-block) (- expiry-date current-block) u0))
        (warning-level (get-warning-level days-until-expiry))
    )
    (map-set ExpiryMonitoring
        {document-id: document-id}
        {
            expiry-score: days-until-expiry,
            warning-level: warning-level,
            last-checked: current-block,
            notification-sent: false
        }
    )
    (ok days-until-expiry)
    )
)

(define-private (get-warning-level (days-remaining uint))
    (if (<= days-remaining (var-get expiry-critical-threshold))
        WARNING-LEVEL-CRITICAL
        (if (<= days-remaining (var-get expiry-warning-threshold))
            WARNING-LEVEL-WARNING
            (if (<= days-remaining u60)
                WARNING-LEVEL-CAUTION
                WARNING-LEVEL-SAFE
            )
        )
    )
)

(define-public (create-expiry-notification 
    (notification-id (string-ascii 32))
    (document-id (string-ascii 32))
    (holder-id (string-ascii 32))
    (notification-type (string-ascii 20)))
    (begin
        (asserts! (is-some (map-get? TravelDocuments {document-id: document-id})) err-not-found)
        (map-set ExpiryNotifications
            {notification-id: notification-id}
            {
                document-id: document-id,
                holder-id: holder-id,
                notification-type: notification-type,
                created-date: stacks-block-height,
                is-acknowledged: false
            }
        )
        (var-set total-notifications (+ (var-get total-notifications) u1))
        (ok true)
    )
)

(define-public (acknowledge-notification (notification-id (string-ascii 32)))
    (let (
        (notification-data (unwrap! (map-get? ExpiryNotifications {notification-id: notification-id}) err-not-found))
    )
    (map-set ExpiryNotifications
        {notification-id: notification-id}
        {
            document-id: (get document-id notification-data),
            holder-id: (get holder-id notification-data),
            notification-type: (get notification-type notification-data),
            created-date: (get created-date notification-data),
            is-acknowledged: true
        }
    )
    (ok true)
    )
)

(define-public (batch-check-expiry (document-ids (list 10 (string-ascii 32))))
    (let (
        (results (map calculate-expiry-score-internal document-ids))
    )
    (ok results)
    )
)

(define-private (calculate-expiry-score-internal (document-id (string-ascii 32)))
    (match (map-get? TravelDocuments {document-id: document-id})
        document-data 
        (let (
            (expiry-date (get expiry-date document-data))
            (current-block stacks-block-height)
            (days-until-expiry (if (> expiry-date current-block) (- expiry-date current-block) u0))
            (warning-level (get-warning-level days-until-expiry))
        )
        (map-set ExpiryMonitoring
            {document-id: document-id}
            {
                expiry-score: days-until-expiry,
                warning-level: warning-level,
                last-checked: current-block,
                notification-sent: false
            }
        )
        {document-id: document-id, expiry-score: days-until-expiry, warning-level: warning-level}
        )
        {document-id: document-id, expiry-score: u0, warning-level: u999}
    )
)

(define-public (update-expiry-thresholds (warning-threshold uint) (critical-threshold uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> warning-threshold critical-threshold) (err u107))
        (var-set expiry-warning-threshold warning-threshold)
        (var-set expiry-critical-threshold critical-threshold)
        (ok true)
    )
)

(define-read-only (get-expiry-status (document-id (string-ascii 32)))
    (match (map-get? ExpiryMonitoring {document-id: document-id})
        monitoring-data (ok monitoring-data)
        err-not-found
    )
)

(define-read-only (get-notification-details (notification-id (string-ascii 32)))
    (match (map-get? ExpiryNotifications {notification-id: notification-id})
        notification-data (ok notification-data)
        err-not-found
    )
)

(define-read-only (get-expiry-thresholds)
    (ok {
        warning-threshold: (var-get expiry-warning-threshold),
        critical-threshold: (var-get expiry-critical-threshold),
        total-notifications: (var-get total-notifications)
    })
)

(define-public (mark-notification-sent (document-id (string-ascii 32)))
    (let (
        (monitoring-data (unwrap! (map-get? ExpiryMonitoring {document-id: document-id}) err-not-found))
    )
    (map-set ExpiryMonitoring
        {document-id: document-id}
        {
            expiry-score: (get expiry-score monitoring-data),
            warning-level: (get warning-level monitoring-data),
            last-checked: (get last-checked monitoring-data),
            notification-sent: true
        }
    )
    (ok true)
    )
)

;; Travel Route Verification and Border Control Integration
;; Manages complete travel routes, border crossings, and multi-country compliance

(define-map TravelRoutes
    { route-id: (string-ascii 32) }
    {
        traveler-id: (string-ascii 32),
        route-name: (string-ascii 50),
        departure-country: (string-ascii 30),
        destination-country: (string-ascii 30),
        transit-countries: (list 8 (string-ascii 30)),
        planned-departure: uint,
        planned-return: uint,
        route-status: (string-ascii 15),
        compliance-verified: bool,
        created-date: uint
    }
)

(define-map BorderCrossings
    { crossing-id: (string-ascii 32) }
    {
        route-id: (string-ascii 32),
        traveler-id: (string-ascii 32),
        country-code: (string-ascii 30),
        crossing-type: (string-ascii 10), ;; "ENTRY" or "EXIT"
        crossing-time: uint,
        border-post: (string-ascii 50),
        document-used: (string-ascii 32),
        verification-status: (string-ascii 15),
        automated-check: bool
    }
)

(define-map TransitRequirements
    { 
        origin-country: (string-ascii 30),
        transit-country: (string-ascii 30),
        destination-country: (string-ascii 30)
    }
    {
        requires-transit-visa: bool,
        max-transit-hours: uint,
        special-requirements: (string-ascii 100),
        last-updated: uint
    }
)

(define-map RouteCompliance
    { route-id: (string-ascii 32) }
    {
        total-requirements: uint,
        met-requirements: uint,
        compliance-percentage: uint,
        missing-documents: (list 5 (string-ascii 50)),
        risk-level: (string-ascii 10),
        last-checked: uint
    }
)

(define-map TravelAlerts
    { alert-id: (string-ascii 32) }
    {
        route-id: (string-ascii 32),
        alert-type: (string-ascii 20),
        severity: (string-ascii 10), ;; "LOW", "MEDIUM", "HIGH"
        description: (string-ascii 150),
        issued-date: uint,
        expires-date: uint,
        acknowledged: bool
    }
)

;; Data variables for route management
(define-data-var total-routes uint u0)
(define-data-var total-border-crossings uint u0)
(define-data-var route-compliance-threshold uint u85)

;; Error constants for route verification
(define-constant err-route-not-found (err u201))
(define-constant err-invalid-route (err u202))
(define-constant err-compliance-failed (err u203))
(define-constant err-border-violation (err u204))

;; Create a new travel route with full itinerary
(define-public (create-travel-route
    (route-id (string-ascii 32))
    (traveler-id (string-ascii 32))
    (route-name (string-ascii 50))
    (departure-country (string-ascii 30))
    (destination-country (string-ascii 30))
    (transit-countries (list 8 (string-ascii 30)))
    (planned-departure uint)
    (planned-return uint))
    (begin
        (asserts! (is-none (map-get? TravelRoutes {route-id: route-id})) err-already-exists)
        (asserts! (> planned-return planned-departure) err-invalid-route)
        (map-set TravelRoutes
            {route-id: route-id}
            {
                traveler-id: traveler-id,
                route-name: route-name,
                departure-country: departure-country,
                destination-country: destination-country,
                transit-countries: transit-countries,
                planned-departure: planned-departure,
                planned-return: planned-return,
                route-status: "PLANNED",
                compliance-verified: false,
                created-date: stacks-block-height
            }
        )
        (var-set total-routes (+ (var-get total-routes) u1))
        (ok true)
    )
)

;; Record border crossing events with full verification
(define-public (record-border-crossing
    (crossing-id (string-ascii 32))
    (route-id (string-ascii 32))
    (traveler-id (string-ascii 32))
    (country-code (string-ascii 30))
    (crossing-type (string-ascii 10))
    (border-post (string-ascii 50))
    (document-used (string-ascii 32)))
    (let (
        (route-exists (is-some (map-get? TravelRoutes {route-id: route-id})))
        (document-valid (is-some (map-get? TravelDocuments {document-id: document-used})))
    )
    (asserts! route-exists err-route-not-found)
    (asserts! document-valid err-not-found)
    (map-set BorderCrossings
        {crossing-id: crossing-id}
        {
            route-id: route-id,
            traveler-id: traveler-id,
            country-code: country-code,
            crossing-type: crossing-type,
            crossing-time: stacks-block-height,
            border-post: border-post,
            document-used: document-used,
            verification-status: "VERIFIED",
            automated-check: true
        }
    )
    (var-set total-border-crossings (+ (var-get total-border-crossings) u1))
    (ok true)
    )
)

;; Set transit requirements between countries
(define-public (set-transit-requirements
    (origin-country (string-ascii 30))
    (transit-country (string-ascii 30))
    (destination-country (string-ascii 30))
    (requires-transit-visa bool)
    (max-transit-hours uint)
    (special-requirements (string-ascii 100)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set TransitRequirements
            {
                origin-country: origin-country,
                transit-country: transit-country,
                destination-country: destination-country
            }
            {
                requires-transit-visa: requires-transit-visa,
                max-transit-hours: max-transit-hours,
                special-requirements: special-requirements,
                last-updated: stacks-block-height
            }
        )
        (ok true)
    )
)

;; Comprehensive route compliance verification
(define-public (verify-route-compliance (route-id (string-ascii 32)))
    (let (
        (route-data (unwrap! (map-get? TravelRoutes {route-id: route-id}) err-route-not-found))
        (traveler-id (get traveler-id route-data))
        (destination (get destination-country route-data))
        (transit-list (get transit-countries route-data))
        (compliance-score (calculate-route-compliance-score route-data transit-list))
        (risk-assessment (assess-route-risk route-data transit-list))
        (missing-docs (get-missing-route-documents route-data))
    )
    (map-set RouteCompliance
        {route-id: route-id}
        {
            total-requirements: u10,
            met-requirements: compliance-score,
            compliance-percentage: (* compliance-score u10),
            missing-documents: missing-docs,
            risk-level: risk-assessment,
            last-checked: stacks-block-height
        }
    )
    (map-set TravelRoutes
        {route-id: route-id}
        {
            traveler-id: (get traveler-id route-data),
            route-name: (get route-name route-data),
            departure-country: (get departure-country route-data),
            destination-country: (get destination-country route-data),
            transit-countries: (get transit-countries route-data),
            planned-departure: (get planned-departure route-data),
            planned-return: (get planned-return route-data),
            route-status: (if (>= (* compliance-score u10) (var-get route-compliance-threshold)) "APPROVED" "PENDING"),
            compliance-verified: true,
            created-date: (get created-date route-data)
        }
    )
    (ok {
        compliance-percentage: (* compliance-score u10),
        risk-level: risk-assessment,
        status: (if (>= (* compliance-score u10) (var-get route-compliance-threshold)) "APPROVED" "PENDING")
    })
    )
)

;; Create travel alerts for route issues
(define-public (create-travel-alert
    (alert-id (string-ascii 32))
    (route-id (string-ascii 32))
    (alert-type (string-ascii 20))
    (severity (string-ascii 10))
    (description (string-ascii 150))
    (expires-blocks uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? TravelRoutes {route-id: route-id})) err-route-not-found)
        (map-set TravelAlerts
            {alert-id: alert-id}
            {
                route-id: route-id,
                alert-type: alert-type,
                severity: severity,
                description: description,
                issued-date: stacks-block-height,
                expires-date: (+ stacks-block-height expires-blocks),
                acknowledged: false
            }
        )
        (ok true)
    )
)

;; Private helper functions for route compliance
(define-private (calculate-route-compliance-score (route-data {traveler-id: (string-ascii 32), route-name: (string-ascii 50), departure-country: (string-ascii 30), destination-country: (string-ascii 30), transit-countries: (list 8 (string-ascii 30)), planned-departure: uint, planned-return: uint, route-status: (string-ascii 15), compliance-verified: bool, created-date: uint}) (transit-list (list 8 (string-ascii 30))))
    (let (
        (base-score u6)
        (destination-valid u2)
        (transit-valid (check-transit-compliance transit-list))
    )
    (+ base-score destination-valid transit-valid)
    )
)

(define-private (check-transit-compliance (transit-countries (list 8 (string-ascii 30))))
    (if (is-eq (len transit-countries) u0)
        u2
        u1
    )
)

(define-private (assess-route-risk (route-data {traveler-id: (string-ascii 32), route-name: (string-ascii 50), departure-country: (string-ascii 30), destination-country: (string-ascii 30), transit-countries: (list 8 (string-ascii 30)), planned-departure: uint, planned-return: uint, route-status: (string-ascii 15), compliance-verified: bool, created-date: uint}) (transit-list (list 8 (string-ascii 30))))
    (let (
        (transit-count (len transit-list))
        (destination-restrictions (map-get? TravelRestrictions {country: (get destination-country route-data)}))
    )
    (if (> transit-count u3)
        "HIGH"
        (match destination-restrictions
            restr (if (> (get restriction-level restr) u2) "MEDIUM" "LOW")
            "LOW"
        )
    )
    )
)

(define-private (get-missing-route-documents (route-data {traveler-id: (string-ascii 32), route-name: (string-ascii 50), departure-country: (string-ascii 30), destination-country: (string-ascii 30), transit-countries: (list 8 (string-ascii 30)), planned-departure: uint, planned-return: uint, route-status: (string-ascii 15), compliance-verified: bool, created-date: uint}))
    (list "Transit Visa Check Required")
)

;; Read-only functions for route information
(define-read-only (get-travel-route (route-id (string-ascii 32)))
    (match (map-get? TravelRoutes {route-id: route-id})
        route-data (ok route-data)
        err-route-not-found
    )
)

(define-read-only (get-border-crossing (crossing-id (string-ascii 32)))
    (match (map-get? BorderCrossings {crossing-id: crossing-id})
        crossing-data (ok crossing-data)
        err-not-found
    )
)

(define-read-only (get-route-compliance (route-id (string-ascii 32)))
    (match (map-get? RouteCompliance {route-id: route-id})
        compliance-data (ok compliance-data)
        err-route-not-found
    )
)

(define-read-only (get-transit-requirements (origin (string-ascii 30)) (transit (string-ascii 30)) (destination (string-ascii 30)))
    (match (map-get? TransitRequirements {origin-country: origin, transit-country: transit, destination-country: destination})
        requirements (ok requirements)
        err-not-found
    )
)

(define-read-only (get-travel-alert (alert-id (string-ascii 32)))
    (match (map-get? TravelAlerts {alert-id: alert-id})
        alert-data (ok alert-data)
        err-not-found
    )
)

(define-read-only (get-route-statistics)
    (ok {
        total-routes: (var-get total-routes),
        total-border-crossings: (var-get total-border-crossings),
        compliance-threshold: (var-get route-compliance-threshold)
    })
)


