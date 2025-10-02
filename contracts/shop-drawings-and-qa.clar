;; title: shop-drawings-and-qa
;; version: 1.0.0
;; summary: Smart contract for managing shop drawings, QA processes, weld certifications, and Factory Acceptance Tests (FAT)
;; description: This contract handles the initial phase of prefab module lifecycle management

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INVALID-SCORE (err u104))
(define-constant ERR-INVALID-SIGNATURE (err u105))
(define-constant ERR-DRAWING-LOCKED (err u106))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-DRAWING-VERSION u100)
(define-constant MIN-QA-SCORE u1)
(define-constant MAX-QA-SCORE u100)

;; Status constants
(define-constant STATUS-DRAFT "DRAFT")
(define-constant STATUS-UNDER-REVIEW "UNDER_REVIEW")
(define-constant STATUS-APPROVED "APPROVED")
(define-constant STATUS-REJECTED "REJECTED")
(define-constant STATUS-LOCKED "LOCKED")

;; Data variables
(define-data-var next-drawing-id uint u1)
(define-data-var next-weld-cert-id uint u1)
(define-data-var next-fat-id uint u1)
(define-data-var total-modules uint u0)

;; Shop Drawing data structure
(define-map shop-drawings
  { drawing-id: uint }
  {
    module-id: (string-ascii 64),
    title: (string-ascii 128),
    version: uint,
    status: (string-ascii 32),
    creator: principal,
    reviewer: (optional principal),
    created-at: uint,
    updated-at: uint,
    drawing-hash: (string-ascii 128),
    approval-signature: (optional (string-ascii 256)),
    comments: (string-ascii 512)
  }
)

;; Weld Certification data structure
(define-map weld-certifications
  { cert-id: uint }
  {
    drawing-id: uint,
    welder-id: (string-ascii 32),
    inspector-principal: principal,
    weld-procedure: (string-ascii 128),
    material-grade: (string-ascii 32),
    test-results: (string-ascii 256),
    certification-date: uint,
    expiry-date: uint,
    is-valid: bool,
    certificate-hash: (string-ascii 128)
  }
)

;; Factory Acceptance Test data structure
(define-map factory-acceptance-tests
  { fat-id: uint }
  {
    drawing-id: uint,
    test-engineer: principal,
    test-date: uint,
    test-results: (string-ascii 512),
    overall-score: uint,
    pass-fail: bool,
    witness-signature: (optional (string-ascii 256)),
    test-report-hash: (string-ascii 128),
    remedial-actions: (string-ascii 256)
  }
)

;; QA Milestone tracking
(define-map qa-milestones
  { drawing-id: uint, milestone-type: (string-ascii 32) }
  {
    completed: bool,
    completed-by: (optional principal),
    completed-at: (optional uint),
    verification-hash: (optional (string-ascii 128))
  }
)

;; Module to drawings mapping
(define-map module-drawings
  { module-id: (string-ascii 64) }
  { drawing-ids: (list 50 uint) }
)

;; PUBLIC FUNCTIONS

;; Create new shop drawing
(define-public (create-shop-drawing (module-id (string-ascii 64)) (title (string-ascii 128)) (drawing-hash (string-ascii 128)))
  (let
    (
      (drawing-id (var-get next-drawing-id))
      (current-time block-height)
    )
    (asserts! (> (len module-id) u0) (err u400))
    (asserts! (> (len title) u0) (err u401))
    (asserts! (> (len drawing-hash) u0) (err u402))
    
    ;; Create the drawing record
    (map-set shop-drawings
      { drawing-id: drawing-id }
      {
        module-id: module-id,
        title: title,
        version: u1,
        status: STATUS-DRAFT,
        creator: tx-sender,
        reviewer: none,
        created-at: current-time,
        updated-at: current-time,
        drawing-hash: drawing-hash,
        approval-signature: none,
        comments: ""
      }
    )
    
    ;; Update module drawings mapping
    (match (map-get? module-drawings { module-id: module-id })
      existing-drawings
        (map-set module-drawings
          { module-id: module-id }
          { drawing-ids: (unwrap! (as-max-len? (append (get drawing-ids existing-drawings) drawing-id) u50) (err u500)) }
        )
      ;; First drawing for this module
      (map-set module-drawings
        { module-id: module-id }
        { drawing-ids: (list drawing-id) }
      )
    )
    
    ;; Increment drawing ID counter
    (var-set next-drawing-id (+ drawing-id u1))
    (var-set total-modules (+ (var-get total-modules) u1))
    
    (ok drawing-id)
  )
)

;; Update drawing status with reviewer authority
(define-public (update-drawing-status (drawing-id uint) (new-status (string-ascii 32)) (comments (string-ascii 512)))
  (let
    (
      (drawing-data (unwrap! (map-get? shop-drawings { drawing-id: drawing-id }) ERR-NOT-FOUND))
      (current-time block-height)
    )
    ;; Check if drawing is locked
    (asserts! (not (is-eq (get status drawing-data) STATUS-LOCKED)) ERR-DRAWING-LOCKED)
    
    ;; Validate status transition
    (asserts! (or (is-eq new-status STATUS-UNDER-REVIEW)
                  (is-eq new-status STATUS-APPROVED)
                  (is-eq new-status STATUS-REJECTED)
                  (is-eq new-status STATUS-LOCKED)) ERR-INVALID-STATUS)
    
    ;; Update the drawing
    (map-set shop-drawings
      { drawing-id: drawing-id }
      (merge drawing-data {
        status: new-status,
        reviewer: (some tx-sender),
        updated-at: current-time,
        comments: comments
      })
    )
    
    (ok true)
  )
)

;; Add weld certification
(define-public (add-weld-certification 
  (drawing-id uint)
  (welder-id (string-ascii 32))
  (weld-procedure (string-ascii 128))
  (material-grade (string-ascii 32))
  (test-results (string-ascii 256))
  (expiry-date uint)
  (certificate-hash (string-ascii 128))
)
  (let
    (
      (cert-id (var-get next-weld-cert-id))
      (current-time block-height)
      (drawing-exists (is-some (map-get? shop-drawings { drawing-id: drawing-id })))
    )
    ;; Verify drawing exists
    (asserts! drawing-exists ERR-NOT-FOUND)
    
    ;; Create weld certification record
    (map-set weld-certifications
      { cert-id: cert-id }
      {
        drawing-id: drawing-id,
        welder-id: welder-id,
        inspector-principal: tx-sender,
        weld-procedure: weld-procedure,
        material-grade: material-grade,
        test-results: test-results,
        certification-date: current-time,
        expiry-date: expiry-date,
        is-valid: (> expiry-date current-time),
        certificate-hash: certificate-hash
      }
    )
    
    ;; Update milestone
    (map-set qa-milestones
      { drawing-id: drawing-id, milestone-type: "WELD_CERT" }
      {
        completed: true,
        completed-by: (some tx-sender),
        completed-at: (some current-time),
        verification-hash: (some certificate-hash)
      }
    )
    
    (var-set next-weld-cert-id (+ cert-id u1))
    (ok cert-id)
  )
)

;; Record Factory Acceptance Test
(define-public (record-fat-results
  (drawing-id uint)
  (test-results (string-ascii 512))
  (overall-score uint)
  (test-report-hash (string-ascii 128))
  (remedial-actions (string-ascii 256))
)
  (let
    (
      (fat-id (var-get next-fat-id))
      (current-time block-height)
      (drawing-exists (is-some (map-get? shop-drawings { drawing-id: drawing-id })))
      (pass-status (>= overall-score u70)) ;; 70% pass threshold
    )
    ;; Validations
    (asserts! drawing-exists ERR-NOT-FOUND)
    (asserts! (and (>= overall-score MIN-QA-SCORE) (<= overall-score MAX-QA-SCORE)) ERR-INVALID-SCORE)
    
    ;; Create FAT record
    (map-set factory-acceptance-tests
      { fat-id: fat-id }
      {
        drawing-id: drawing-id,
        test-engineer: tx-sender,
        test-date: current-time,
        test-results: test-results,
        overall-score: overall-score,
        pass-fail: pass-status,
        witness-signature: none,
        test-report-hash: test-report-hash,
        remedial-actions: remedial-actions
      }
    )
    
    ;; Update milestone
    (map-set qa-milestones
      { drawing-id: drawing-id, milestone-type: "FAT" }
      {
        completed: true,
        completed-by: (some tx-sender),
        completed-at: (some current-time),
        verification-hash: (some test-report-hash)
      }
    )
    
    (var-set next-fat-id (+ fat-id u1))
    (ok { fat-id: fat-id, passed: pass-status })
  )
)

;; Add witness signature to FAT
(define-public (add-fat-witness-signature (fat-id uint) (signature (string-ascii 256)))
  (let
    (
      (fat-data (unwrap! (map-get? factory-acceptance-tests { fat-id: fat-id }) ERR-NOT-FOUND))
    )
    (map-set factory-acceptance-tests
      { fat-id: fat-id }
      (merge fat-data { witness-signature: (some signature) })
    )
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get drawing details
(define-read-only (get-drawing-details (drawing-id uint))
  (map-get? shop-drawings { drawing-id: drawing-id })
)

;; Get module drawings
(define-read-only (get-module-drawings (module-id (string-ascii 64)))
  (map-get? module-drawings { module-id: module-id })
)

;; Get weld certification
(define-read-only (get-weld-certification (cert-id uint))
  (map-get? weld-certifications { cert-id: cert-id })
)

;; Get FAT results
(define-read-only (get-fat-results (fat-id uint))
  (map-get? factory-acceptance-tests { fat-id: fat-id })
)

;; Get QA milestone status
(define-read-only (get-qa-milestone (drawing-id uint) (milestone-type (string-ascii 32)))
  (map-get? qa-milestones { drawing-id: drawing-id, milestone-type: milestone-type })
)

;; Check if drawing is approved and ready for next phase
(define-read-only (is-drawing-approved (drawing-id uint))
  (match (map-get? shop-drawings { drawing-id: drawing-id })
    drawing-data (is-eq (get status drawing-data) STATUS-APPROVED)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-drawings: (- (var-get next-drawing-id) u1),
    total-weld-certs: (- (var-get next-weld-cert-id) u1),
    total-fats: (- (var-get next-fat-id) u1),
    total-modules: (var-get total-modules)
  }
)

;; Validate weld certification is current
(define-read-only (is-weld-cert-valid (cert-id uint))
  (match (map-get? weld-certifications { cert-id: cert-id })
    cert-data 
      (let ((current-time block-height))
        (and (get is-valid cert-data) (> (get expiry-date cert-data) current-time))
      )
    false
  )
)

;; PRIVATE FUNCTIONS

;; Validate drawing ownership or reviewer status
(define-private (is-authorized-for-drawing (drawing-id uint) (user principal))
  (match (map-get? shop-drawings { drawing-id: drawing-id })
    drawing-data
      (or 
        (is-eq user (get creator drawing-data))
        (is-eq user CONTRACT-OWNER)
        (match (get reviewer drawing-data)
          reviewer (is-eq user reviewer)
          false
        )
      )
    false
  )
)

