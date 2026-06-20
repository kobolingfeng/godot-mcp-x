# Skeletons, IK & Bone Modifiers (4.7)

The 4.3+ **`SkeletonModifier3D`** system replaces the old single `SkeletonIK3D`
node. Modifiers are added as **children of a `Skeleton3D`** and post-process the
pose each frame. (`SkeletonIK3D` still exists but is deprecated.)

## What's available ✅ (verified `is_parent_class(x, "SkeletonModifier3D")`)

**IK solvers**: `TwoBoneIK3D`, `CCDIK3D`, `FABRIK3D`, `JacobianIK3D`,
`ChainIK3D`, `SplineIK3D`, `IterateIK3D`, `IKModifier3D`, `AimModifier3D`
**Look / aim**: `LookAtModifier3D`
**Physics-ish**: `SpringBoneSimulator3D` (jiggle/secondary motion),
`PhysicalBoneSimulator3D`
**Constraints / transfer**: `BoneConstraint3D`, `BoneTwistDisperser3D`,
`LimitAngularVelocityModifier3D`, `CopyTransformModifier3D`,
`ConvertTransformModifier3D`, `ModifierBoneTarget3D`, `RetargetModifier3D`
**XR**: `XRBodyModifier3D`, `XRHandModifier3D`

Base `SkeletonModifier3D` props: **`active: bool`**, **`influence: float`** (0–1
blend). Order matters — modifiers run top-to-bottom in the child list.

## Pattern: foot/hand IK with TwoBoneIK3D

```gdscript
# children of the Skeleton3D:
var ik := TwoBoneIK3D.new()
skeleton.add_child(ik)
# set its bone chain + target (property names vary per solver — introspect!)
```
> Property names differ per solver. **Don't guess** — use
> `describe_class {name:"TwoBoneIK3D"}` (godot-mcp-x emits full method/property
> signatures) or `ClassDB.class_get_property_list("FABRIK3D", true)`.

## Pattern: head look-at (`LookAtModifier3D`) ✅ props

`target_node: NodePath`, `bone_name: StringName`, `forward_axis`,
`primary_rotation_axis`, `use_secondary_rotation`, `origin_from`,
`duration`/`transition_type`/`ease_type` (smoothing), and angle limits
(`use_angle_limitation`, `primary_limit_angle`, `secondary_limit_angle`, …).

```gdscript
var look := LookAtModifier3D.new()
look.bone_name = "Head"
look.target_node = look.get_path_to(target)   # NodePath relative to the modifier
skeleton.add_child(look)
```

## Pattern: secondary motion (`SpringBoneSimulator3D`)

Add as a Skeleton3D child for jiggle physics on hair/cloth/tails — set up bone
chains + stiffness/drag in its properties (introspect for exact names).

## via godot-mcp-x

- `add_skeleton_modifier {path, type, name?, properties}` — add **any** of the
  above; `properties` sets bone names/targets (NodePath strings auto-converted).
- `setup_look_at_modifier {path, bone, target_path}` — LookAt convenience.
- `list_skeleton_modifiers {path}` — type/active/influence of each.
- `add_bone`, `set_bone_pose`, `reset_bone_poses`, `list_bones`,
  `add_bone_attachment` — build/pose skeletons & parent props to bones.

## Bones, poses & attachments

- `Skeleton3D`: `get_bone_count`, `find_bone(name)`, `get_bone_parent(i)`,
  `set_bone_pose_position(i, Vector3)`, `set_bone_pose_rotation(i, Quaternion)`,
  `reset_bone_poses()`. Pose = override on top of rest; reset clears it.
- `BoneAttachment3D` (child of skeleton, `bone_name`) parents a node to a bone —
  e.g. mount a weapon to the hand bone. Animations then carry the weapon along.

## Gotcha

A modifier only runs while `active` and its `influence > 0`, and it must be a
**direct child** of the `Skeleton3D`. Solvers need a valid bone chain set up — an
unconfigured solver silently does nothing.
