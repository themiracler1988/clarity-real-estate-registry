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


