# feat(mqtt): retained publish support + SUBACK-gated subscription restoration

## 📋 Summary
Implements deterministic MQTT subscription restoration using per-topic SUBACK acknowledgments and adds narrowly-scoped retained publish support (for broker mode detection only). Resolves race conditions where responses published immediately after reconnect were lost because subscriptions were not yet active.

## ✨ Key Changes
- Added `retain` flag support across internal publish APIs (default remain `retain=false` for application data)
- Introduced `Stream<String> onSubscribed` in MQTT client abstraction emitting topic on SUBACK
- `TopicRouter` restoration now waits for all previous topics' SUBACKs (or timeout) before signaling completion
- Added `waitForRestore()` helper used by integration tests for deterministic sequencing
- Reattach updates listener on every connect to prevent stale stream loss
- New test: `response_subscription_restore_test` verifying post-reconnect response delivery
- Updated broker mode detection integration test to use retained message semantics
- Updated mocks across test suite to implement `onSubscribed` stream (703 tests passing)

## 🐞 Issues Fixed
| Problem | Root Cause | Resolution |
|---------|------------|-----------|
| Lost first response after reconnect | Race: publish arrived before subscription SUBACK | Gate restoration on SUBACK events |
| Stale updates listener after reconnect | Listener not reattached | Always reattach on `onConnected` |

## 🔧 Implementation Details
### SUBACK-Gated Flow
1. Reconnect triggers restoration of previously subscribed topics
2. Each subscribe call tracked as pending
3. For each SUBACK event (`onSubscribed`), topic removed from pending
4. Restoration completes only when pending set empty or timeout (configurable default)
5. Higher layers proceed (e.g., sending correlated commands) only after `waitForRestore()` resolves

### Retained Publish Usage
- Restricted to broker capability/mode detection (external vs embedded)
- All replication/event payloads continue using `retain=false`
- Preserves Locked Spec expectations for application data paths

## 🧪 Testing
- Added deterministic restoration test ensuring messages published during disconnect are delivered after reconnection
- Updated all MQTT mocks to emit SUBACK events synchronously for simplicity
- Entire suite (703 tests) green after interface addition

## 📚 Documentation
- README section added: Deterministic Subscription Restoration (SUBACK‑Gated)
- CHANGELOG Unreleased updated with feature summary, migration notes, and compliance confirmation

## 🔒 Locked Spec v1.0 Compliance
- No wire format changes
- QoS=1 maintained; retained only for capability probe, not state replication
- Size/time limits unchanged
- Determinism improved via explicit restoration barrier

## 🧩 Migration Notes
- If you implement a custom MQTT client mock, add:
  - `StreamController<String>` and a getter `onSubscribed`
  - Emit the topic inside your `subscribe()` implementation (or after simulated delay)
- Existing consumers ignoring `onSubscribed` do not break; it's additive

## ⚡ Performance
- Negligible overhead: one stream event per subscribed topic during restoration
- No added steady-state runtime cost

## ✅ Verification Checklist
- [x] Lost post-reconnect message reproduced pre-fix
- [x] Fix eliminates race under repeated stress (manual loop and test)
- [x] New tests added and passing
- [x] Full suite passes (703 tests)
- [x] Documentation & changelog updated
- [x] Backward compatibility (additive API extension)

## 📎 Follow-Ups (Optional)
- Add metrics for restoration duration and SUBACK latency distribution
- Negative test asserting timeout path when SUBACK never arrives
- Retained capability probe abstraction to formalize pattern

---

PR Title Suggestion:
feat(mqtt): retained publish support + SUBACK-gated subscription restoration

Let me know if you'd like this merged into the existing PR body or further condensed.
