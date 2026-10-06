# Runtime check: do the changed nodes still treat the inputs as required?

Source: `Morpheme4/morpheme/SDK/core` (read only, nothing changed). Paths below are relative to `SDK/core/src`.

How the runtime reads a control parameter input, which decides whether a missing connection is safe:

| Call | Missing connection (`m_sourceNodeID == INVALID_NODE_ID`) |
|---|---|
| `Network::updateOptionalInputCPConnection` | returns NULL (safe) |
| `Network::updateInputCPConnection` | no check: `updateOutputCPAttribute` → `getNodeBin(INVALID_NODE_ID)`, out-of-range bin, crash or garbage |
| `TaskAddOptionalInputCP` + task reading `getOptionalInputAttrib` / `getInputAttrib` and null-checking | safe (`validateTaskParam` only asserts a non-optional param) |
| `TaskAddInputCP`, or a task dereferencing the attrib without a null check | required |

## Summary

| Node / input (manifest change) | Verdict | Where |
|---|---|---|
| **LockFoot** `IkFkBlendWeight` | **optional** | update `updateOptionalInputCPConnection` (Nodes/mrNodeLockFoot.cpp:30); both queue fns `TaskAddOptionalInputCP` (:122, :177); task falls back to `m_defaultFkIkWeight` when NULL (mrFootLockIKTasks.cpp:60-63) |
| **LockFoot** `SwivelContributionToOrientation` | **optional** | same (:31, :125, :180); falls back to `m_defaultSwivelContributionToOrientation` (mrFootLockIKTasks.cpp:66-69) |
| **TwoBoneIK** `TargetOrientation`, `SwivelAngle`, `IkFkBlendWeight`, `SwivelContributionToOrientation` | **optional** | update all `updateOptionalInputCPConnection` (Nodes/mrNodeTwoBoneIK.cpp:29-41); queue `TaskAddOptionalInputCP` (:142-154); task null-checks each (mrTwoBoneIKTasks.cpp:77, 114, 120) |
| **TwoBoneIK** `EffectorTarget` (still required in the manifest) | **required** | task dereferences it unconditionally (mrTwoBoneIKTasks.cpp:99, :110); consistent with the manifest and the compiler |
| **SmoothTransforms** `Multiplier` | **optional** | `TaskAddOptionalInputCP` (Nodes/mrNodeSmoothTransforms.cpp:124); task uses 1.0 when NULL (mrCommonTasks.cpp:2584-2586) |
| **HipsIK** `RotationDelta` (quat / euler) | **optional** | `TaskAddOptionalInputCP` (Nodes/mrNodeHipsIK.cpp:74, 78, 151, 155); task uses identity when both are NULL (mrHipsIKTasks.cpp:264-281, 343-360) |
| **Blend2** `Weight` | **required** | `nodeBlend2UpdateConnectionsBase` calls `updateInputCPConnection(getInputCPConnection(0))` and reads `->m_value` (Nodes/mrNodeBlend2.cpp:699-700); the builder has no "weight not connected" variant (NodeBlend2Builder.cpp:226-255) |
| **BlendN** `Weight` | **required** | `nodeBlendNUpdateConnections`, `updateInputCPConnection` + `->m_value` (Nodes/mrNodeBlendN.cpp:184-196) |
| **Switch** `Weight` | **required** | `NMP_ASSERT(getNumInputCPConnections() > 0)` then `updateInputCPConnection` + `->m_value` (Nodes/mrNodeSwitch.cpp:121-128) |
| **FeatherBlend2** `Weight` | **handled by the builder, but see note** | the compiler picks `nodeFeatherBlend2UpdateConnectionsFixBlendWeight` / `...SyncEventsUpdateConnectionsFixBlendWeight` when `Weight` is unconnected (NodeFeatherBlend2Builder.cpp:303-356): blend weight fixed to 1 |

## Notes

* **FeatherBlend2 with no Weight**: the compiler creates no control parameter for the fixed weight; the CP slot it
  declares (NodeFeatherBlend2Builder.cpp:168) is initialised to `INVALID_NODE_ID` (core/src/mrNodeDef.cpp:134) and only
  filled when the export has a `Weight` field (assetProcessor NodeBuilderUtils.h, `processCPConnectionDetails`). The
  fixed weight lives only in the update-connections functions:
  * `nodeFeatherBlend2SyncEventsUpdateConnectionsFixBlendWeight` (match events) never touches the CP: safe.
  * `nodeFeatherBlend2UpdateConnectionsFixBlendWeight` (no time stretch) still reads CP connection 0 as the events blend
    weight when `getNumInputCPConnections() > 0`, which is always 1, with `updateInputCPConnection` (no INVALID check)
    (Nodes/mrNodeFeatherBlend2.cpp:359-365): with no `Weight` it reads an invalid connection. This is the one place to make
    optional (`updateOptionalInputCPConnection`, keep `blendWeightEvents = 1` when NULL).
  * (Correction: the `RuntimeNodeID` values seen on FeatherBlend2_291/292 belong to transition conditions the node holds,
    not to a node input.)
* **Blend2, BlendN, Switch** were only changed pre-emptively in the manifest (no character has hit them). With the stock
  runtime an unconnected `Weight` on these nodes would read an invalid connection, so if a character ever needs it, the
  DS2 runtime must handle it differently from this SDK.
* **HipsIK, not changed in the manifest but worth knowing**: `PositionDelta` (index 5), `FootTurnWeight` (8) and `Weight` (9)
  are dereferenced without a null check in both tasks (mrHipsIKTasks.cpp:260-290, 339-368), and the transforms queue
  function reads `Weight` with `updateInputCPConnection` (Nodes/mrNodeHipsIK.cpp:31). `PositionDelta` is even queued as
  required (`TaskAddInputCP`, :70) in that function. The trajectory variant checks `Weight` for INVALID first (:100).
