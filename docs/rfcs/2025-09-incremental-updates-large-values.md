# RFC: Incremental Updates for Large Values (Post-v1.0)

Labels: rfc, design-document, incremental, optimization, future-version, compatibility, non-v1.0

Milestone: RFC / Non-v1.0

Effort: S (2–3 engineer-days)

Status: Draft (Design only; no implementation in v1.0)

## Abstract

This document proposes a future, optional mechanism to update large values incrementally by transmitting only the changed portions (deltas) instead of full values. The design is strictly compatible with the Locked Spec v1.0: it introduces no changes to current v1.0 wire formats or protocols and requires no changes to existing implementations. It serves as a foundation for potential post-v1.0 optimization work.

## Background & Rationale

Large values near the 256 KiB limit can be expensive to sync on mobile networks, especially when updates are frequent but small. Full-value replication wastes bandwidth and battery. An incremental update mechanism could substantially reduce transmitted bytes by shipping deltas computed against a known base version of the value. This RFC outlines how such a mechanism can be introduced in future versions while keeping v1.0 fully intact and interoperable.

## Scope

In-scope (RFC/Design Only):
- Design document for incremental update mechanisms
- Compatibility analysis with Locked Spec v1.0 wire formats
- Future protocol extension proposals without current implementation
- Theoretical performance analysis and bandwidth savings estimation
- Integration strategy for potential future versions
- Design considerations for mobile constraints and battery impact

Out-of-scope:
- Any implementation in v1.0 (design document only)
- Changes to current v1.0 wire formats or protocols
- Violation of Locked Spec v1.0 requirements
- Production code or functional implementation

## Goals and Non-Goals

Goals:
- Define a backwards/forwards compatible approach to incremental updates for large values
- Ensure strict v1.0 compatibility: zero changes to existing wire formats and behaviors
- Provide clear success criteria, thresholds, and guardrails for when deltas make sense
- Anticipate mobile constraints (CPU, memory, battery) in the design

Non-Goals:
- Implementing the mechanism in v1.0
- Mandating the use of deltas for all deployments
- Altering current replication semantics or conflict resolution in v1.0

## v1.0 Compatibility Guarantee

- No wire format changes in current version.
- No protocol modifications affecting interoperability.
- Current implementation remains fully Spec v1.0 compliant.
- Any future changes must be optional and capability-negotiated; peers that do not support deltas continue using full values without any behavioral differences.

## Constraints and Assumptions

- Max value size: 256 KiB (v1.0 limit remains unchanged).
- Replication uses CBOR+base64 payloads in v1.0; this remaining unchanged is a hard requirement.
- LWW (last-write-wins) remains the conflict resolution semantics; deltas must not alter LWW guarantees.
- Mobile devices have limited CPU/battery; delta computation must be selective, adaptive, and bounded.

## Proposed Architecture (Future, Optional)

High-level concept:
- Introduce an optional “delta envelope” in a future replication event version (not v1.0). The envelope carries:
  - Base identifier: content hash (e.g., BLAKE3/SHA-256) and/or sequence number of the base value the delta applies to.
  - Delta payload: compact encoding of changes relative to the base.
  - Full-value fallback: optionally include a full value if delta is inefficient or base is unavailable on receiver.
  - Integrity metadata: hashes of base, delta, and expected result to validate correctness.

Behavioral requirements:
- If the receiver lacks the referenced base (by hash/seq), it requests or falls back to the full value.
- Deltas are only used when: size(delta) + overhead < size(full value) × threshold (e.g., 0.8); threshold is tunable.
- For small changes below a byte/percentage threshold, deltas are preferred; otherwise, full transmission remains simpler and cheaper.
- Deltas are purely an optimization — semantics of the resulting value are identical to a full-value write.

### Capability Discovery (Future)

- Advertise support via capability bitset or feature flags exchanged during session setup (out of scope for v1.0).
- If either side lacks support, full-value behavior is used transparently.

### Base Version Tracking

- Each stored value maintains metadata:
  - contentHash (of current bytes)
  - logicalVersion (e.g., sequence number / vector clock entry if applicable)
  - lastReplicatedHash (to help choose a good delta base)
- A sender chooses a base known (or likely known) by the receiver (e.g., last acknowledged hash).

### Delta Encoding Options (Evaluation Only)

- Text-oriented algorithms: Myers, patience diff (good for JSON/text; variable CPU cost).
- Binary delta algorithms: xdelta3, bsdiff/courgette (strong compression; higher CPU/memory).
- Rolling-hash based chunking (rsync/CDC, Rabin-Karp):
  - Content-defined chunking to detect moved/inserted regions efficiently.
  - Good for binary blobs; robust to small shifts.

A pragmatic path likely combines CDC to find regions, then local binary diffs within changed chunks.

### Chunking Strategy (Future)

- Content-defined chunking with target chunk size (e.g., 4–8 KiB) and min/max bounds.
- Maintain per-value chunk hashes (Merkle-like) to support selective retransmission of changed chunks.
- Delta payload becomes a sequence of references (unchanged chunks) + inline bytes (changed chunks).

### Integrity and Validation

- Include baseHash, resultHash and deltaHash in the envelope; verify at receiver:
  1) baseHash matches local base contents
  2) applying delta yields result with resultHash
  3) delta payload integrity via deltaHash
- On any mismatch, discard delta and request full value.

### Conflict Resolution (LWW) Compatibility

- LWW timestamp/vector remains the authority for which write is applied.
- Deltas inherit the same logical timestamp as equivalent full values.
- If two concurrent deltas target different bases, normal LWW chooses the winning write; the winning write must be represented as a concrete value (either by applying the delta if base is present or by re-sending full value).

## Efficiency Thresholds and Policy

Let:
- V = size of full value (bytes)
- D = size of encoded delta (bytes)
- O = overhead for metadata (hashes, headers) (bytes)
- T = decision threshold factor (0 < T < 1)

Use delta if D + O ≤ T × V, otherwise send full value. Reasonable starting points:
- T = 0.8 (20% savings minimum to cover CPU/battery costs)
- For very small V (e.g., < 8 KiB), prefer full value (avoid CPU overhead)
- Backoff if CPU usage is high, battery is low, or thermal constraints are active

## Theoretical Performance Modeling

Example scenario:
- V = 256 KiB, change rate = 5% uniformly distributed per update
- With CDC chunk size ≈ 8 KiB, expect ~5% chunks changed ≈ 3–4 chunks
- D ≈ changedChunks × (chunkSize + per-chunk headers) ≈ 4 × (8 KiB + 64 B) ≈ 32.25 KiB
- O (global) ≈ 256 B (hashes, headers)
- Full send = 256 KiB; delta = ~32.5 KiB → ~87% reduction

Battery/CPU considerations:
- CDC and delta encoding cost scale with V; leverage adaptive policies (only attempt delta when recent CPU load < threshold and battery > threshold; else send full value).

## Mobile Constraints and Battery Impact

- CPU-bound delta construction may offset bandwidth gains; policy must be adaptive.
- Cache recent chunk hashes to avoid recomputation for successive small edits.
- Rate limit delta computation on background or low-power modes.
- Allow dynamic disablement when device thermal state is elevated.

## Security & Privacy

- Data integrity: resultHash verification ensures correctness; reject mismatches.
- Resource protection: bound delta algorithm memory usage and time; enforce max delta size.
- Privacy: deltas should not reveal additional information beyond the final value; payload confidentiality relies on existing transport security (TLS) unchanged.

## Observability (Design-phase Metrics)

- design_completeness_score: qualitative checklist completion
- compatibility_analysis_coverage: proportion of v1.0 scenarios analyzed
- implementation_readiness_score: subjective readiness assessment
- integration_complexity_assessment: estimated complexity levels
- v1_0_compliance_verification: confirmed no wire format changes for v1.0
- wire_format_impact_analysis: documented impact = none for v1.0

## Risks & Mitigations

- Premature optimization distracting from v1.0: limit to RFC-only now; roadmap later.
- Compatibility analysis missing edge cases: document comprehensive v1.0 scenarios and require expert review.
- Design complexity affecting future implementation: keep envelope minimal; prefer chunk-based deltas with simple validation.
- Performance assumptions not validated: mark estimates; plan empirical validation phase before rollout.

## Compatibility Strategy for Mixed Environments

- If peer lacks delta capability: send full values.
- If base missing at receiver: fallback to full value automatically.
- If validation fails: request full value; optionally blacklist that base for delta until updated.

## Fallback Mechanisms

- Always support full-value replication; deltas are opportunistic.
- Maintain per-key last-known-good full value snapshot frequency to cap worst-case recovery cost.

## Test Plan (Design Validation)

- RFC technical review by distributed systems experts.
- Theoretical validation against v1.0 requirements and wire formats (no changes proposed).
- Performance modeling with synthetic datasets; vary change rates (1%, 5%, 10%, 25%).
- Security/integrity reasoning validation for delta application and hash checks.
- Implementation planning workshop to outline phased rollout in a future version.

## Acceptance Criteria Mapping

- Complete RFC design document provided → this document.
- v1.0 compatibility analysis shows no current wire format changes → guaranteed and documented.
- Efficiency analysis with quantified savings → included (theoretical modeling and thresholds).
- Mobile impact assessment documented → included (adaptive policies, CPU/battery considerations).
- Compatibility strategy ensures backward/forward compatibility → included.
- Conflict resolution (LWW) compatibility → addressed.
- Edge cases under v1.0 considered without breaking compatibility → addressed via fallback and capability discovery (future).

## Future Protocol Extension Sketch (Non-binding)

- New optional event envelope fields in a future version:
  - baseHash: bytes
  - resultHash: bytes
  - deltaHash: bytes (optional if resultHash is present)
  - chunks: list of {refHash | inlineBytes}
  - policyHints: thresholds, power state hints
- Transport stays identical; envelope is version-gated and optional.

## Roadmap (Post-v1.0)

1. Prototype (lab only): evaluate CDC + binary delta combos on typical values.
2. Capability negotiation design: feature flags/cap bits.
3. Integrity model finalization: hashing choices and envelopes.
4. Policy engine: dynamic decision-making for delta vs full.
5. Interop testing: mixed environments, missing base scenarios.
6. Gradual rollout plan with kill-switch and telemetry.

## Open Questions

- Best default chunk size and bounds across device classes?
- Which hash (BLAKE3 vs SHA-256) balances speed and security for mobile?
- Minimum benefit threshold T for real-world conditions?
- How to persist per-value chunk indices efficiently within current storage constraints?
