# DS2 manifest changes to node inputs

What changed in `scripts/manifest` (FRPG2Connect history), limited to node **inputs**: pins whose connection became
optional, and what the export writes when nothing is connected. For each one, the morpheme asset compiler builder
(`Morpheme4/morpheme/tools/assetCompiler/Core/src`) and what to check in the runtime.

"Unconnected" below means the runtime data has **no field** for that input (the manifest skips the write), unless
it says `-1` is written.

## Inputs that became optional

| Node | Input (pin) | Manifest change | Commit | Seen in | Compiler builder (`declareDataPin` optional flag) | Check in the runtime |
|---|---|---|---|---|---|---|
| **LockFoot** | `IkFkBlendWeight` (data, float) | validate no longer requires it; serialize already skipped it when unconnected | fcc3ec2 | c2170 (LockFoot_309/310) | NodeLockFootBuilder.cpp:70, optional = true | node runs with no IK/FK weight CP: confirm it uses full IK (weight 1) and not 0 |
| **LockFoot** | `SwivelContributionToOrientation` (data, float) | validate no longer requires it | 7283025 | several characters | NodeLockFootBuilder.cpp:71, optional = true | default swivel contribution used when absent |
| **FeatherBlend2** | `Weight` (data, float) | serialize writes `Weight` only when connected (it errored before, which made Connect drop the whole state) | 9b519be (write added), 4e2c931 (made optional) | c3260 (FeatherBlend2_292) | NodeFeatherBlend2Builder.cpp:80, optional = true; line 314 records `weightNodeID != INVALID_NODE_ID` | blend with no weight CP: check which source it outputs (BlendWeight_0 / _1 attributes vs weight 0) |
| **Blend2** | `Weight` (data, float) | serialize writes `Weight` only when connected | 4e2c931 | not hit yet (pre-emptive) | NodeBlend2Builder.cpp:77, optional = true | same as FeatherBlend2 |
| **BlendN** | `Weight` (data, float) | serialize writes `Weight` only when connected | 4e2c931 | not hit yet (pre-emptive) | NodeBlendNBuilder.cpp:83, optional = true | which source is active with no weight |
| **Switch** | `Weight` (data, float) | serialize writes `Weight` only when connected | 4e2c931 | not hit yet (pre-emptive) | NodeSwitchBuilder.cpp:77, optional = true | which source is selected with no weight |
| **HipsIK** | `RotationDelta` (data, euler/quat) | validate no longer requires a rotation delta input | 71390ac | DS2 HipsIK nodes without it | NodeHipsIKBuilder.cpp:128-129, optional = true | no hips rotation applied when absent |
| **TwoBoneIK** | `EffectorTarget` (data, vector3) | still **required** by validate (ad83375 removed the check, 8e1be19 restored it); serialize writes nothing when unconnected instead of `-1, pin 0` (6743973), which only matters if validation is bypassed | ad83375, 8e1be19, 6743973 | all DS2 TwoBoneIK nodes have it so far | **NodeTwoBoneIKBuilder.cpp:72, optional = false**: the stock compiler requires it too | nothing changed in practice; if a DS2 node ever targets a joint only (`UseSpecifiedJointAsTarget` + `TargetJointIndex_N`) without EffectorTarget, both validate and the compiler would reject it |
| **TwoBoneIK** | `TargetOrientation`, `SwivelAngle`, `IkFkBlendWeight`, `SwivelContributionToOrientation` (data) | serialize writes nothing when unconnected (was `-1, pin 0`) | 6743973 | most TwoBoneIK nodes | NodeTwoBoneIKBuilder.cpp:73-76, optional = true | defaults used when absent |
| **SmoothTransforms** | `Multiplier` (data, float) | serialize writes nothing when unconnected (was `-1`) | 34d4c05 | SmoothTransforms nodes without a multiplier CP | NodeSmoothTransformsBuilder.cpp:67, optional = true | smoothing strength unscaled when absent |

## Other serialize changes on the same nodes (not inputs, listed for completeness)

| Node | Change | Commit |
|---|---|---|
| TwoBoneIK | new attributes `UseSpecifiedJointAsTarget`, `UseSpecifiedJointOrientation`, `TargetJointName` (per set); writes `UseSpecifiedJointAsTarget`, `UseSpecifiedJointOrientation`, and `TargetJointIndex_N` only when a target joint is set | 4ec86cc, decdcda, 6743973, af2e121, f2ee78b |
| HipsIK | no longer writes the `FootTurnWeight` float attribute (it is the `FootTurnWeight` CP input in DS2 data) | 6743973 |
| LockFoot | no longer writes `HipIndex_N` / `KneeIndex_N` (-1) | 6743973 |
| OperatorOneInputArithmetic | new `ConstantValueX` attribute, written instead of 0 (`ConstantValueY/Z` still 0) | fcc3ec2, e4378a7 |
| Freeze | `getTransformChannels` returns the whole rig (it returned nil, which failed every channel query above a Freeze and made Connect drop states) | fd2a867 |
| AnimWithEvents | `ClipRangeMode` attribute and widget | 41ee8d8, a5fdceb |

## How the generator reflects it

mcnGen only connects an input when the game export has it, so these nodes come out of the round trip with the field
missing exactly where the game data has it missing. xmldiff reports 0 differences on the characters listed above,
which confirms Connect's export matches the game data. It does not show what the runtime does with the missing input:
that is what the "Check in the runtime" column is for.
