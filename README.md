# Secure Docs Protocol

Enterprise-grade on-chain governance infrastructure for confidential document lifecycles, built natively on the Stacks blockchain. Secure Docs Protocol provides cryptographically-secured vaults with multi-tiered access hierarchies and immutable audit trails for sensitive enterprise and institutional document management.

## Problem Statement & Value Proposition

Traditional enterprise document management systems rely on centralized custodians and trust assumptions that don't scale to multi-party ecosystems. Secure Docs Protocol eliminates intermediary risk by deploying governance logic directly to the blockchain, where:

- **Verifiable Ownership**: Document ownership recorded immutably on-chain
- **Cryptographic Integrity**: Content hashes prove document authenticity and detect tampering
- **Transparent Access**: All permission changes logged in permanent audit trail
- **Programmable Collaboration**: Multi-party workflows enforced by smart contract logic
- **Sovereign Control**: No third-party service provider can restrict document access

## Core Capabilities

### Vault Infrastructure
- Create encrypted document vaults with persistent ownership records
- Establish organizational access tiers with granular permission hierarchies
- Support multiple concurrent vaults per principal for organizational segmentation
- Maintain immutable vault audit logs including all membership changes

### Asset Lifecycle Management
- Register document metadata with cryptographic hash commitments
- Publish versioned revisions with modification tracking and timestamp attestation
- Organize assets into vaults for categorical management and workflow routing
- Query complete version history with audit details for compliance documentation

### Multi-Tier Access Control System
- **RESTRICTED (u0)**: Denied access state - default permission tier
- **OBSERVER (u1)**: Read-only access to metadata and historical versions
- **CONTRIBUTOR (u2)**: Write capabilities including revision publication and asset enrollment
- **STEWARD (u3)**: Administrative authority for delegation and vault governance

### Audit & Compliance Features
- Immutable recording of asset creation, modification, and removal events
- Complete version history with agent identity and timestamps for accountability
- Optional change notes documenting business rationale for regulatory compliance
- Owner-exclusive access delegation prevents unauthorized permission escalation

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│         Secure Docs Protocol - Vault Manager         │
├─────────────────────────────────────────────────────┤
│                                                       │
│  ┌──────────────┐    ┌──────────────┐               │
│  │ Vault        │    │ Asset        │               │
│  │ Registry     │    │ Repository   │               │
│  └──────────────┘    └──────────────┘               │
│         ▲                    ▲                        │
│         └────────┬───────────┘                       │
│                  │                                   │
│         ┌────────▼────────┐                         │
│         │ Vault-Asset     │                         │
│         │ Index           │                         │
│         └─────────────────┘                         │
│                                                       │
│  ┌──────────────┐    ┌──────────────┐               │
│  │ Access       │    │ Access       │               │
│  │ Tables       │    │ History      │               │
│  └──────────────┘    └──────────────┘               │
│                                                       │
└─────────────────────────────────────────────────────┘
```

### Primary Data Structures

| Entity | Purpose | Scope |
|--------|---------|-------|
| `vault-registry` | Persistent vault ownership and metadata | Per-vault |
| `asset-repository` | Document metadata with integrity tracking | Per-asset |
| `vault-asset-index` | Vault membership associations | Many-to-many |
| `asset-change-history` | Complete revision audit trail | Per-asset-version |
| `vault-access-table` | Vault-level tier assignments | Per-principal-per-vault |
| `asset-access-table` | Asset-level tier assignments | Per-principal-per-asset |

## Getting Started

### System Requirements
- Clarinet development environment (v2.0+)
- Stacks-compatible wallet with testnet STX
- Node.js 18+ for testing framework

### Installation & Deployment

```bash
# Clone repository
git clone https://github.com/your-org/secure-docs-protocol.git
cd secure-docs-protocol

# Install dependencies
npm install

# Validate contract syntax
clarinet check

# Run test suite
npm run test

# Deploy to local testnet
clarinet deploy
```

## Contract Reference

### vault-manager.clar

The primary orchestration contract implementing vault governance and access control.

#### Vault Operations

**Establish Vault**
```clarity
(contract-call? .vault-manager establish-vault
    "vault-enterprise-001"
    "Q4 Strategic Initiatives"
    (some "Contains confidential strategy documents"))
```

**Retire Vault** (Owner-only)
```clarity
(contract-call? .vault-manager retire-vault
    "vault-enterprise-001")
```

#### Asset Operations

**Enroll Asset**
```clarity
(contract-call? .vault-manager enroll-asset
    "asset-strategic-2024-01"
    "Strategic Plan Q4"
    (some "Annual strategic planning document")
    "pdf"
    "ar://storage/strategic_plan_q4_2024.pdf"
    0x{hash_digest}
    u234567)
```

**Publish Revision**
```clarity
(contract-call? .vault-manager publish-asset-revision
    "asset-strategic-2024-01"
    "Strategic Plan Q4 - Final"
    (some "Updated with board feedback")
    "ar://storage/strategic_plan_q4_2024_v2.pdf"
    0x{updated_hash}
    u245000
    (some "Incorporated board revision comments"))
```

**Retire Asset** (Owner-only)
```clarity
(contract-call? .vault-manager retire-asset
    "asset-strategic-2024-01")
```

#### Membership Operations

**Attach Asset to Vault**
```clarity
(contract-call? .vault-manager attach-asset-to-vault
    "vault-enterprise-001"
    "asset-strategic-2024-01")
```

**Remove Asset from Vault**
```clarity
(contract-call? .vault-manager remove-asset-from-vault
    "vault-enterprise-001"
    "asset-strategic-2024-01")
```

#### Permission Management

**Grant Vault Access**
```clarity
(contract-call? .vault-manager grant-vault-access
    "vault-enterprise-001"
    'SPTEAM_MEMBER_ADDRESS
    u2)  ;; CONTRIBUTOR tier
```

**Grant Asset Access**
```clarity
(contract-call? .vault-manager grant-asset-access
    "asset-strategic-2024-01"
    'SPREVIEW_STAKEHOLDER_ADDRESS
    u1)  ;; OBSERVER tier
```

#### Query Functions

**Read Vault Details**
```clarity
(contract-call? .vault-manager read-vault-info
    "vault-enterprise-001")
```

**Query Asset Metadata**
```clarity
(contract-call? .vault-manager read-asset-info
    "asset-strategic-2024-01")
```

**Retrieve Version Snapshot**
```clarity
(contract-call? .vault-manager read-version-snapshot
    "asset-strategic-2024-01"
    u3)  ;; Third revision iteration
```

**Verify Access Tiers**
```clarity
(contract-call? .vault-manager verify-read-access
    "asset-strategic-2024-01"
    'SPUSER_ADDRESS)

(contract-call? .vault-manager verify-write-access
    "asset-strategic-2024-01"
    'SPCONTRIBUTOR_ADDRESS)

(contract-call? .vault-manager verify-admin-access
    "vault-enterprise-001"
    'SPADMIN_ADDRESS)
```

## Deployment Workflow

### Phase 1: Local Development
```bash
npm run test:watch  # Monitor code changes with live testing
```

### Phase 2: Testnet Integration
```bash
# Update Testnet.toml with your testnet wallet
clarinet deploy --network testnet
```

### Phase 3: Mainnet Production
```bash
# Update Mainnet.toml with production wallet
clarinet deploy --network mainnet
```

## Security Architecture

### Access Control Model
- **Owner Privilege**: Asset and vault owners bypass explicit tier checks - receive implicit STEWARD (u3) equivalent authority
- **Delegation Authority**: Only owners can call permission-granting functions, preventing privilege escalation
- **Tier Enforcement**: Each operation validates requestor tier against operation requirements
- **Immutable Permissions**: No permission revocation function exists; archive and re-grant recommended for tier changes

### Cryptographic Commitments
- **Content Hashing**: 32-byte hash digest commitment prevents undetected tampering
- **Version Integrity**: Each revision maintains independent hash preventing retroactive modification
- **Timestamp Attestation**: Blockchain block height proves temporal ordering of revisions

### Audit Trail Guarantees
- **Permanent Recording**: All state changes recorded in immutable maps
- **Agent Identity**: Principal identity captured in each version history entry
- **Modification Causality**: Asset altered timestamp updated with each revision enabling forensics

## Multi-Party Collaboration Patterns

### Pattern: Confidential Review & Approval

1. **Document Owner** publishes initial asset revision
2. **Steward** grants OBSERVER tier to reviewers
3. **Observers** query read-version-snapshot to review changes
4. **Contributors** publish revision incorporating feedback
5. **Audit Trail** maintains complete change history with reviewer identities

### Pattern: Cross-Organizational Asset Sharing

1. **Org A** creates asset in vault-a
2. **Org A** creates vault-b for partnership
3. **Org A** attaches asset to vault-b via attach-asset-to-vault
4. **Org A** grants OBSERVER tier on vault-b to Org B principals
5. **Org B** queries metadata without requiring asset copy

### Pattern: Tiered Governance Escalation

- **Level 1**: Contributors create draft revisions
- **Level 2**: Stewards publish approved revisions to production vault
- **Level 3**: Observers from downstream teams can query published versions
- **Audit**: Complete chain of modification recorded for compliance

## Development & Testing

### Unit Test Execution
```bash
npm run test
```

### Coverage Report
```bash
npm run test:report
```

### Local Console Exploration
```bash
clarinet console
```

Inside console:
```clarity
;; Inspect vault state
(contract-call? .vault-manager read-vault-info "vault-id")

;; Verify permission status
(contract-call? .vault-manager verify-read-access "asset-id" 'SP_ADDRESS)
```

## Error Codes Reference

| Code | Constant | Meaning | Recovery |
|------|----------|---------|----------|
| u100 | `fail-no-auth` | Insufficient permissions for operation | Verify tier or ownership, request higher tier grant |
| u101 | `fail-vault-absent` | Referenced vault doesn't exist | Create vault via `establish-vault` before reference |
| u102 | `fail-asset-absent` | Referenced asset doesn't exist | Enroll asset via `enroll-asset` before reference |
| u103 | `fail-already-registered` | ID already in use | Select different identifier, check for existing asset |
| u104 | `fail-invalid-params` | Invalid parameters passed | Validate parameter types and ranges |
| u105 | `fail-permission-invalid` | Invalid tier value | Specify tier in range u0-u3 |

## Production Considerations

### Gas Optimization
- Asset queries cache frequently-accessed metadata to minimize map lookups
- Pagination recommended for vaults with >1000 assets via off-chain indexing
- Batch operations combine multiple state changes into single transaction

### Scalability Architecture
- Each vault independently manages assets without cross-vault dependencies
- Access tables indexed per principal enabling efficient permission queries
- Version history keyed by asset-iteration supporting append-only design

### Compliance & Auditing
- All operations leave immutable blockchain record
- Timestamps prove temporal ordering of document modifications
- Agent identity enables multi-party responsibility tracking
- Optional revision notes document business justification

### Backup & Disaster Recovery
- Vault registry contains no critical state requiring backup
- Asset metadata replicates across blockchain nodes automatically
- Off-chain document content should replicate to independent IPFS/Arweave nodes
- Version history enables point-in-time recovery of document states

## Roadmap & Future Enhancements

- [ ] Hierarchical permission inheritance from parent vaults
- [ ] Automated expiration policies for time-bound asset access
- [ ] Multi-signature approval workflows for sensitive revisions
- [ ] Integration with oracle services for external document authentication
- [ ] Cross-chain asset attestation to other blockchain networks

## Community & Support

For questions, issues, or contributions:
- Report bugs via GitHub Issues
- Propose enhancements via GitHub Discussions
- Submit PRs following contribution guidelines

## License

Secure Docs Protocol is released under the Apache 2.0 License.