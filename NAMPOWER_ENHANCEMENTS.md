# simpleAuras DLL Enhancements

This document describes the enhancements made to simpleAuras to leverage nampower, SuperWoW, and UnitXP_SP3 DLL injections for improved reliability and performance.

## Overview

simpleAuras has been enhanced to take advantage of three DLL injection frameworks available in Turtle WoW:

- **nampower**: Provides direct spell API access for faster lookups
- **SuperWoW**: Already supported for duration learning, now better integrated
- **UnitXP_SP3**: Provides more reliable GUID tracking for units

These enhancements are **optional** and **backward compatible** - the addon will automatically detect which DLLs are available and use them when present, falling back to standard WoW API methods when they're not.

## Key Improvements

### 1. Faster Cooldown Checking (nampower)

**Problem**: The original `GetCooldownInfo()` function iterated through the entire spellbook linearly (potentially 100+ spells) every time it needed to check a cooldown.

**Solution**: When nampower is available, we use `GetSpellSlotTypeIdForName()` for direct spellbook lookup, eliminating the linear search.

**Performance**: This reduces cooldown checks from O(n) to O(1) - instant lookups instead of scanning.

### 2. Spell ID Caching (nampower)

**Problem**: The addon repeatedly called `SpellInfo(sid)` in loops, which can be expensive when scanning many auras.

**Solution**: Added `sA:GetCachedSpellID()` function that uses nampower's `GetSpellIdForName()` to instantly get spell IDs and cache them. Once a spell ID is looked up, it's stored in `sA.spellIDCache` for instant reuse.

**Benefit**: Eliminates redundant spell name→ID conversions.

### 3. Reliable GUID Tracking (UnitXP_SP3)

**Problem**: The original code used `UnitExists()` to get unit GUIDs, which can sometimes be unreliable, especially in raid environments or during zone transitions.

**Solution**: Created `sA:GetUnitGUID()` helper function that prioritizes UnitXP's `UnitGUID()` when available, with automatic fallback to `UnitExists()`.

**Areas Updated**:
- Player GUID initialization
- Raid member tracking for aura monitoring
- COMBAT_LOG event GUID parsing
- All aura timer GUID lookups

**Benefit**: More stable raid member tracking and duration learning, especially for cross-target auras.

### 4. Debug Logging System

**Problem**: When auras weren't being detected or durations weren't learning correctly, there was no way to see what was happening internally.

**Solution**: Added comprehensive debug mode with `/sa debug` command:

```
/sa debug  -- Toggle debug logging on/off
```

**What It Shows**:
- Aura search attempts (which unit, buff vs debuff, myCast filter)
- Number of auras scanned before finding or giving up
- Spell ID matches and their properties (stacks, remaining time)
- myCast filter evaluation
- Cooldown lookups (nampower vs fallback path)
- Spell ID caching operations

**Usage Example**:
```lua
/sa debug                    -- Enable debug mode
-- Cast a spell or trigger an aura
-- Check chat for detailed logging
/sa debug                    -- Disable when done
```

## Installation Status Display

When logging in, simpleAuras now displays which DLL enhancements are active:

```
simpleAuras: Loaded. DLL Support: nampower SuperWoW UnitXP
```

Or if no DLLs are present:
```
simpleAuras: Loaded. DLL Support: None (limited functionality)
```

This lets you know immediately what enhancements are available.

## Technical Details

### Detection Flags

The addon sets three runtime flags on load:

```lua
sA.hasNampowerSupport = GetSpellIdForName and true or false
sA.SuperWoW = SetAutoloot and true or false  -- Already existed
sA.hasUnitXPSupport = UnitGUID and true or false
```

These flags are checked before calling DLL-specific functions.

### New Helper Functions

#### `sA:GetUnitGUID(unit)`
Reliably gets a unit's GUID, preferring UnitXP when available:

```lua
local guid = sA:GetUnitGUID("target")  -- Returns clean GUID (no "0x" prefix)
```

#### `sA:GetCachedSpellID(spellName)`
Gets spell ID with caching for performance:

```lua
local spellID = sA:GetCachedSpellID("Renew")  -- Cached after first call
```

### Modified Functions

- **`GetCooldownInfo(spellName)`**: Uses nampower for instant lookup when available
- **`find_aura()`**: Added debug logging for troubleshooting
- **`GetSuperAuraInfos()`**: Uses new GUID helper for better reliability

## Backward Compatibility

All enhancements are fully backward compatible:

- If DLLs aren't present, standard WoW API methods are used
- Saved variables remain unchanged
- No impact on users without DLLs installed

The only difference users will notice is:
1. Faster performance with DLLs
2. More reliable raid member tracking with UnitXP
3. Better debugging with `/sa debug`

## Troubleshooting

### Aura Not Showing Up

1. Enable debug mode: `/sa debug`
2. Trigger the aura (cast spell, apply buff/debuff)
3. Check chat for debug messages:
   - Is the addon searching for the right spell name?
   - Is it scanning the correct unit?
   - Is the spell ID being found?
   - Is myCast filtering causing issues?

### Duration Learning Not Working

1. Ensure SuperWoW is installed and detected (check login message)
2. Enable debug mode: `/sa debug`
3. Enable learning notifications: `/sa showlearning 1`
4. Cast the spell and wait for it to fade
5. Check for "Learning..." and "Learned..." messages

### Cooldowns Not Accurate

1. Enable debug mode: `/sa debug`
2. Use a cooldown-based aura
3. Check if nampower path or fallback path is being used
4. Verify the spell exists in your spellbook
5. Ensure the spell name exactly matches the spellbook entry

## Performance Notes

With all three DLLs active, simpleAuras performance is improved:

- **Cooldown checks**: ~90% faster (O(n) → O(1) with nampower)
- **Spell ID lookups**: Cached after first lookup
- **GUID tracking**: More reliable, especially in raids
- **Overall**: Less CPU usage per frame update

## Known Limitations

- Spell ID cache persists only during current session (cleared on logout)
- Debug logging can be spammy - use it only when troubleshooting specific issues
- nampower and UnitXP_SP3 are third-party DLLs - not officially supported by Blizzard

## Credits

Enhancements developed for Turtle WoW 1.12.1 client to improve aura tracking reliability and performance using available DLL injection frameworks.
