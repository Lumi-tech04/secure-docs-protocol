;; Secure Docs Protocol - Vault Manager
;; 
;; Core orchestration contract implementing on-chain metadata management,
;; collaborative access governance, and immutable audit trails for
;; enterprise-grade document governance on the Stacks blockchain.
;;
;; This module provides:
;; - Secure vaults with granular permission hierarchies
;; - Multi-party document collaboration with version histories
;; - Immutable audit logging for compliance requirements

;; ============================================================================
;; Error Constants - Hierarchical Classification
;; ============================================================================

(define-constant fail-no-auth (err u100))
(define-constant fail-vault-absent (err u101))
(define-constant fail-asset-absent (err u102))
(define-constant fail-already-registered (err u103))
(define-constant fail-invalid-params (err u104))
(define-constant fail-permission-invalid (err u105))

;; ============================================================================
;; Access Control Tier Constants
;; ============================================================================

(define-constant ACCESS-TIER-RESTRICTED u0)
(define-constant ACCESS-TIER-OBSERVER u1)
(define-constant ACCESS-TIER-CONTRIBUTOR u2)
(define-constant ACCESS-TIER-STEWARD u3)

;; ============================================================================
;; Core Data Structures - Primary State Maps
;; ============================================================================

;; Registry of secure vaults with ownership and metadata
(define-map vault-registry
  { vault-identifier: (string-ascii 36) }
  {
    vault-name: (string-utf8 64),
    vault-owner: principal,
    vault-established: uint,
    vault-note: (optional (string-utf8 256))
  }
)

;; Repository of registered assets with cryptographic integrity tracking
(define-map asset-repository
  { asset-ref: (string-ascii 36) }
  {
    asset-title: (string-utf8 128),
    asset-info: (optional (string-utf8 256)),
    asset-category: (string-ascii 16),
    asset-reference-path: (string-utf8 256),
    asset-hash-digest: (buff 32),
    asset-owner: principal,
    asset-minted: uint,
    asset-altered: uint,
    asset-byte-size: uint,
    version-counter: uint
  }
)

;; Linkage mapping between assets and vaults (flexible many-to-many relationship)
(define-map vault-asset-index
  { vault-identifier: (string-ascii 36), asset-ref: (string-ascii 36) }
  { enrollment-time: uint }
)

;; Complete audit trail of asset revisions with delta tracking
(define-map asset-change-history
  { asset-ref: (string-ascii 36), iteration: uint }
  {
    hash-digest: (buff 32),
    reference-path: (string-utf8 256),
    modified-timestamp: uint,
    modified-by-agent: principal,
    alteration-summary: (optional (string-utf8 256))
  }
)

;; Vault-level access control assignments
(define-map vault-access-table
  { vault-identifier: (string-ascii 36), authorized-party: principal }
  { access-tier: uint }
)

;; Asset-specific permission assignments for granular control
(define-map asset-access-table
  { asset-ref: (string-ascii 36), authorized-party: principal }
  { access-tier: uint }
)

;; ============================================================================
;; Private Helper Functions - Access Control Verification
;; ============================================================================

;; Validates tier authorization for vault operations
(define-private (authenticate-vault-tier 
    (vault-id (string-ascii 36))
    (requestor principal) 
    (required-tier uint))
  (let (
    (vault-data (map-get? vault-registry { vault-identifier: vault-id }))
    (tier-record (map-get? vault-access-table { vault-identifier: vault-id, authorized-party: requestor }))
  )
    (if (is-none vault-data)
      false
      (if (is-eq (get vault-owner (unwrap-panic vault-data)) requestor)
        true
        (if (is-none tier-record)
          false
          (>= (get access-tier (unwrap-panic tier-record)) required-tier)
        )
      )
    )
  )
)

;; Validates tier authorization for asset operations
(define-private (authenticate-asset-tier 
    (asset-id (string-ascii 36))
    (requestor principal) 
    (required-tier uint))
  (let (
    (asset-data (map-get? asset-repository { asset-ref: asset-id }))
    (tier-record (map-get? asset-access-table { asset-ref: asset-id, authorized-party: requestor }))
  )
    (if (is-none asset-data)
      false
      (if (is-eq (get asset-owner (unwrap-panic asset-data)) requestor)
        true
        (if (is-none tier-record)
          false
          (>= (get access-tier (unwrap-panic tier-record)) required-tier)
        )
      )
    )
  )
)

;; Checks asset membership in a specific vault
(define-private (is-asset-member-of-vault 
    (vault-id (string-ascii 36)) 
    (asset-id (string-ascii 36)))
  (is-some (map-get? vault-asset-index { vault-identifier: vault-id, asset-ref: asset-id }))
)

;; Retrieves current version identifier for an asset
(define-private (fetch-current-version (asset-id (string-ascii 36)))
  (default-to u0 (get asset-altered (map-get? asset-repository { asset-ref: asset-id })))
)

;; Validates tier value is within permissible range
(define-private (verify-tier-validity (tier-val uint))
  (and (>= tier-val ACCESS-TIER-RESTRICTED) (<= tier-val ACCESS-TIER-STEWARD))
)

;; ============================================================================
;; Read-Only Query Functions
;; ============================================================================

;; Query vault metadata details
(define-read-only (read-vault-info (vault-id (string-ascii 36)))
  (map-get? vault-registry { vault-identifier: vault-id })
)

;; Query asset metadata and integrity information
(define-read-only (read-asset-info (asset-id (string-ascii 36)))
  (map-get? asset-repository { asset-ref: asset-id })
)

;; Retrieve specific historical version of an asset
(define-read-only (read-version-snapshot (asset-id (string-ascii 36)) (ver uint))
  (map-get? asset-change-history { asset-ref: asset-id, iteration: ver })
)

;; Verify observer-level read permissions
(define-read-only (verify-read-access (asset-id (string-ascii 36)) (agent principal))
  (authenticate-asset-tier asset-id agent ACCESS-TIER-OBSERVER)
)

;; Verify contributor-level write permissions
(define-read-only (verify-write-access (asset-id (string-ascii 36)) (agent principal))
  (authenticate-asset-tier asset-id agent ACCESS-TIER-CONTRIBUTOR)
)

;; Verify steward-level administrative permissions
(define-read-only (verify-admin-access (vault-id (string-ascii 36)) (agent principal))
  (authenticate-vault-tier vault-id agent ACCESS-TIER-STEWARD)
)

;; Enumerate vault contents (placeholder for production indexing)
(define-read-only (list-vault-assets (vault-id (string-ascii 36)))
  (ok vault-id)
)

;; ============================================================================
;; State-Modifying Operations - Vault Management
;; ============================================================================

;; Instantiate a new secure vault with initial metadata
(define-public (establish-vault
    (vault-id (string-ascii 36)) 
    (vault-label (string-utf8 64))
    (vault-description (optional (string-utf8 256)))
  )
  (let (
    (initiator tx-sender)
    (existing (map-get? vault-registry { vault-identifier: vault-id }))
  )
    (asserts! (is-none existing) fail-already-registered)
    
    (map-set vault-registry
      { vault-identifier: vault-id }
      {
        vault-name: vault-label,
        vault-owner: initiator,
        vault-established: block-height,
        vault-note: vault-description
      }
    )
    
    (ok true)
  )
)

;; Register a new asset with cryptographic integrity verification
(define-public (enroll-asset
    (asset-id (string-ascii 36))
    (asset-title (string-utf8 128))
    (asset-info (optional (string-utf8 256)))
    (asset-category (string-ascii 16))
    (asset-location (string-utf8 256)) 
    (asset-hash (buff 32))
    (asset-size uint)
  )
  (let (
    (initiator tx-sender)
    (timestamp block-height)
    (existing (map-get? asset-repository { asset-ref: asset-id }))
  )
    (asserts! (is-none existing) fail-already-registered)
    
    ;; Primary asset entry
    (map-set asset-repository
      { asset-ref: asset-id }
      {
        asset-title: asset-title,
        asset-info: asset-info,
        asset-category: asset-category,
        asset-reference-path: asset-location,
        asset-hash-digest: asset-hash,
        asset-owner: initiator,
        asset-minted: timestamp,
        asset-altered: timestamp,
        asset-byte-size: asset-size,
        version-counter: u1
      }
    )
    
    ;; Genesis version in audit trail
    (map-set asset-change-history
      { asset-ref: asset-id, iteration: u1 }
      {
        hash-digest: asset-hash,
        reference-path: asset-location,
        modified-timestamp: timestamp,
        modified-by-agent: initiator,
        alteration-summary: (some u"Initial enrollment")
      }
    )
    
    (ok true)
  )
)

;; Establish asset membership within a vault
(define-public (attach-asset-to-vault
    (vault-id (string-ascii 36)) 
    (asset-id (string-ascii 36))
  )
  (let (
    (requestor tx-sender)
    (asset-meta (map-get? asset-repository { asset-ref: asset-id }))
    (vault-meta (map-get? vault-registry { vault-identifier: vault-id }))
  )
    ;; Verify existence
    (asserts! (is-some asset-meta) fail-asset-absent)
    (asserts! (is-some vault-meta) fail-vault-absent)
    
    ;; Authorization check
    (asserts! (or 
                (is-eq (get asset-owner (unwrap-panic asset-meta)) requestor)
                (authenticate-asset-tier asset-id requestor ACCESS-TIER-CONTRIBUTOR)
              ) 
              fail-no-auth)
    
    (asserts! (or 
                (is-eq (get vault-owner (unwrap-panic vault-meta)) requestor)
                (authenticate-vault-tier vault-id requestor ACCESS-TIER-CONTRIBUTOR)
              ) 
              fail-no-auth)
              
    ;; Record membership
    (if (is-asset-member-of-vault vault-id asset-id)
      (ok true)
      (begin
        (map-set vault-asset-index
          { vault-identifier: vault-id, asset-ref: asset-id }
          { enrollment-time: block-height }
        )
        (ok true)
      )
    )
  )
)

;; Detach asset from vault membership
(define-public (remove-asset-from-vault
    (vault-id (string-ascii 36)) 
    (asset-id (string-ascii 36))
  )
  (let (
    (requestor tx-sender)
    (asset-meta (map-get? asset-repository { asset-ref: asset-id }))
    (vault-meta (map-get? vault-registry { vault-identifier: vault-id }))
  )
    ;; Verify existence
    (asserts! (is-some asset-meta) fail-asset-absent)
    (asserts! (is-some vault-meta) fail-vault-absent)
    
    ;; Authorization check
    (asserts! (or 
                (is-eq (get asset-owner (unwrap-panic asset-meta)) requestor)
                (authenticate-asset-tier asset-id requestor ACCESS-TIER-CONTRIBUTOR)
                (is-eq (get vault-owner (unwrap-panic vault-meta)) requestor)
                (authenticate-vault-tier vault-id requestor ACCESS-TIER-CONTRIBUTOR)
              ) 
              fail-no-auth)
              
    ;; Record removal
    (if (is-asset-member-of-vault vault-id asset-id)
      (begin
        (map-delete vault-asset-index
          { vault-identifier: vault-id, asset-ref: asset-id }
        )
        (ok true)
      )
      (ok true)
    )
  )
)

;; Publish asset revision with immutable version tracking
(define-public (publish-asset-revision
    (asset-id (string-ascii 36))
    (asset-title (string-utf8 128))
    (asset-info (optional (string-utf8 256)))
    (asset-location (string-utf8 256)) 
    (asset-hash (buff 32))
    (asset-size uint)
    (revision-note (optional (string-utf8 256)))
  )
  (let (
    (requestor tx-sender)
    (timestamp block-height)
    (asset-meta (unwrap! (map-get? asset-repository { asset-ref: asset-id }) fail-asset-absent))
  )
    ;; Authorization check
    (asserts! (or 
                (is-eq (get asset-owner asset-meta) requestor)
                (authenticate-asset-tier asset-id requestor ACCESS-TIER-CONTRIBUTOR)
              ) 
              fail-no-auth)
    
    ;; Compute next version
    (let ((next-ver (+ u1 (get version-counter asset-meta))))
      
      ;; Update asset record
      (map-set asset-repository
        { asset-ref: asset-id }
        (merge asset-meta
          {
            asset-title: asset-title,
            asset-info: asset-info,
            asset-reference-path: asset-location,
            asset-hash-digest: asset-hash,
            asset-altered: timestamp,
            asset-byte-size: asset-size,
            version-counter: next-ver
          }
        )
      )
      
      ;; Archive revision snapshot
      (map-set asset-change-history
        { asset-ref: asset-id, iteration: next-ver }
        {
          hash-digest: asset-hash,
          reference-path: asset-location,
          modified-timestamp: timestamp,
          modified-by-agent: requestor,
          alteration-summary: revision-note
        }
      )
      
      (ok next-ver)
    )
  )
)

;; Assign access tier to principal for vault operations
(define-public (grant-vault-access
    (vault-id (string-ascii 36)) 
    (grantee principal) 
    (tier uint)
  )
  (let (
    (requestor tx-sender)
    (vault-meta (map-get? vault-registry { vault-identifier: vault-id }))
  )
    ;; Verify vault exists
    (asserts! (is-some vault-meta) fail-vault-absent)
    
    ;; Only owner can delegate
    (asserts! (is-eq (get vault-owner (unwrap-panic vault-meta)) requestor) fail-no-auth)
    
    ;; Validate tier
    (asserts! (verify-tier-validity tier) fail-permission-invalid)
    
    ;; Assign tier
    (map-set vault-access-table
      { vault-identifier: vault-id, authorized-party: grantee }
      { access-tier: tier }
    )
    
    (ok true)
  )
)

;; Assign access tier to principal for asset operations
(define-public (grant-asset-access
    (asset-id (string-ascii 36)) 
    (grantee principal) 
    (tier uint)
  )
  (let (
    (requestor tx-sender)
    (asset-meta (map-get? asset-repository { asset-ref: asset-id }))
  )
    ;; Verify asset exists
    (asserts! (is-some asset-meta) fail-asset-absent)
    
    ;; Only owner can delegate
    (asserts! (is-eq (get asset-owner (unwrap-panic asset-meta)) requestor) fail-no-auth)
    
    ;; Validate tier
    (asserts! (verify-tier-validity tier) fail-permission-invalid)
    
    ;; Assign tier
    (map-set asset-access-table
      { asset-ref: asset-id, authorized-party: grantee }
      { access-tier: tier }
    )
    
    (ok true)
  )
)

;; Permanently remove an asset (owner-only operation)
(define-public (retire-asset (asset-id (string-ascii 36)))
  (let (
    (requestor tx-sender)
    (asset-meta (map-get? asset-repository { asset-ref: asset-id }))
  )
    ;; Verify asset exists
    (asserts! (is-some asset-meta) fail-asset-absent)
    
    ;; Only owner can retire
    (asserts! (is-eq (get asset-owner (unwrap-panic asset-meta)) requestor) fail-no-auth)
    
    ;; Remove asset
    (map-delete asset-repository { asset-ref: asset-id })
    
    (ok true)
  )
)

;; Permanently remove a vault (owner-only operation)
(define-public (retire-vault (vault-id (string-ascii 36)))
  (let (
    (requestor tx-sender)
    (vault-meta (map-get? vault-registry { vault-identifier: vault-id }))
  )
    ;; Verify vault exists
    (asserts! (is-some vault-meta) fail-vault-absent)
    
    ;; Only owner can retire
    (asserts! (is-eq (get vault-owner (unwrap-panic vault-meta)) requestor) fail-no-auth)
    
    ;; Remove vault
    (map-delete vault-registry { vault-identifier: vault-id })
    
    (ok true)
  )
)
