;; title: deconstruction-and-reuse
;; version: 1.0.0
;; summary: Smart contract for managing deconstruction planning, component reusability assessment, and end-of-life cycle tracking
;; description: Handles the final phase of prefab module lifecycle focusing on sustainable deconstruction and circular economy principles

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-ALREADY-EXISTS (err u402))
(define-constant ERR-INVALID-STATUS (err u403))
(define-constant ERR-INVALID-ASSESSMENT (err u404))
(define-constant ERR-PLAN-LOCKED (err u405))
(define-constant ERR-INVALID-CONDITION (err u406))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-REUSABILITY-SCORE u0)
(define-constant MAX-REUSABILITY-SCORE u100)
(define-constant MIN-CONDITION-SCORE u0)
(define-constant MAX-CONDITION-SCORE u10)

;; Status constants
(define-constant STATUS-ACTIVE "ACTIVE")
(define-constant STATUS-PLANNED "PLANNED")
(define-constant STATUS-IN-PROGRESS "IN_PROGRESS")
(define-constant STATUS-COMPLETED "COMPLETED")
(define-constant STATUS-CANCELLED "CANCELLED")

;; Condition assessment constants
(define-constant CONDITION-EXCELLENT "EXCELLENT")
(define-constant CONDITION-GOOD "GOOD")
(define-constant CONDITION-FAIR "FAIR")
(define-constant CONDITION-POOR "POOR")
(define-constant CONDITION-UNUSABLE "UNUSABLE")

;; Reuse outcome constants
(define-constant REUSE-SUCCESS "SUCCESS")
(define-constant REUSE-PARTIAL "PARTIAL")
(define-constant REUSE-FAILED "FAILED")
(define-constant REUSE-PENDING "PENDING")

;; Data variables
(define-data-var next-deconstruction-id uint u1)
(define-data-var next-component-id uint u1)
(define-data-var next-reuse-record-id uint u1)
(define-data-var total-deconstructions uint u0)
(define-data-var total-reuse-success uint u0)

;; Deconstruction plan data structure
(define-map deconstruction-plans
  { deconstruction-id: uint }
  {
    commission-id: uint,
    module-id: (string-ascii 64),
    planner-principal: principal,
    status: (string-ascii 32),
    planned-date: uint,
    actual-start-date: (optional uint),
    actual-completion-date: (optional uint),
    deconstruction-reason: (string-ascii 256),
    methodology: (string-ascii 256),
    safety-requirements: (string-ascii 512),
    environmental-considerations: (string-ascii 256),
    estimated-duration: uint,
    actual-duration: (optional uint),
    contractor: (string-ascii 64),
    supervisor: principal,
    created-at: uint
  }
)

;; Component assessment data structure
(define-map component-assessments
  { component-id: uint }
  {
    deconstruction-id: uint,
    component-type: (string-ascii 64),
    component-description: (string-ascii 128),
    material-type: (string-ascii 32),
    original-specifications: (string-ascii 256),
    current-condition: (string-ascii 32),
    condition-score: uint,
    reusability-score: uint,
    estimated-value: uint,
    assessor-principal: principal,
    assessment-date: uint,
    assessment-notes: (string-ascii 512),
    photos-hash: (string-ascii 128),
    recommended-treatment: (string-ascii 256)
  }
)

;; Reuse records data structure
(define-map reuse-records
  { reuse-id: uint }
  {
    component-id: uint,
    new-project-id: (string-ascii 64),
    reuse-date: uint,
    reuse-application: (string-ascii 128),
    treatment-applied: (string-ascii 256),
    performance-validation: (string-ascii 256),
    reuse-outcome: (string-ascii 32),
    cost-savings: uint,
    environmental-benefit: (string-ascii 256),
    reuse-engineer: principal,
    quality-verified: bool,
    warranty-period: uint,
    documentation-hash: (string-ascii 128)
  }
)

;; Waste tracking for non-reusable components
(define-map waste-tracking
  { component-id: uint }
  {
    disposal-method: (string-ascii 64),
    disposal-facility: (string-ascii 128),
    disposal-date: uint,
    waste-category: (string-ascii 32),
    disposal-cost: uint,
    environmental-impact: (string-ascii 256),
    disposal-certificate: (string-ascii 128),
    responsible-party: principal
  }
)

;; Sustainability metrics
(define-map sustainability-metrics
  { deconstruction-id: uint }
  {
    total-components: uint,
    components-reused: uint,
    components-recycled: uint,
    components-disposed: uint,
    reuse-percentage: uint,
    carbon-footprint-saved: uint,
    cost-savings-achieved: uint,
    materials-diverted-from-landfill: uint,
    circular-economy-score: uint
  }
)

;; Deconstruction milestones
(define-map deconstruction-milestones
  { deconstruction-id: uint, milestone: (string-ascii 64) }
  {
    planned-date: uint,
    actual-date: (optional uint),
    completed: bool,
    completed-by: (optional principal),
    milestone-notes: (string-ascii 256),
    approval-required: bool,
    approved-by: (optional principal)
  }
)

;; PUBLIC FUNCTIONS

;; Create deconstruction plan
(define-public (create-deconstruction-plan
  (commission-id uint)
  (module-id (string-ascii 64))
  (planned-date uint)
  (deconstruction-reason (string-ascii 256))
  (methodology (string-ascii 256))
  (safety-requirements (string-ascii 512))
  (estimated-duration uint)
  (contractor (string-ascii 64))
)
  (let
    (
      (deconstruction-id (var-get next-deconstruction-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Validations
    (asserts! (> commission-id u0) (err u500))
    (asserts! (> (len module-id) u0) (err u501))
    (asserts! (> planned-date current-time) (err u502))
    (asserts! (> estimated-duration u0) (err u503))
    
    ;; Create deconstruction plan
    (map-set deconstruction-plans
      { deconstruction-id: deconstruction-id }
      {
        commission-id: commission-id,
        module-id: module-id,
        planner-principal: tx-sender,
        status: STATUS-PLANNED,
        planned-date: planned-date,
        actual-start-date: none,
        actual-completion-date: none,
        deconstruction-reason: deconstruction-reason,
        methodology: methodology,
        safety-requirements: safety-requirements,
        environmental-considerations: "",
        estimated-duration: estimated-duration,
        actual-duration: none,
        contractor: contractor,
        supervisor: tx-sender,
        created-at: current-time
      }
    )
    
    ;; Initialize sustainability metrics
    (map-set sustainability-metrics
      { deconstruction-id: deconstruction-id }
      {
        total-components: u0,
        components-reused: u0,
        components-recycled: u0,
        components-disposed: u0,
        reuse-percentage: u0,
        carbon-footprint-saved: u0,
        cost-savings-achieved: u0,
        materials-diverted-from-landfill: u0,
        circular-economy-score: u0
      }
    )
    
    (var-set next-deconstruction-id (+ deconstruction-id u1))
    (var-set total-deconstructions (+ (var-get total-deconstructions) u1))
    (ok deconstruction-id)
  )
)

;; Update deconstruction status
(define-public (update-deconstruction-status (deconstruction-id uint) (new-status (string-ascii 32)))
  (let
    (
      (plan-data (unwrap! (map-get? deconstruction-plans { deconstruction-id: deconstruction-id }) ERR-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Authorization check
    (asserts! (or (is-eq tx-sender (get planner-principal plan-data))
                  (is-eq tx-sender (get supervisor plan-data))
                  (is-eq tx-sender CONTRACT-OWNER)) ERR-UNAUTHORIZED)
    
    ;; Validate status
    (asserts! (or (is-eq new-status STATUS-ACTIVE)
                  (is-eq new-status STATUS-PLANNED)
                  (is-eq new-status STATUS-IN-PROGRESS)
                  (is-eq new-status STATUS-COMPLETED)
                  (is-eq new-status STATUS-CANCELLED)) ERR-INVALID-STATUS)
    
    ;; Update plan with status-specific data
    (let
      (
        (updated-plan
          (if (is-eq new-status STATUS-IN-PROGRESS)
            (merge plan-data {
              status: new-status,
              actual-start-date: (some current-time)
            })
            (if (is-eq new-status STATUS-COMPLETED)
              (let
                (
                  (duration (match (get actual-start-date plan-data)
                            start-date (- current-time start-date)
                            u0))
                )
                (merge plan-data {
                  status: new-status,
                  actual-completion-date: (some current-time),
                  actual-duration: (some duration)
                })
              )
              (merge plan-data { status: new-status })
            )
          )
        )
      )
      (map-set deconstruction-plans { deconstruction-id: deconstruction-id } updated-plan)
    )
    
    (ok true)
  )
)

;; Assess component for reusability
(define-public (assess-component-reusability
  (deconstruction-id uint)
  (component-type (string-ascii 64))
  (component-description (string-ascii 128))
  (material-type (string-ascii 32))
  (original-specifications (string-ascii 256))
  (current-condition (string-ascii 32))
  (condition-score uint)
  (reusability-score uint)
  (estimated-value uint)
  (assessment-notes (string-ascii 512))
  (photos-hash (string-ascii 128))
  (recommended-treatment (string-ascii 256))
)
  (let
    (
      (component-id (var-get next-component-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (plan-exists (is-some (map-get? deconstruction-plans { deconstruction-id: deconstruction-id })))
    )
    ;; Validations
    (asserts! plan-exists ERR-NOT-FOUND)
    (asserts! (and (>= condition-score MIN-CONDITION-SCORE) (<= condition-score MAX-CONDITION-SCORE)) ERR-INVALID-CONDITION)
    (asserts! (and (>= reusability-score MIN-REUSABILITY-SCORE) (<= reusability-score MAX-REUSABILITY-SCORE)) ERR-INVALID-ASSESSMENT)
    (asserts! (> (len component-type) u0) (err u500))
    
    ;; Create component assessment
    (map-set component-assessments
      { component-id: component-id }
      {
        deconstruction-id: deconstruction-id,
        component-type: component-type,
        component-description: component-description,
        material-type: material-type,
        original-specifications: original-specifications,
        current-condition: current-condition,
        condition-score: condition-score,
        reusability-score: reusability-score,
        estimated-value: estimated-value,
        assessor-principal: tx-sender,
        assessment-date: current-time,
        assessment-notes: assessment-notes,
        photos-hash: photos-hash,
        recommended-treatment: recommended-treatment
      }
    )
    
    ;; Update sustainability metrics
    (update-sustainability-metrics-for-assessment deconstruction-id component-id)
    
    (var-set next-component-id (+ component-id u1))
    (ok component-id)
  )
)

;; Record successful reuse of component
(define-public (record-component-reuse
  (component-id uint)
  (new-project-id (string-ascii 64))
  (reuse-application (string-ascii 128))
  (treatment-applied (string-ascii 256))
  (performance-validation (string-ascii 256))
  (cost-savings uint)
  (environmental-benefit (string-ascii 256))
  (warranty-period uint)
  (documentation-hash (string-ascii 128))
)
  (let
    (
      (reuse-id (var-get next-reuse-record-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (component-exists (is-some (map-get? component-assessments { component-id: component-id })))
    )
    ;; Validations
    (asserts! component-exists ERR-NOT-FOUND)
    (asserts! (> (len new-project-id) u0) (err u500))
    (asserts! (> (len reuse-application) u0) (err u501))
    
    ;; Create reuse record
    (map-set reuse-records
      { reuse-id: reuse-id }
      {
        component-id: component-id,
        new-project-id: new-project-id,
        reuse-date: current-time,
        reuse-application: reuse-application,
        treatment-applied: treatment-applied,
        performance-validation: performance-validation,
        reuse-outcome: REUSE-SUCCESS,
        cost-savings: cost-savings,
        environmental-benefit: environmental-benefit,
        reuse-engineer: tx-sender,
        quality-verified: true,
        warranty-period: warranty-period,
        documentation-hash: documentation-hash
      }
    )
    
    ;; Update sustainability metrics for reuse
    (match (map-get? component-assessments { component-id: component-id })
      component-data
        (update-sustainability-metrics-for-reuse (get deconstruction-id component-data))
      false
    )
    
    (var-set next-reuse-record-id (+ reuse-id u1))
    (var-set total-reuse-success (+ (var-get total-reuse-success) u1))
    (ok reuse-id)
  )
)

;; Record waste disposal for non-reusable components
(define-public (record-waste-disposal
  (component-id uint)
  (disposal-method (string-ascii 64))
  (disposal-facility (string-ascii 128))
  (waste-category (string-ascii 32))
  (disposal-cost uint)
  (environmental-impact (string-ascii 256))
  (disposal-certificate (string-ascii 128))
)
  (let
    (
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (component-exists (is-some (map-get? component-assessments { component-id: component-id })))
    )
    ;; Validations
    (asserts! component-exists ERR-NOT-FOUND)
    (asserts! (> (len disposal-method) u0) (err u500))
    
    ;; Create waste tracking record
    (map-set waste-tracking
      { component-id: component-id }
      {
        disposal-method: disposal-method,
        disposal-facility: disposal-facility,
        disposal-date: current-time,
        waste-category: waste-category,
        disposal-cost: disposal-cost,
        environmental-impact: environmental-impact,
        disposal-certificate: disposal-certificate,
        responsible-party: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Update deconstruction milestone
(define-public (update-deconstruction-milestone
  (deconstruction-id uint)
  (milestone (string-ascii 64))
  (milestone-notes (string-ascii 256))
  (approval-required bool)
)
  (let
    (
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (plan-exists (is-some (map-get? deconstruction-plans { deconstruction-id: deconstruction-id })))
    )
    ;; Validations
    (asserts! plan-exists ERR-NOT-FOUND)
    
    ;; Update milestone
    (map-set deconstruction-milestones
      { deconstruction-id: deconstruction-id, milestone: milestone }
      {
        planned-date: current-time,
        actual-date: (some current-time),
        completed: true,
        completed-by: (some tx-sender),
        milestone-notes: milestone-notes,
        approval-required: approval-required,
        approved-by: (if approval-required none (some tx-sender))
      }
    )
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get deconstruction plan details
(define-read-only (get-deconstruction-plan (deconstruction-id uint))
  (map-get? deconstruction-plans { deconstruction-id: deconstruction-id })
)

;; Get component assessment
(define-read-only (get-component-assessment (component-id uint))
  (map-get? component-assessments { component-id: component-id })
)

;; Get reuse record
(define-read-only (get-reuse-record (reuse-id uint))
  (map-get? reuse-records { reuse-id: reuse-id })
)

;; Get waste disposal record
(define-read-only (get-waste-disposal (component-id uint))
  (map-get? waste-tracking { component-id: component-id })
)

;; Get sustainability metrics
(define-read-only (get-sustainability-metrics (deconstruction-id uint))
  (map-get? sustainability-metrics { deconstruction-id: deconstruction-id })
)

;; Get deconstruction milestone
(define-read-only (get-deconstruction-milestone (deconstruction-id uint) (milestone (string-ascii 64)))
  (map-get? deconstruction-milestones { deconstruction-id: deconstruction-id, milestone: milestone })
)

;; Check if deconstruction is complete
(define-read-only (is-deconstruction-complete (deconstruction-id uint))
  (match (map-get? deconstruction-plans { deconstruction-id: deconstruction-id })
    plan-data (is-eq (get status plan-data) STATUS-COMPLETED)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-deconstructions: (- (var-get next-deconstruction-id) u1),
    total-components: (- (var-get next-component-id) u1),
    total-reuse-records: (- (var-get next-reuse-record-id) u1),
    total-reuse-success: (var-get total-reuse-success)
  }
)

;; Calculate reuse success rate
(define-read-only (get-reuse-success-rate)
  (let
    (
      (total-components (- (var-get next-component-id) u1))
      (successful-reuses (var-get total-reuse-success))
    )
    (if (> total-components u0)
      (/ (* successful-reuses u100) total-components)
      u0
    )
  )
)

;; PRIVATE FUNCTIONS

;; Update sustainability metrics for component assessment
(define-private (update-sustainability-metrics-for-assessment (deconstruction-id uint) (component-id uint))
  (let
    (
      (current-metrics (default-to {
        total-components: u0,
        components-reused: u0,
        components-recycled: u0,
        components-disposed: u0,
        reuse-percentage: u0,
        carbon-footprint-saved: u0,
        cost-savings-achieved: u0,
        materials-diverted-from-landfill: u0,
        circular-economy-score: u0
      } (map-get? sustainability-metrics { deconstruction-id: deconstruction-id })))
    )
    (map-set sustainability-metrics
      { deconstruction-id: deconstruction-id }
      (merge current-metrics {
        total-components: (+ (get total-components current-metrics) u1)
      })
    )
    true
  )
)

;; Update sustainability metrics for successful reuse
(define-private (update-sustainability-metrics-for-reuse (deconstruction-id uint))
  (let
    (
      (current-metrics (default-to {
        total-components: u0,
        components-reused: u0,
        components-recycled: u0,
        components-disposed: u0,
        reuse-percentage: u0,
        carbon-footprint-saved: u0,
        cost-savings-achieved: u0,
        materials-diverted-from-landfill: u0,
        circular-economy-score: u0
      } (map-get? sustainability-metrics { deconstruction-id: deconstruction-id })))
      (new-reused (+ (get components-reused current-metrics) u1))
      (total (get total-components current-metrics))
    )
    (let
      (
        (new-percentage (if (> total u0) (/ (* new-reused u100) total) u0))
      )
      (map-set sustainability-metrics
        { deconstruction-id: deconstruction-id }
        (merge current-metrics {
          components-reused: new-reused,
          reuse-percentage: new-percentage,
          materials-diverted-from-landfill: (+ (get materials-diverted-from-landfill current-metrics) u1)
        })
      )
    )
    true
  )
)

