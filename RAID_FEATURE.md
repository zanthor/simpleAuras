# Raid Feature Documentation

## Overview
The raid feature allows you to track buffs/debuffs that you cast on raid members. This is particularly useful for tracking spells like Blessing of Kings, Mark of the Wild, or other buffs that you want to monitor on specific raid members.

## How It Works

### 1. Cast Targeting System
When you cast a spell on a raid member, the addon automatically captures which raid member received the spell. This information is stored and used to track the aura on that specific person.

### 2. Setting Up a Raid Aura

1. Create a new aura or edit an existing one
2. Set the **Unit** dropdown to **"Raid"**
3. Enter the spell name in the **Aura Name** field
4. Configure other settings as needed (duration, stacks, etc.)

**Note:** When "Raid" is selected, the Invert and Dual options are automatically hidden since they don't apply to raid tracking.

### 3. Usage Workflow

1. Set up your raid aura (e.g., "Blessing of Kings")
2. In-game, cast the spell on a raid member while they are targeted
3. The addon will remember which raid member received the spell
4. The aura will now track that specific spell on that specific raid member
5. The aura icon will show when the buff is present and hide when it's not

### 4. Multiple Targets
- You can cast the same spell on different raid members
- The addon will track the most recent target for each spell
- If you want to track different raid members for the same spell, you'll need separate auras

## Commands

- `/sa raid` or `/sa showraid` - Shows all currently tracked raid targets
- `/sa clearraid` - Clears all stored raid targets (useful for resetting)

## Requirements

- **SuperWoW is recommended** for full functionality, especially duration tracking
- Must be in a raid group for raid member detection to work
- The target must be a raid member when you cast the spell

## Limitations

- Only tracks spells that you cast yourself
- Raid member must be online and in your raid when the aura updates
- If a raid member leaves the raid, their tracking will be lost until they rejoin
- The addon uses the target at cast time, so make sure you're targeting the right person

## Example Use Cases

- **Paladins**: Track Blessing of Kings, Blessing of Wisdom, etc. on specific raid members
- **Druids**: Monitor Mark of the Wild on key players
- **Priests**: Track Power Word: Fortitude or Divine Spirit on important targets
- **Any Class**: Monitor debuffs you apply to raid members for coordination

## Tips

- Use descriptive aura names that include the target if you have multiple auras for the same spell
- The raid target is captured at spell cast time, so target the person you want to track before casting
- Use `/sa showraid` to see which raid members are currently being tracked for which spells
- If tracking seems inconsistent, try `/sa clearraid` and re-establish your targets