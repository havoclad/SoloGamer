# B-17 Queen of the Skies - Implementation Plan

## Executive Summary
**STATUS: BASE GAME COMPLETE (100%)**

All tables from the original B-17 Queen of the Skies board game rulebook have been successfully implemented. The game features complete fighter combat, damage resolution, crew casualty mechanics, emergency procedures, and 25-mission campaign capability. This document tracks the historical development and serves as a reference for the implementation phases completed.

## Phase 1: Critical Fighter Combat System (B-3 through B-7) ✅ COMPLETE
**Priority: CRITICAL - Game is unplayable without these**

1. **Add PDF to .gitignore** ✅
   - Added `games/QotS/rules/B-17 - Queen of the Skies_text.pdf` to prevent uploading copyrighted material

2. **B-3: Attacking Fighter Waves** ✅
   - Created `B-3.json` with 2D6 roll table (rolls 11-66)
   - Implemented fighter types (Me109, Me110, FW190) and attack positions
   - Included special attacks (Vertical Dive, Vertical Climb)
   - Added "No Attackers" results and random events trigger (66)

3. **B-4: Shell Hits By Area** ✅
   - Created `B-4.json` for determining number of shell hits per attack position
   - Implemented position-based hit tables (12/1:30/10:30, 3/9, 6, Vertical Dive/Climb)
   - Added fighter type modifiers (FW190 x1.5 rounded down, Me110 +1)

4. **B-5: Area Damage Tables** ✅
   - Created `B-5.json` for hit location determination with complex nested structure
   - Implemented attack angle matrices (High/Level/Low from each position)
   - Added "Walking Hits" special damage patterns (Types A, B, C)
   - Included "Superficial Damage" results and specific compartment hits

5. **B-6: Successive Attacks** ✅
   - Created `B-6.json` for follow-up attack positions
   - Fighters that hit get additional attacks (max 3 total: 1 initial + 2 successive)
   - Includes detailed rules for successive attack positioning

6. **B-7: Random Events** ✅
   - Created `B-7.json` with comprehensive special events table
   - Engine failures, formation changes, weather effects, friendly fighter effects
   - Complex conditional events with mission-long modifiers

### Critical Special Conditions Identified:
**Fighter Type Modifiers:**
- FW190: Shell hits × 1.5 (rounded down)
- Me110: Shell hits +1
- All fighters can potentially make successive attacks

**Walking Hits Mechanics:**
- Type A: Hits all 6 fuselage sections (Nose, Pilot, Bomb Bay, Radio, Waist, Tail)
- Type B: 2 hits on each wing (4 total hits)
- Type C: Hits 4 sections (Nose, Wing-attacking side, Waist, Tail)
- Walking hits negate all other shell hits from that fighter

**Successive Attack Chain:**
- Any fighter scoring a hit gets another attack (new position via B-6)
- Second successive attack possible if second attack hits
- Maximum 3 attacks total per fighter per wave
- Fighter cover applies after positioning but before second/third attacks

**Random Events State Changes:**
- Engine failures (can restart if rolled again)
- Formation position changes (Lead/Tail bomber with combat modifiers)
- Formation tightness (+/-1 to B-1/B-2 rolls for remainder of mission)
- Friendly fighter effectiveness (+1 to M-4 rolls)
- Equipment effects (gun jamming, rabbit's foot luck)
- Mission abort conditions (mid-air collisions, steep dives)

## Phase 2: Defensive Fire System (M-series tables) ✅ COMPLETE
**Priority: CRITICAL - Combat resolution impossible without these**

7. **M-1: B-17 Defensive Fire** ✅
   - Created `M-1.json` with gun position vs fighter position matrix
   - Implemented field of fire restrictions for each gun position
   - Added tail gun special rules for passing shots

8. **M-2: Hit Damage Against German Fighter** ✅
   - Created `M-2.json` for fighter damage results
   - FCA (Fighter Continues Attack), FBOA (Fighter Breaks Off), Destroyed
   - Included twin gun bonuses and cumulative damage rules

9. **M-3: German Offensive Fire** ✅
   - Created `M-3.json` for fighter hit determination
   - Included damage state modifiers and attack position variations
   - Implemented fighter type hit probabilities

10. **M-4: Fighter Cover Defense** ✅
    - Created `M-4.json` for friendly fighter assistance
    - Poor/Fair/Good cover drives off enemy fighters
    - Separate values for initial vs successive attacks

11. **M-5: B-17 Area Spray Fire** (Optional) ✅
    - Created `M-5.json` for spray fire mechanics
    - Included gun jamming risks and repair procedures

12. **M-6: Fighter Pilot Status** ✅
    - Created `M-6.json` for Ace/Green pilot determination
    - Optional rule for enhanced combat realism

## Phase 3: Damage Resolution System (P-series and BL-series) ✅ COMPLETE
**Priority: HIGH - Determines mission outcomes**

13. **P-1: Nose Compartment Damage** ✅
    - Created `P-1.json` with specific damage effects
    - Bombardier/Navigator wounds, equipment damage

14. **P-2: Pilot Compartment Damage** ✅
    - Created `P-2.json` for pilot/copilot wounds, control damage

15. **P-3: Bomb Bay Damage** ✅
    - Created `P-3.json` including bomb detonation risks

16. **P-4: Radio Room Damage** ✅
    - Created `P-4.json` for radio operator and equipment

17. **P-5: Waist Section Damage** ✅
    - Created `P-5.json` for waist gunner casualties

18. **P-6: Tail Section Damage** ✅
    - Created `P-6.json` for tail gunner and control surfaces

19. **BL-1: Wings** ✅
    - Created `BL-1.json` for comprehensive wing damage
    - Engine damage, fuel tank hits, control surfaces

20. **BL-2: Instruments** ✅
    - Created `BL-2.json` for navigation and control instruments

21. **BL-3: Hand Held Extinguishers** ✅
    - Created `BL-3.json` for fire fighting mechanics

22. **BL-4: Wounds** ✅
    - Created `BL-4.json` for crew casualty determination
    - Light/Serious/KIA results

23. **BL-5: Frostbite** ✅
    - Created `BL-5.json` for cold exposure effects

## Phase 4: Bailout and Special Landing Tables ✅ COMPLETE
**Priority: MEDIUM - For complete game experience**

24. **G-6: Controlled Bailout** ✅
    - Created `G-6.json` for orderly crew evacuation
    - Individual crew member survival rolls
    - Geographic capture/rescue mechanics

25. **G-7: Bailout from Uncontrolled Plane** ✅
    - Created `G-7.json` for emergency bailout
    - Reduced survival chances for uncontrolled bailout
    - Light wound modifiers

26. **G-8: Bailout Over Water** ✅
    - Created `G-8.json` for water survival
    - Drowning mechanics and radio dependency
    - Rescue probability system

27. **G-10: Landing in Water** ✅
    - Created `G-10.json` for ditching mechanics
    - Comprehensive landing modifiers
    - Crew survival and capture mechanics

## Phase 5: Integration and Game Flow Updates ✅ COMPLETE
**Priority: HIGH - Ties everything together**

28. **Update FLOW files** ✅
    - Created `FLOW-zone-movement.json` for zone traversal with combat checks
    - Created `FLOW-fighter-combat.json` for complete combat sequence
    - Created `FLOW-fighter-attack.json` for individual fighter attacks
    - Created `FLOW-damage-resolution.json` for damage application
    - Created `FLOW-successive-attacks.json` for successive attack chains

29. **Implement Variable Tracking** ✅
    - Created `AircraftState` class for damage states (engines, controls, fuel, guns, structural)
    - Created `CombatState` class for transient combat tracking (waves, fighters, ace tracking)
    - Enhanced `CrewMember` with wounds, frostbite, and position tracking
    - Integrated state objects into `SaveGame` with full serialization support

30. **Create Combat Resolution Flow** ✅
    - Fighter wave generation → Fighter cover → Defensive fire → Fighter attacks → Damage resolution → Successive attacks
    - Complete state management throughout combat sequences
    - Comprehensive test coverage for all new classes

## Implementation Guidelines

### JSON Structure Standards:
```json
{
  "Title": "Table Name",
  "table_type": "roll|onlyif|flow",
  "rolltype": "2d6|d6d6|1d6",
  "determines": "variable_name",
  "rolls": {
    "roll_value": {
      "result": "value",
      "description": "text",
      "next": "NEXT-TABLE",
      "notes": []
    }
  }
}
```

### Testing Protocol:
1. Implement each table with exact roll ranges from rules
2. Test individual table rolls
3. Test complete combat sequences
4. Validate damage accumulation
5. Run full 25-mission campaigns

## Success Criteria - ✅ ALL ACHIEVED
- ✅ All tables from the PDF rules implemented with 100% accuracy
- ✅ Complete fighter combat from appearance to resolution
- ✅ Proper damage accumulation affecting subsequent gameplay
- ✅ Crew casualties and replacements working correctly
- ✅ Full 25-mission campaigns playable with historical accuracy

## Complete Implementation Summary

### All Base Game Tables Implemented (46 tables):

**G-Series - Mission Tables (11 tables):**
- ✅ G-1, G-2, G-3: Mission target selection
- ✅ G-4, G-4a: Formation positions
- ✅ G-5: Fighter cover
- ✅ G-6, G-7, G-8: Bailout procedures (controlled, uncontrolled, water)
- ✅ G-9: Landing on land
- ✅ G-10: Landing in water (ditching)
- ✅ G-11: Flight Log Gazetteer

**O-Series - Operations (7 tables):**
- ✅ O-1 through O-7: Weather, flak, and bombing

**B-Series - Fighter Combat (7 tables):**
- ✅ B-1, B-2: Fighter wave determination
- ✅ B-3: Attacking Fighter Waves
- ✅ B-4: Shell Hits By Area
- ✅ B-5: Area Damage Tables
- ✅ B-6: Successive Attacks
- ✅ B-7: Random Events

**M-Series - Defensive Fire (6 tables):**
- ✅ M-1: B-17 Defensive Fire
- ✅ M-2: Hit Damage Against German Fighter
- ✅ M-3: German Offensive Fire
- ✅ M-4: Fighter Cover Defense
- ✅ M-5: B-17 Area Spray Fire (Optional)
- ✅ M-6: Fighter Pilot Status (Optional)

**P-Series - Compartment Damage (6 tables):**
- ✅ P-1 through P-6: All compartment damage tables

**BL-Series - Generic Damage (5 tables):**
- ✅ BL-1: Wings Damage
- ✅ BL-2: Instruments Damage
- ✅ BL-3: Hand Held Extinguishers
- ✅ BL-4: Wounds System
- ✅ BL-5: Frostbite System

**FLOW Tables - Game Flow (7+ tables):**
- ✅ Complete mission flow integration
- ✅ Zone movement with combat
- ✅ Fighter combat sequences
- ✅ Damage resolution chains

**State Management Classes:**
- ✅ AircraftState: Comprehensive damage tracking
- ✅ CombatState: Transient combat management
- ✅ Enhanced CrewMember: Complete crew tracking

## Phase 6: Combat System Integration ✅ COMPLETE
**Priority: CRITICAL - Makes all previous work functional**

31. **Fighter Cover Integration** ✅
    - Added G-5 fighter cover roll to mission flow
    - Converted M-4 to standard table_input format
    - Fighter cover now properly drives off attackers

32. **Zone Combat Processing** ✅
    - Created zone_process method in Game.pm
    - Integrated B-1 for fighter wave generation
    - Connected B-3 for fighter composition
    - Fixed table determines fields for proper data flow

33. **Defensive Fire Resolution** ✅
    - Implemented M-1 gun position lookups
    - Added M-2 damage resolution (FCA/FBOA/Destroyed)
    - Guns successfully hit and damage/destroy fighters
    - Fixed M-2 determines field alignment

34. **Fighter Attack Resolution** ✅
    - Implemented M-3 position-based hit determination
    - Added attack category mapping for positions
    - Applied FCA damage modifiers to attacks
    - B-17 now takes hits from fighters

### All Phases Complete:
All core game tables and state management have been implemented and integrated! The game now includes functional fighter combat with defensive fire, damage resolution, crew management, emergency procedures, and advanced state tracking systems all working together during missions.

This implementation has transformed the basic framework into a fully playable B-17 bomber simulation with actual combat occurring during missions.

## Next Steps
1. ✅ Add PDF to .gitignore - COMPLETE
2. ✅ Phase 1: Fighter Combat Tables - COMPLETE
3. ✅ Phase 2: Defensive Fire System - COMPLETE
4. ✅ Phase 3: Damage Resolution System - COMPLETE
5. ✅ Phase 4: Bailout and Emergency Landing - COMPLETE
6. ✅ Phase 5: State Management & Integration - COMPLETE
7. ✅ Phase 6: Combat System Integration - COMPLETE

## Optional Enhancement Ideas

**Note:** All base game features are complete. The following are potential enhancements not present in the original board game:

### High Value Additions
1. **Crew Experience System** - Green/Veteran progression with skill modifiers
2. **Historical Scenarios** - Pre-scripted missions based on actual raids
3. **Enhanced Mission Reports** - Detailed statistics and combat logs
4. **Achievement Tracking** - Notable milestones and records

### Medium Value Additions
5. **Navigation Uncertainty** - Random off-course events
6. **Crew Personality System** - Individual traits and morale
7. **Advanced Repair Mechanics** - Between-mission maintenance decisions
8. **Campaign Statistics Dashboard** - Long-term tracking and visualization

### Already Completed Enhancements
- ✅ P-series damage tables connected to AircraftState
- ✅ Kill credits awarded to crew members
- ✅ Successive attacks using B-6 table
- ✅ Complete state persistence in save/load system

---

*Document Created: 2025-08-11*
*Last Updated: 2025-11-02 (Documentation Cleanup - 100% Base Game Complete)*
*Based on analysis of B-17 Queen of the Skies rulebook and current implementation status*

**FINAL STATUS: All phases complete. Base game is production-ready and fully playable.**