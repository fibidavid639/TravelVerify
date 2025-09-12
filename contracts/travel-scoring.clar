;; Travel Credential Scoring System
;; Evaluates traveler credibility based on document history and compliance record

;; Error constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-invalid-score (err u302))
(define-constant err-unauthorized (err u303))
(define-constant err-invalid-criteria (err u304))

;; Scoring criteria weights (out of 1000 for precision)
(define-data-var document-completeness-weight uint u300)
(define-data-var travel-history-weight uint u250)
(define-data-var compliance-record-weight uint u200)
(define-data-var verification-status-weight uint u150)
(define-data-var border-crossing-weight uint u100)

;; Score thresholds for traveler tiers
(define-data-var trusted-traveler-threshold uint u850)
(define-data-var regular-traveler-threshold uint u600)
(define-data-var caution-traveler-threshold uint u400)

;; Traveler credential scores and metadata
(define-map traveler-scores
    { traveler-id: (string-ascii 32) }
    {
        overall-score: uint,
        document-score: uint,
        history-score: uint,
        compliance-score: uint,
        verification-score: uint,
        border-score: uint,
        tier-level: (string-ascii 15),
        last-calculated: uint,
        total-updates: uint
    }
)

;; Score calculation history for auditing
(define-map score-history
    { traveler-id: (string-ascii 32), timestamp: uint }
    {
        previous-score: uint,
        new-score: uint,
        calculation-type: (string-ascii 20),
        calculated-by: principal,
        notes: (string-ascii 100)
    }
)

;; Administrative score adjustments
(define-map score-adjustments
    { traveler-id: (string-ascii 32), adjustment-id: uint }
    {
        adjustment-amount: int,
        reason: (string-ascii 100),
        adjusted-by: principal,
        adjustment-date: uint,
        adjustment-type: (string-ascii 20)
    }
)

;; Calculate comprehensive traveler score
(define-public (calculate-traveler-score 
    (traveler-id (string-ascii 32))
    (document-count uint)
    (travel-history-count uint)
    (compliance-violations uint)
    (verified-documents uint)
    (border-crossings uint))
    (let
        ((doc-score (calculate-document-score document-count))
         (history-score (calculate-history-score travel-history-count))
         (compliance-score (calculate-compliance-score compliance-violations))
         (verification-score (calculate-verification-score verified-documents document-count))
         (border-score (calculate-border-score border-crossings))
         (weighted-total (calculate-weighted-score doc-score history-score compliance-score verification-score border-score))
         (tier (determine-traveler-tier weighted-total))
         (existing-score (map-get? traveler-scores { traveler-id: traveler-id }))
         (previous-score (if (is-some existing-score) (get overall-score (unwrap-panic existing-score)) u0)))
        
        (asserts! (<= document-count u20) err-invalid-score)
        (asserts! (<= travel-history-count u100) err-invalid-score)
        (asserts! (<= compliance-violations u10) err-invalid-score)
        
        ;; Update traveler score
        (map-set traveler-scores
            { traveler-id: traveler-id }
            {
                overall-score: weighted-total,
                document-score: doc-score,
                history-score: history-score,
                compliance-score: compliance-score,
                verification-score: verification-score,
                border-score: border-score,
                tier-level: tier,
                last-calculated: stacks-block-height,
                total-updates: (if (is-some existing-score) 
                                 (+ (get total-updates (unwrap-panic existing-score)) u1) 
                                 u1)
            }
        )
        
        ;; Record score history
        (map-set score-history
            { traveler-id: traveler-id, timestamp: stacks-block-height }
            {
                previous-score: previous-score,
                new-score: weighted-total,
                calculation-type: "automatic",
                calculated-by: tx-sender,
                notes: "Regular score calculation"
            }
        )
        
        (ok {
            score: weighted-total,
            tier: tier,
            improvement: (if (> weighted-total previous-score) 
                           (- weighted-total previous-score) 
                           u0)
        })
    )
)

;; Administrative score adjustment function
(define-public (adjust-traveler-score
    (traveler-id (string-ascii 32))
    (adjustment-amount int)
    (reason (string-ascii 100))
    (adjustment-type (string-ascii 20)))
    (let
        ((existing-score (unwrap! (map-get? traveler-scores { traveler-id: traveler-id }) err-not-found))
         (current-score (get overall-score existing-score))
         (adjustment-id (get total-updates existing-score))
         (new-score (if (< adjustment-amount 0)
                       (if (> (to-uint (- 0 adjustment-amount)) current-score) u0 
                           (- current-score (to-uint (- 0 adjustment-amount))))
                       (+ current-score (to-uint adjustment-amount)))))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-score u1000) err-invalid-score)
        
        ;; Record adjustment
        (map-set score-adjustments
            { traveler-id: traveler-id, adjustment-id: adjustment-id }
            {
                adjustment-amount: adjustment-amount,
                reason: reason,
                adjusted-by: tx-sender,
                adjustment-date: stacks-block-height,
                adjustment-type: adjustment-type
            }
        )
        
        ;; Update traveler score
        (map-set traveler-scores
            { traveler-id: traveler-id }
            (merge existing-score {
                overall-score: new-score,
                tier-level: (determine-traveler-tier new-score),
                last-calculated: stacks-block-height,
                total-updates: (+ (get total-updates existing-score) u1)
            })
        )
        
        ;; Record in history
        (map-set score-history
            { traveler-id: traveler-id, timestamp: stacks-block-height }
            {
                previous-score: current-score,
                new-score: new-score,
                calculation-type: "admin-adjustment",
                calculated-by: tx-sender,
                notes: reason
            }
        )
        
        (ok new-score)
    )
)

;; Update scoring criteria weights
(define-public (update-scoring-weights
    (doc-weight uint)
    (history-weight uint)
    (compliance-weight uint)
    (verification-weight uint)
    (border-weight uint))
    (let
        ((total-weight (+ doc-weight (+ history-weight (+ compliance-weight (+ verification-weight border-weight))))))
        
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-eq total-weight u1000) err-invalid-criteria)
        
        (var-set document-completeness-weight doc-weight)
        (var-set travel-history-weight history-weight)
        (var-set compliance-record-weight compliance-weight)
        (var-set verification-status-weight verification-weight)
        (var-set border-crossing-weight border-weight)
        
        (ok true)
    )
)

;; Private scoring calculation functions
(define-private (calculate-document-score (document-count uint))
    (if (>= document-count u10) u100
        (if (>= document-count u5) u80
            (if (>= document-count u3) u60
                (if (>= document-count u1) u40 u20)))))

(define-private (calculate-history-score (travel-count uint))
    (if (>= travel-count u20) u100
        (if (>= travel-count u10) u80
            (if (>= travel-count u5) u60
                (if (>= travel-count u1) u40 u20)))))

(define-private (calculate-compliance-score (violations uint))
    (if (is-eq violations u0) u100
        (if (<= violations u1) u80
            (if (<= violations u3) u60
                (if (<= violations u5) u40 u20)))))

(define-private (calculate-verification-score (verified-docs uint) (total-docs uint))
    (if (is-eq total-docs u0) u50
        (let ((percentage (/ (* verified-docs u100) total-docs)))
            (if (>= percentage u90) u100
                (if (>= percentage u70) u80
                    (if (>= percentage u50) u60
                        (if (>= percentage u30) u40 u20)))))))

(define-private (calculate-border-score (crossings uint))
    (if (>= crossings u15) u100
        (if (>= crossings u8) u80
            (if (>= crossings u4) u60
                (if (>= crossings u1) u40 u20)))))

(define-private (calculate-weighted-score (doc uint) (hist uint) (comp uint) (verif uint) (border uint))
    (/  (+ (* doc (var-get document-completeness-weight))
           (+ (* hist (var-get travel-history-weight))
              (+ (* comp (var-get compliance-record-weight))
                 (+ (* verif (var-get verification-status-weight))
                    (* border (var-get border-crossing-weight))))))
        u1000))

(define-private (determine-traveler-tier (score uint))
    (if (>= score (var-get trusted-traveler-threshold)) "TRUSTED"
        (if (>= score (var-get regular-traveler-threshold)) "REGULAR"
            (if (>= score (var-get caution-traveler-threshold)) "CAUTION"
                "RESTRICTED"))))

;; Read-only functions
(define-read-only (get-traveler-score (traveler-id (string-ascii 32)))
    (map-get? traveler-scores { traveler-id: traveler-id })
)

(define-read-only (get-score-history (traveler-id (string-ascii 32)) (timestamp uint))
    (map-get? score-history { traveler-id: traveler-id, timestamp: timestamp })
)

(define-read-only (get-score-adjustment (traveler-id (string-ascii 32)) (adjustment-id uint))
    (map-get? score-adjustments { traveler-id: traveler-id, adjustment-id: adjustment-id })
)

(define-read-only (get-scoring-criteria)
    {
        document-weight: (var-get document-completeness-weight),
        history-weight: (var-get travel-history-weight),
        compliance-weight: (var-get compliance-record-weight),
        verification-weight: (var-get verification-status-weight),
        border-weight: (var-get border-crossing-weight),
        trusted-threshold: (var-get trusted-traveler-threshold),
        regular-threshold: (var-get regular-traveler-threshold),
        caution-threshold: (var-get caution-traveler-threshold)
    }
)

(define-read-only (get-tier-benefits (tier (string-ascii 15)))
    (if (is-eq tier "TRUSTED")
        { expedited-processing: true, priority-lanes: true, reduced-checks: true }
        (if (is-eq tier "REGULAR") 
            { expedited-processing: false, priority-lanes: true, reduced-checks: false }
            { expedited-processing: false, priority-lanes: false, reduced-checks: false }))
)
