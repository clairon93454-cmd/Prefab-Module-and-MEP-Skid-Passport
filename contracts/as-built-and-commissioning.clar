;; title: as-built-and-commissioning
;; version: 1.0.0
;; summary: Smart contract for as-built documentation, I/O verification, SAT/IBMS integration, and commissioning processes
;; description: Manages the commissioning phase of prefab modules including system integration and performance validation

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-ALREADY-EXISTS (err u302))
(define-constant ERR-INVALID-STATUS (err u303))
(define-constant ERR-INVALID-SCORE (err u304))
(define-constant ERR-COMMISSIONING-LOCKED (err u305))
(define-constant ERR-PREREQUISITE-NOT-MET (err u306))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-SAT-SCORE u60)
(define-constant MAX-SAT-SCORE u100)
(define-constant MIN-IO-TESTS u1)
(define-constant MAX-IO-TESTS u1000)

;; Status constants
(define-constant STATUS-PLANNING "PLANNING")
(define-constant STATUS-IN-PROGRESS "IN_PROGRESS")
(define-constant STATUS-TESTING "TESTING")
(define-constant STATUS-COMMISSIONED "COMMISSIONED")
(define-constant STATUS-FAILED "FAILED")
(define-constant STATUS-ON-HOLD "ON_HOLD")

;; Test result constants
(define-constant TEST-PASSED "PASSED")
(define-constant TEST-FAILED "FAILED")
(define-constant TEST-PENDING "PENDING")
(define-constant TEST-CONDITIONAL "CONDITIONAL")

;; Data variables
(define-data-var next-commission-id uint u1)
(define-data-var next-io-test-id uint u1)
(define-data-var next-sat-id uint u1)
(define-data-var next-integration-id uint u1)
(define-data-var total-commissions uint u0)

;; Commissioning record data structure
(define-map commissioning-records
  { commission-id: uint }
  {
    transport-id: uint,
    module-id: (string-ascii 64),
    commissioning-engineer: principal,
    status: (string-ascii 32),
    start-date: uint,
    target-completion: uint,
    actual-completion: (optional uint),
    as-built-model-hash: (string-ascii 128),
    commissioning-plan: (string-ascii 256),
    overall-progress: uint,
    created-by: principal,
    created-at: uint
  }
)

;; I/O Testing records
(define-map io-tests
  { test-id: uint }
  {
    commission-id: uint,
    io-point-id: (string-ascii 64),
    test-type: (string-ascii 32),
    expected-value: (string-ascii 128),
    actual-value: (string-ascii 128),
    test-result: (string-ascii 32),
    test-date: uint,
    tested-by: principal,
    calibration-required: bool,
    calibration-completed: bool,
    notes: (string-ascii 256)
  }
)

;; Site Acceptance Test (SAT) records
(define-map site-acceptance-tests
  { sat-id: uint }
  {
    commission-id: uint,
    test-procedure: (string-ascii 128),
    test-engineer: principal,
    witness-engineer: (optional principal),
    test-date: uint,
    test-duration: uint,
    performance-score: uint,
    functionality-score: uint,
    safety-score: uint,
    overall-score: uint,
    test-result: (string-ascii 32),
    deficiencies: (string-ascii 512),
    remedial-work: (string-ascii 256),
    test-report-hash: (string-ascii 128),
    client-acceptance: bool
  }
)

;; IBMS Integration records
(define-map ibms-integrations
  { integration-id: uint }
  {
    commission-id: uint,
    ibms-system: (string-ascii 64),
    integration-type: (string-ascii 32),
    communication-protocol: (string-ascii 32),
    data-points-count: uint,
    integration-status: (string-ascii 32),
    go-live-date: (optional uint),
    integration-engineer: principal,
    system-ip: (string-ascii 32),
    configuration-hash: (string-ascii 128),
    testing-completed: bool,
    performance-validated: bool
  }
)

;; Performance metrics tracking
(define-map performance-metrics
  { commission-id: uint, metric-type: (string-ascii 64) }
  {
    baseline-value: (string-ascii 64),
    current-value: (string-ascii 64),
    target-value: (string-ascii 64),
    measurement-unit: (string-ascii 32),
    last-updated: uint,
    trend-direction: (string-ascii 16),
    within-spec: bool
  }
)

;; Commissioning milestones
(define-map commissioning-milestones
  { commission-id: uint, milestone: (string-ascii 64) }
  {
    planned-date: uint,
    actual-date: (optional uint),
    completed: bool,
    completed-by: (optional principal),
    dependencies: (string-ascii 256),
    approval-required: bool,
    approved-by: (optional principal)
  }
)

;; PUBLIC FUNCTIONS

;; Create new commissioning record
(define-public (create-commissioning-record
  (transport-id uint)
  (module-id (string-ascii 64))
  (target-completion uint)
  (as-built-model-hash (string-ascii 128))
  (commissioning-plan (string-ascii 256))
)
  (let
    (
      (commission-id (var-get next-commission-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Validations
    (asserts! (> transport-id u0) (err u400))
    (asserts! (> (len module-id) u0) (err u401))
    (asserts! (> target-completion current-time) (err u402))
    
    ;; Create commissioning record
    (map-set commissioning-records
      { commission-id: commission-id }
      {
        transport-id: transport-id,
        module-id: module-id,
        commissioning-engineer: tx-sender,
        status: STATUS-PLANNING,
        start-date: current-time,
        target-completion: target-completion,
        actual-completion: none,
        as-built-model-hash: as-built-model-hash,
        commissioning-plan: commissioning-plan,
        overall-progress: u0,
        created-by: tx-sender,
        created-at: current-time
      }
    )
    
    (var-set next-commission-id (+ commission-id u1))
    (var-set total-commissions (+ (var-get total-commissions) u1))
    (ok commission-id)
  )
)

;; Update commissioning status
(define-public (update-commissioning-status (commission-id uint) (new-status (string-ascii 32)) (progress uint))
  (let
    (
      (commission-data (unwrap! (map-get? commissioning-records { commission-id: commission-id }) ERR-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Authorization check
    (asserts! (or (is-eq tx-sender (get commissioning-engineer commission-data))
                  (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    
    ;; Validate status
    (asserts! (or (is-eq new-status STATUS-PLANNING)
                  (is-eq new-status STATUS-IN-PROGRESS)
                  (is-eq new-status STATUS-TESTING)
                  (is-eq new-status STATUS-COMMISSIONED)
                  (is-eq new-status STATUS-FAILED)
                  (is-eq new-status STATUS-ON-HOLD)) ERR-INVALID-STATUS)
    
    ;; Validate progress
    (asserts! (<= progress u100) ERR-INVALID-SCORE)
    
    ;; Update record
    (let
      (
        (updated-record
          (if (is-eq new-status STATUS-COMMISSIONED)
            (merge commission-data {
              status: new-status,
              overall-progress: u100,
              actual-completion: (some current-time)
            })
            (merge commission-data {
              status: new-status,
              overall-progress: progress
            })
          )
        )
      )
      (map-set commissioning-records { commission-id: commission-id } updated-record)
    )
    
    (ok true)
  )
)

;; Record I/O test results
(define-public (record-io-test
  (commission-id uint)
  (io-point-id (string-ascii 64))
  (test-type (string-ascii 32))
  (expected-value (string-ascii 128))
  (actual-value (string-ascii 128))
  (calibration-required bool)
  (notes (string-ascii 256))
)
  (let
    (
      (test-id (var-get next-io-test-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (commission-exists (is-some (map-get? commissioning-records { commission-id: commission-id })))
      (test-result (if (is-eq expected-value actual-value) TEST-PASSED TEST-FAILED))
    )
    ;; Validations
    (asserts! commission-exists ERR-NOT-FOUND)
    (asserts! (> (len io-point-id) u0) (err u400))
    
    ;; Create I/O test record
    (map-set io-tests
      { test-id: test-id }
      {
        commission-id: commission-id,
        io-point-id: io-point-id,
        test-type: test-type,
        expected-value: expected-value,
        actual-value: actual-value,
        test-result: test-result,
        test-date: current-time,
        tested-by: tx-sender,
        calibration-required: calibration-required,
        calibration-completed: false,
        notes: notes
      }
    )
    
    (var-set next-io-test-id (+ test-id u1))
    (ok { test-id: test-id, result: test-result })
  )
)

;; Record Site Acceptance Test
(define-public (record-sat-results
  (commission-id uint)
  (test-procedure (string-ascii 128))
  (test-duration uint)
  (performance-score uint)
  (functionality-score uint)
  (safety-score uint)
  (deficiencies (string-ascii 512))
  (test-report-hash (string-ascii 128))
)
  (let
    (
      (sat-id (var-get next-sat-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (commission-exists (is-some (map-get? commissioning-records { commission-id: commission-id })))
      (overall-score (/ (+ performance-score functionality-score safety-score) u3))
      (test-result (if (>= overall-score MIN-SAT-SCORE) TEST-PASSED TEST-FAILED))
      (client-acceptance (>= overall-score u80))
    )
    ;; Validations
    (asserts! commission-exists ERR-NOT-FOUND)
    (asserts! (and (<= performance-score MAX-SAT-SCORE) (<= functionality-score MAX-SAT-SCORE) (<= safety-score MAX-SAT-SCORE)) ERR-INVALID-SCORE)
    
    ;; Create SAT record
    (map-set site-acceptance-tests
      { sat-id: sat-id }
      {
        commission-id: commission-id,
        test-procedure: test-procedure,
        test-engineer: tx-sender,
        witness-engineer: none,
        test-date: current-time,
        test-duration: test-duration,
        performance-score: performance-score,
        functionality-score: functionality-score,
        safety-score: safety-score,
        overall-score: overall-score,
        test-result: test-result,
        deficiencies: deficiencies,
        remedial-work: "",
        test-report-hash: test-report-hash,
        client-acceptance: client-acceptance
      }
    )
    
    (var-set next-sat-id (+ sat-id u1))
    (ok { sat-id: sat-id, overall-score: overall-score, passed: (is-eq test-result TEST-PASSED) })
  )
)

;; Record IBMS integration
(define-public (record-ibms-integration
  (commission-id uint)
  (ibms-system (string-ascii 64))
  (integration-type (string-ascii 32))
  (communication-protocol (string-ascii 32))
  (data-points-count uint)
  (system-ip (string-ascii 32))
  (configuration-hash (string-ascii 128))
)
  (let
    (
      (integration-id (var-get next-integration-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (commission-exists (is-some (map-get? commissioning-records { commission-id: commission-id })))
    )
    ;; Validations
    (asserts! commission-exists ERR-NOT-FOUND)
    (asserts! (> (len ibms-system) u0) (err u400))
    (asserts! (> data-points-count u0) (err u401))
    
    ;; Create integration record
    (map-set ibms-integrations
      { integration-id: integration-id }
      {
        commission-id: commission-id,
        ibms-system: ibms-system,
        integration-type: integration-type,
        communication-protocol: communication-protocol,
        data-points-count: data-points-count,
        integration-status: STATUS-PLANNING,
        go-live-date: none,
        integration-engineer: tx-sender,
        system-ip: system-ip,
        configuration-hash: configuration-hash,
        testing-completed: false,
        performance-validated: false
      }
    )
    
    (var-set next-integration-id (+ integration-id u1))
    (ok integration-id)
  )
)

;; Update performance metrics
(define-public (update-performance-metric
  (commission-id uint)
  (metric-type (string-ascii 64))
  (current-value (string-ascii 64))
  (target-value (string-ascii 64))
  (measurement-unit (string-ascii 32))
  (within-spec bool)
)
  (let
    (
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (commission-exists (is-some (map-get? commissioning-records { commission-id: commission-id })))
      (existing-metric (map-get? performance-metrics { commission-id: commission-id, metric-type: metric-type }))
    )
    ;; Validations
    (asserts! commission-exists ERR-NOT-FOUND)
    
    ;; Determine trend direction
    (let
      (
        (trend-direction
          (match existing-metric
            existing
              (if (> (len current-value) (len (get current-value existing)))
                "UP"
                (if (< (len current-value) (len (get current-value existing)))
                  "DOWN"
                  "STABLE"
                )
              )
            "NEW"
          )
        )
        (baseline-value
          (match existing-metric
            existing (get baseline-value existing)
            current-value
          )
        )
      )
      ;; Update metric
      (map-set performance-metrics
        { commission-id: commission-id, metric-type: metric-type }
        {
          baseline-value: baseline-value,
          current-value: current-value,
          target-value: target-value,
          measurement-unit: measurement-unit,
          last-updated: current-time,
          trend-direction: trend-direction,
          within-spec: within-spec
        }
      )
    )
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get commissioning record
(define-read-only (get-commissioning-details (commission-id uint))
  (map-get? commissioning-records { commission-id: commission-id })
)

;; Get I/O test results
(define-read-only (get-io-test (test-id uint))
  (map-get? io-tests { test-id: test-id })
)

;; Get SAT results
(define-read-only (get-sat-results (sat-id uint))
  (map-get? site-acceptance-tests { sat-id: sat-id })
)

;; Get IBMS integration details
(define-read-only (get-ibms-integration (integration-id uint))
  (map-get? ibms-integrations { integration-id: integration-id })
)

;; Get performance metric
(define-read-only (get-performance-metric (commission-id uint) (metric-type (string-ascii 64)))
  (map-get? performance-metrics { commission-id: commission-id, metric-type: metric-type })
)

;; Get commissioning milestone
(define-read-only (get-commissioning-milestone (commission-id uint) (milestone (string-ascii 64)))
  (map-get? commissioning-milestones { commission-id: commission-id, milestone: milestone })
)

;; Check if commissioning is complete
(define-read-only (is-commissioning-complete (commission-id uint))
  (match (map-get? commissioning-records { commission-id: commission-id })
    commission-data (is-eq (get status commission-data) STATUS-COMMISSIONED)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-commissions: (- (var-get next-commission-id) u1),
    total-io-tests: (- (var-get next-io-test-id) u1),
    total-sats: (- (var-get next-sat-id) u1),
    total-integrations: (- (var-get next-integration-id) u1)
  }
)

;; PRIVATE FUNCTIONS

;; Validate commissioning prerequisites
(define-private (validate-prerequisites (commission-id uint))
  ;; Check if transport phase is complete
  ;; Check if required approvals are in place
  ;; This would typically call other contracts
  true
)

