# simpleAuras Changelog

## Version 1.1 (December 14, 2025)

### Improvements
- **Enhanced Debuff Detection**: Significantly improved debuff tracking reliability by implementing GUID-based scanning (inspired by Cursive addon)
  - Primary aura scanning now uses GUID-based `UnitDebuff(guid, i)` calls when available, which is more reliable than unit token scanning
  - Added automatic GUID tracking system that monitors `PLAYER_TARGET_CHANGED`, `UNIT_COMBAT`, and `UNIT_MODEL_CHANGED` events
  - Implemented fallback mechanism that searches all tracked GUIDs when primary scan fails
  - Increased scan limit to 64 iterations (matching pfUI and Cursive) for more comprehensive aura detection

### Technical Details
- Added `sA.trackedGUIDs` table to maintain recently encountered units (auto-cleanup after 30 seconds)
- Enhanced `find_aura()` function with GUID detection and proper 0x prefix handling
- Added `find_spell_on_tracked_guids()` helper function for enhanced fallback scanning
- Updated `GetSuperAuraInfos()` to utilize tracked GUID fallback when initial scan misses auras
- All improvements activate only when SuperWoW is available; maintains full backward compatibility

### Bug Fixes
- Fixed issue where debuffs would not be detected on targets during rapid target switching
- Fixed timing-related issues where debuffs visible in pfUI were missed by simpleAuras
- Improved reliability of debuff detection on units that appear in combat log but aren't currently targeted

### Performance
- GUID-based lookups are actually faster than repeated unit token lookups
- Optimized scan iterations to reduce redundant checks
- Efficient GUID cleanup prevents memory bloat from old tracked units

### Compatibility
- Fully compatible with existing simpleAuras configurations
- No changes required to user settings or saved variables
- Works seamlessly with SuperWoW, nampower, and UnitXP enhancements
- Maintains vanilla functionality for non-SuperWoW installations

---

## Version 1.0

### Initial Features
- Simple aura display system with customizable positioning
- Support for buffs, debuffs, and cooldown tracking
- SuperWoW integration for enhanced spell ID detection
- nampower integration for faster spell lookups
- UnitXP integration for directional aura triggers
- Aura duration learning and tracking
- Raid target support
- Combat/out-of-combat conditional display
- Raid/party conditional display
- Configurable refresh rates
- Debug mode for troubleshooting
