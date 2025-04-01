;; Clarity Real Estate Registry Blockchain System
;; A decentralized platform for real estate document management and verification

;; System Governance Constants
(define-constant registry-admin tx-sender)
(define-constant err-item-not-found (err u301))
(define-constant err-item-already-exists (err u302))
(define-constant err-invalid-title (err u303))
(define-constant err-invalid-document-size (err u304))
(define-constant err-unauthorized-access (err u305))
(define-constant err-not-property-owner (err u306))
(define-constant err-admin-only (err u300))
(define-constant err-visibility-restricted (err u307))
(define-constant err-tag-format-invalid (err u308))

;; Track total registry entries
(define-data-var registry-entry-count uint u0)

;; ===== Core Registry Storage =====

;; Primary data store for property documents
(define-map estate-registry
  { entry-id: uint }
  {
    title: (string-ascii 64),
    owner: principal,
    file-size: uint,
    registration-block: uint,
    description: (string-ascii 128),
    tags: (list 10 (string-ascii 32))
  }
)

;; Permission management for document access
(define-map viewing-permissions
  { entry-id: uint, viewer: principal }
  { access-allowed: bool }
)

;; ===== Utility & Validation Functions =====

;; Checks if entry with given ID exists
(define-private (entry-exists (entry-id uint))
  (is-some (map-get? estate-registry { entry-id: entry-id }))
)

;; Validates property tag format requirements
(define-private (valid-tag (tag (string-ascii 32)))
  (and
    (> (len tag) u0)
    (< (len tag) u33)
  )
)

;; Validates the entire set of property tags
(define-private (validate-tags (tag-list (list 10 (string-ascii 32))))
  (and
    (> (len tag-list) u0)
    (<= (len tag-list) u10)
    (is-eq (len (filter valid-tag tag-list)) (len tag-list))
  )
)

;; Checks if principal is the owner of a property record
(define-private (owns-entry (entry-id uint) (viewer principal))
  (match (map-get? estate-registry { entry-id: entry-id })
    entry-data (is-eq (get owner entry-data) viewer)
    false
  )
)

;; Gets document size for specified entry
(define-private (get-document-size (entry-id uint))
  (default-to u0
    (get file-size
      (map-get? estate-registry { entry-id: entry-id })
    )
  )
)

;; ===== Registry Management Functions =====

;; Registers a new property document in the system
(define-public (register-property 
  (property-title (string-ascii 64)) 
  (document-size uint) 
  (property-details (string-ascii 128)) 
  (property-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (next-id (+ (var-get registry-entry-count) u1))
    )
    ;; Input validation checks
    (asserts! (> (len property-title) u0) err-invalid-title)
    (asserts! (< (len property-title) u65) err-invalid-title)
    (asserts! (> document-size u0) err-invalid-document-size)
    (asserts! (< document-size u1000000000) err-invalid-document-size)
    (asserts! (> (len property-details) u0) err-invalid-title)
    (asserts! (< (len property-details) u129) err-invalid-title)
    (asserts! (validate-tags property-tags) err-tag-format-invalid)

    ;; Create the property record
    (map-insert estate-registry
      { entry-id: next-id }
      {
        title: property-title,
        owner: tx-sender,
        file-size: document-size,
        registration-block: block-height,
        description: property-details,
        tags: property-tags
      }
    )

    ;; Set initial access permissions
    (map-insert viewing-permissions
      { entry-id: next-id, viewer: tx-sender }
      { access-allowed: true }
    )

    ;; Update counter and return success
    (var-set registry-entry-count next-id)
    (ok next-id)
  )
)

;; Updates property information for an existing entry
(define-public (update-property 
  (entry-id uint) 
  (new-title (string-ascii 64)) 
  (new-size uint) 
  (new-details (string-ascii 128)) 
  (new-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (entry-data (unwrap! (map-get? estate-registry { entry-id: entry-id }) err-item-not-found))
    )
    ;; Validate ownership and input parameters
    (asserts! (entry-exists entry-id) err-item-not-found)
    (asserts! (is-eq (get owner entry-data) tx-sender) err-not-property-owner)
    (asserts! (> (len new-title) u0) err-invalid-title)
    (asserts! (< (len new-title) u65) err-invalid-title)
    (asserts! (> new-size u0) err-invalid-document-size)
    (asserts! (< new-size u1000000000) err-invalid-document-size)
    (asserts! (> (len new-details) u0) err-invalid-title)
    (asserts! (< (len new-details) u129) err-invalid-title)
    (asserts! (validate-tags new-tags) err-tag-format-invalid)

    ;; Update the property record with new information
    (map-set estate-registry
      { entry-id: entry-id }
      (merge entry-data { 
        title: new-title, 
        file-size: new-size, 
        description: new-details, 
        tags: new-tags 
      })
    )
    (ok true)
  )
)

;; Transfers property ownership to another principal
(define-public (transfer-property (entry-id uint) (new-owner principal))
  (let
    (
      (entry-data (unwrap! (map-get? estate-registry { entry-id: entry-id }) err-item-not-found))
    )
    ;; Verify caller is the current owner
    (asserts! (entry-exists entry-id) err-item-not-found)
    (asserts! (is-eq (get owner entry-data) tx-sender) err-not-property-owner)

    ;; Update ownership
    (map-set estate-registry
      { entry-id: entry-id }
      (merge entry-data { owner: new-owner })
    )
    (ok true)
  )
)

;; Removes a property record from the registry
(define-public (delete-property (entry-id uint))
  (let
    (
      (entry-data (unwrap! (map-get? estate-registry { entry-id: entry-id }) err-item-not-found))
    )
    ;; Ownership verification
    (asserts! (entry-exists entry-id) err-item-not-found)
    (asserts! (is-eq (get owner entry-data) tx-sender) err-not-property-owner)

    ;; Remove the property record
    (map-delete estate-registry { entry-id: entry-id })
    (ok true)
  )
)
