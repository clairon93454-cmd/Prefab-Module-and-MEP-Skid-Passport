;; title: transport-and-install-logs
;; version: 1.0.0
;; summary: Smart contract for tracking chain of custody, environmental monitoring, and transport logistics for prefab modules
;; description: Manages transportation phase with shock/tilt indicators, site arrival checks, and installation logs

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-NOT-FOUND (err u201))
(define-constant ERR-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-STATUS (err u203))
(define-constant ERR-INVALID-READING (err u204))
(define-constant ERR-TRANSPORT-LOCKED (err u205))
(define-constant ERR-INVALID-COORDINATES (err u206))

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-SHOCK-THRESHOLD u100)
(define-constant MAX-TILT-THRESHOLD u45)
(define-constant MIN-TEMPERATURE-CELSIUS -50)
(define-constant MAX-TEMPERATURE-CELSIUS 60)

;; Status constants
(define-constant STATUS-PREPARED "PREPARED")
(define-constant STATUS-IN-TRANSIT "IN_TRANSIT")
(define-constant STATUS-DELIVERED "DELIVERED")
(define-constant STATUS-INSTALLED "INSTALLED")
(define-constant STATUS-DAMAGED "DAMAGED")

;; Data variables
(define-data-var next-transport-id uint u1)
(define-data-var next-sensor-reading-id uint u1)
(define-data-var next-custody-log-id uint u1)
(define-data-var total-transports uint u0)

;; Transport Record data structure
(define-map transport-records
  { transport-id: uint }
  {
    module-id: (string-ascii 64),
    drawing-id: uint,
    origin: (string-ascii 128),
    destination: (string-ascii 128),
    transport-company: (string-ascii 64),
    driver-id: (string-ascii 32),
    vehicle-id: (string-ascii 32),
    status: (string-ascii 32),
    departure-time: (optional uint),
    arrival-time: (optional uint),
    estimated-delivery: uint,
    special-handling: (string-ascii 256),
    insurance-value: uint,
    created-by: principal,
    created-at: uint
  }
)

;; Environmental Sensor Readings
(define-map sensor-readings
  { reading-id: uint }
  {
    transport-id: uint,
    sensor-type: (string-ascii 32),
    reading-value: int,
    threshold-exceeded: bool,
    reading-time: uint,
    location-lat: (optional int),
    location-lon: (optional int),
    recorded-by: principal,
    alert-triggered: bool
  }
)

;; Chain of Custody logs
(define-map custody-logs
  { log-id: uint }
  {
    transport-id: uint,
    custody-event: (string-ascii 64),
    from-party: (string-ascii 64),
    to-party: (string-ascii 64),
    handover-time: uint,
    location: (string-ascii 128),
    condition-notes: (string-ascii 256),
    signatures-hash: (string-ascii 128),
    photos-hash: (optional (string-ascii 128)),
    recorded-by: principal
  }
)

;; Site Arrival Inspection
(define-map site-inspections
  { transport-id: uint }
  {
    inspector-principal: principal,
    inspection-time: uint,
    overall-condition: (string-ascii 32),
    damage-assessment: (string-ascii 512),
    acceptance-status: bool,
    rejection-reason: (optional (string-ascii 256)),
    inspection-photos: (string-ascii 128),
    next-actions: (string-ascii 256),
    signed-off-by: (optional principal)
  }
)

;; Installation milestones
(define-map installation-milestones
  { transport-id: uint, milestone: (string-ascii 64) }
  {
    completed: bool,
    completion-time: (optional uint),
    completed-by: (optional principal),
    notes: (string-ascii 256),
    verification-hash: (optional (string-ascii 128))
  }
)

;; Environmental alerts tracking
(define-map environmental-alerts
  { transport-id: uint }
  { 
    shock-alerts: uint,
    tilt-alerts: uint,
    temperature-alerts: uint,
    last-alert-time: (optional uint),
    total-alerts: uint
  }
)

;; PUBLIC FUNCTIONS

;; Create new transport record
(define-public (create-transport-record
  (module-id (string-ascii 64))
  (drawing-id uint)
  (origin (string-ascii 128))
  (destination (string-ascii 128))
  (transport-company (string-ascii 64))
  (driver-id (string-ascii 32))
  (vehicle-id (string-ascii 32))
  (estimated-delivery uint)
  (special-handling (string-ascii 256))
  (insurance-value uint)
)
  (let
    (
      (transport-id (var-get next-transport-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Validations
    (asserts! (> (len module-id) u0) (err u400))
    (asserts! (> drawing-id u0) (err u401))
    (asserts! (> estimated-delivery current-time) (err u402))
    
    ;; Create transport record
    (map-set transport-records
      { transport-id: transport-id }
      {
        module-id: module-id,
        drawing-id: drawing-id,
        origin: origin,
        destination: destination,
        transport-company: transport-company,
        driver-id: driver-id,
        vehicle-id: vehicle-id,
        status: STATUS-PREPARED,
        departure-time: none,
        arrival-time: none,
        estimated-delivery: estimated-delivery,
        special-handling: special-handling,
        insurance-value: insurance-value,
        created-by: tx-sender,
        created-at: current-time
      }
    )
    
    ;; Initialize environmental alerts
    (map-set environmental-alerts
      { transport-id: transport-id }
      {
        shock-alerts: u0,
        tilt-alerts: u0,
        temperature-alerts: u0,
        last-alert-time: none,
        total-alerts: u0
      }
    )
    
    (var-set next-transport-id (+ transport-id u1))
    (var-set total-transports (+ (var-get total-transports) u1))
    (ok transport-id)
  )
)

;; Update transport status
(define-public (update-transport-status (transport-id uint) (new-status (string-ascii 32)))
  (let
    (
      (transport-data (unwrap! (map-get? transport-records { transport-id: transport-id }) ERR-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    ;; Validate status
    (asserts! (or (is-eq new-status STATUS-IN-TRANSIT)
                  (is-eq new-status STATUS-DELIVERED)
                  (is-eq new-status STATUS-INSTALLED)
                  (is-eq new-status STATUS-DAMAGED)) ERR-INVALID-STATUS)
    
    ;; Update record with status-specific data
    (let
      (
        (updated-record
          (if (is-eq new-status STATUS-IN-TRANSIT)
            (merge transport-data { status: new-status, departure-time: (some current-time) })
            (if (is-eq new-status STATUS-DELIVERED)
              (merge transport-data { status: new-status, arrival-time: (some current-time) })
              (merge transport-data { status: new-status })
            )
          )
        )
      )
      (map-set transport-records { transport-id: transport-id } updated-record)
    )
    
    (ok true)
  )
)

;; Record environmental sensor reading
(define-public (record-sensor-reading
  (transport-id uint)
  (sensor-type (string-ascii 32))
  (reading-value int)
  (location-lat (optional int))
  (location-lon (optional int))
)
  (let
    (
      (reading-id (var-get next-sensor-reading-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (transport-exists (is-some (map-get? transport-records { transport-id: transport-id })))
      (threshold-exceeded (check-threshold-exceeded sensor-type reading-value))
    )
    ;; Validations
    (asserts! transport-exists ERR-NOT-FOUND)
    (asserts! (validate-sensor-reading sensor-type reading-value) ERR-INVALID-READING)
    
    ;; Create sensor reading record
    (map-set sensor-readings
      { reading-id: reading-id }
      {
        transport-id: transport-id,
        sensor-type: sensor-type,
        reading-value: reading-value,
        threshold-exceeded: threshold-exceeded,
        reading-time: current-time,
        location-lat: location-lat,
        location-lon: location-lon,
        recorded-by: tx-sender,
        alert-triggered: threshold-exceeded
      }
    )
    
    ;; Update alerts if threshold exceeded
    (if threshold-exceeded
      (update-environmental-alerts transport-id sensor-type)
      true
    )
    
    (var-set next-sensor-reading-id (+ reading-id u1))
    (ok { reading-id: reading-id, alert-triggered: threshold-exceeded })
  )
)

;; Log chain of custody event
(define-public (log-custody-event
  (transport-id uint)
  (custody-event (string-ascii 64))
  (from-party (string-ascii 64))
  (to-party (string-ascii 64))
  (location (string-ascii 128))
  (condition-notes (string-ascii 256))
  (signatures-hash (string-ascii 128))
  (photos-hash (optional (string-ascii 128)))
)
  (let
    (
      (log-id (var-get next-custody-log-id))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (transport-exists (is-some (map-get? transport-records { transport-id: transport-id })))
    )
    ;; Validations
    (asserts! transport-exists ERR-NOT-FOUND)
    (asserts! (> (len custody-event) u0) (err u400))
    
    ;; Create custody log
    (map-set custody-logs
      { log-id: log-id }
      {
        transport-id: transport-id,
        custody-event: custody-event,
        from-party: from-party,
        to-party: to-party,
        handover-time: current-time,
        location: location,
        condition-notes: condition-notes,
        signatures-hash: signatures-hash,
        photos-hash: photos-hash,
        recorded-by: tx-sender
      }
    )
    
    (var-set next-custody-log-id (+ log-id u1))
    (ok log-id)
  )
)

;; Record site arrival inspection
(define-public (record-site-inspection
  (transport-id uint)
  (overall-condition (string-ascii 32))
  (damage-assessment (string-ascii 512))
  (acceptance-status bool)
  (rejection-reason (optional (string-ascii 256)))
  (inspection-photos (string-ascii 128))
  (next-actions (string-ascii 256))
)
  (let
    (
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (transport-exists (is-some (map-get? transport-records { transport-id: transport-id })))
    )
    ;; Validations
    (asserts! transport-exists ERR-NOT-FOUND)
    
    ;; Create inspection record
    (map-set site-inspections
      { transport-id: transport-id }
      {
        inspector-principal: tx-sender,
        inspection-time: current-time,
        overall-condition: overall-condition,
        damage-assessment: damage-assessment,
        acceptance-status: acceptance-status,
        rejection-reason: rejection-reason,
        inspection-photos: inspection-photos,
        next-actions: next-actions,
        signed-off-by: none
      }
    )
    
    (ok true)
  )
)

;; Update installation milestone
(define-public (update-installation-milestone
  (transport-id uint)
  (milestone (string-ascii 64))
  (notes (string-ascii 256))
  (verification-hash (optional (string-ascii 128)))
)
  (let
    (
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
      (transport-exists (is-some (map-get? transport-records { transport-id: transport-id })))
    )
    ;; Validations
    (asserts! transport-exists ERR-NOT-FOUND)
    
    ;; Update milestone
    (map-set installation-milestones
      { transport-id: transport-id, milestone: milestone }
      {
        completed: true,
        completion-time: (some current-time),
        completed-by: (some tx-sender),
        notes: notes,
        verification-hash: verification-hash
      }
    )
    
    (ok true)
  )
)

;; READ-ONLY FUNCTIONS

;; Get transport record details
(define-read-only (get-transport-details (transport-id uint))
  (map-get? transport-records { transport-id: transport-id })
)

;; Get sensor readings for transport
(define-read-only (get-sensor-reading (reading-id uint))
  (map-get? sensor-readings { reading-id: reading-id })
)

;; Get custody log entry
(define-read-only (get-custody-log (log-id uint))
  (map-get? custody-logs { log-id: log-id })
)

;; Get site inspection results
(define-read-only (get-site-inspection (transport-id uint))
  (map-get? site-inspections { transport-id: transport-id })
)

;; Get installation milestone
(define-read-only (get-installation-milestone (transport-id uint) (milestone (string-ascii 64)))
  (map-get? installation-milestones { transport-id: transport-id, milestone: milestone })
)

;; Get environmental alerts summary
(define-read-only (get-environmental-alerts (transport-id uint))
  (map-get? environmental-alerts { transport-id: transport-id })
)

;; Check if transport is completed
(define-read-only (is-transport-completed (transport-id uint))
  (match (map-get? transport-records { transport-id: transport-id })
    transport-data (is-eq (get status transport-data) STATUS-INSTALLED)
    false
  )
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-transports: (- (var-get next-transport-id) u1),
    total-readings: (- (var-get next-sensor-reading-id) u1),
    total-custody-logs: (- (var-get next-custody-log-id) u1)
  }
)

;; PRIVATE FUNCTIONS

;; Check if sensor reading exceeds thresholds
(define-private (check-threshold-exceeded (sensor-type (string-ascii 32)) (reading-value int))
  (if (is-eq sensor-type "SHOCK")
    (> reading-value MAX-SHOCK-THRESHOLD)
    (if (is-eq sensor-type "TILT")
      (> reading-value MAX-TILT-THRESHOLD)
      (if (is-eq sensor-type "TEMPERATURE")
        (or (< reading-value MIN-TEMPERATURE-CELSIUS) (> reading-value MAX-TEMPERATURE-CELSIUS))
        false
      )
    )
  )
)

;; Validate sensor reading values
(define-private (validate-sensor-reading (sensor-type (string-ascii 32)) (reading-value int))
  (if (is-eq sensor-type "SHOCK")
    (and (>= reading-value 0) (<= reading-value 1000))
    (if (is-eq sensor-type "TILT")
      (and (>= reading-value 0) (<= reading-value 90))
      (if (is-eq sensor-type "TEMPERATURE")
        (and (>= reading-value -100) (<= reading-value 100))
        false
      )
    )
  )
)

;; Update environmental alerts counters
(define-private (update-environmental-alerts (transport-id uint) (sensor-type (string-ascii 32)))
  (let
    (
      (current-alerts (default-to { shock-alerts: u0, tilt-alerts: u0, temperature-alerts: u0, last-alert-time: none, total-alerts: u0 }
                                  (map-get? environmental-alerts { transport-id: transport-id })))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u999)))
    )
    (let
      (
        (updated-alerts
          (if (is-eq sensor-type "SHOCK")
            (merge current-alerts { 
              shock-alerts: (+ (get shock-alerts current-alerts) u1),
              total-alerts: (+ (get total-alerts current-alerts) u1),
              last-alert-time: (some current-time)
            })
            (if (is-eq sensor-type "TILT")
              (merge current-alerts {
                tilt-alerts: (+ (get tilt-alerts current-alerts) u1),
                total-alerts: (+ (get total-alerts current-alerts) u1),
                last-alert-time: (some current-time)
              })
              (if (is-eq sensor-type "TEMPERATURE")
                (merge current-alerts {
                  temperature-alerts: (+ (get temperature-alerts current-alerts) u1),
                  total-alerts: (+ (get total-alerts current-alerts) u1),
                  last-alert-time: (some current-time)
                })
                current-alerts
              )
            )
          )
        )
      )
      (map-set environmental-alerts { transport-id: transport-id } updated-alerts)
      true
    )
  )
)

