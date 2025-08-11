# B-17 Queen of the Skies - Complete Implementation Plan

## Executive Summary
After analyzing the PDF rules and comparing with the current implementation, I've identified 47+ critical tables missing from the game. The current implementation has the basic game flow and mission structure but lacks the entire fighter combat system, damage resolution, and crew casualty mechanics that form the heart of the game.

## Phase 1: Critical Fighter Combat System (B-3 through B-7)
**Priority: CRITICAL - Game is unplayable without these**

1. **Add PDF to .gitignore**
   - Add `games/QotS/rules/B-17 - Queen of the Skies_text.pdf` to prevent uploading copyrighted material

2. **B-3: Attacking Fighter Waves** 
   - Create `B-3.json` with 2D roll table (rolls 11-66)
   - Implement fighter types (Me109, Me110, FW190) and attack positions
   - Include special attacks (Vertical Dive, Vertical Climb)
   - Add "No Attackers" results and random events trigger (66)

3. **B-4: Shell Hits By Area**
   - Create `B-4.json` for determining number of shell hits
   - Implement position-based hit tables (12/1:30/10:30, 3/9, 6, Vertical Dive/Climb)
   - Add fighter type modifiers (FW190 x1.5, Me110 +1)

4. **B-5: Area Damage Tables**
   - Create `B-5.json` for hit location determination
   - Implement attack angle matrices (High/Level/Low from each position)
   - Add "Walking Hits" special damage patterns

5. **B-6: Successive Attacks**
   - Create `B-6.json` for follow-up attack positions
   - Fighters that hit get additional attacks (max 3 total)

6. **B-7: Random Events**
   - Create `B-7.json` with special events table
   - Engine failures, formation changes, weather effects, etc.

## Phase 2: Defensive Fire System (M-series tables)
**Priority: CRITICAL - Combat resolution impossible without these**

7. **M-1: B-17 Defensive Fire**
   - Create `M-1.json` with gun position vs fighter position matrix
   - Implement field of fire restrictions for each gun position

8. **M-2: Hit Damage Against German Fighter**
   - Create `M-2.json` for fighter damage results
   - FCA (Fighter Continues Attack), FBOA (Fighter Breaks Off), Destroyed

9. **M-3: German Offensive Fire**
   - Create `M-3.json` for fighter hit determination
   - Include damage state modifiers

10. **M-4: Fighter Cover Defense**
    - Create `M-4.json` for friendly fighter assistance
    - Poor/Fair/Good cover drives off enemy fighters

11. **M-5: B-17 Area Spray Fire** (Optional)
    - Create `M-5.json` for spray fire mechanics

12. **M-6: Fighter Pilot Status**
    - Create `M-6.json` for Ace/Green pilot determination

## Phase 3: Damage Resolution System (P-series and BL-series)
**Priority: HIGH - Determines mission outcomes**

13. **P-1: Nose Compartment Damage**
    - Create `P-1.json` with specific damage effects
    - Bombardier/Navigator wounds, equipment damage

14. **P-2: Pilot Compartment Damage**
    - Create `P-2.json` for pilot/copilot wounds, control damage

15. **P-3: Bomb Bay Damage**
    - Create `P-3.json` including bomb detonation risks

16. **P-4: Radio Room Damage**
    - Create `P-4.json` for radio operator and equipment

17. **P-5: Waist Section Damage**
    - Create `P-5.json` for waist gunner casualties

18. **P-6: Tail Section Damage**
    - Create `P-6.json` for tail gunner and control surfaces

19. **BL-1: Wings**
    - Create `BL-1.json` for comprehensive wing damage
    - Engine damage, fuel tank hits, control surfaces

20. **BL-2: Instruments**
    - Create `BL-2.json` for navigation and control instruments

21. **BL-3: Hand Held Extinguishers**
    - Create `BL-3.json` for fire fighting mechanics

22. **BL-4: Wounds**
    - Create `BL-4.json` for crew casualty determination
    - Light/Serious/KIA results

23. **BL-5: Frostbite**
    - Create `BL-5.json` for cold exposure effects

## Phase 4: Bailout and Special Landing Tables
**Priority: MEDIUM - For complete game experience**

24. **G-6: Controlled Bailout**
    - Create `G-6.json` for orderly crew evacuation

25. **G-7: Bailout from Uncontrolled Plane**
    - Create `G-7.json` for emergency bailout

26. **G-8: Bailout Over Water**
    - Create `G-8.json` for water survival

27. **G-10: Landing in Water**
    - Create `G-10.json` for ditching mechanics

## Phase 5: Integration and Game Flow Updates
**Priority: HIGH - Ties everything together**

28. **Update FLOW files**
    - Modify `FLOW-start.json` to include zone movement with fighter encounters
    - Create `FLOW-zone-movement.json` for each zone traversal
    - Create `FLOW-fighter-combat.json` for complete combat sequence
    - Update `FLOW-target-zone.json` to include fighter attacks before/after bombing

29. **Implement Variable Tracking**
    - Track damage states (engines out, controls damaged, fuel leaks)
    - Track crew states (wounds, frostbite, positions)
    - Track ammunition counts for each gun position
    - Track fighter kills for ace gunner status

30. **Create Combat Resolution Flow**
    - Fighter wave generation → Fighter cover → Defensive fire → Fighter attacks → Damage resolution → Successive attacks

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

## Estimated Completion Time
- Phase 1: 2-3 days (Critical for basic combat)
- Phase 2: 2 days (Required for combat resolution)
- Phase 3: 3-4 days (Complex damage systems)
- Phase 4: 1 day (Bailout mechanics)
- Phase 5: 2 days (Integration and testing)

**Total: 10-12 days for complete implementation**

## Success Criteria
- All tables from the PDF rules implemented with 100% accuracy
- Complete fighter combat from appearance to resolution
- Proper damage accumulation affecting subsequent gameplay
- Crew casualties and replacements working correctly
- Full 25-mission campaigns playable with historical accuracy

## Critical Missing Tables Summary

### Currently Implemented (19 tables):
- ✅ G-1, G-2, G-3: Mission target selection
- ✅ G-4, G-4a: Formation positions
- ✅ G-5: Fighter cover
- ✅ G-9: Landing on land
- ✅ G-11: Flight Log Gazetteer
- ✅ O-1 through O-7: Weather, flak, and bombing
- ✅ B-1, B-2: Fighter wave determination
- ✅ FLOW tables: Basic game flow

### Critical Missing Tables (28+ tables):
- ❌ B-3 through B-7: Fighter combat core
- ❌ M-1 through M-6: Defensive fire system
- ❌ P-1 through P-6: Damage by compartment
- ❌ BL-1 through BL-5: Wings and crew wounds
- ❌ G-6, G-7, G-8, G-10: Bailout and ditching

This implementation will transform the current basic framework into a fully playable, historically accurate B-17 bomber simulation matching the original board game rules.

## Next Steps
1. Add PDF to .gitignore
2. Begin Phase 1 with B-3 table implementation
3. Test each table individually before integration
4. Implement combat flow integration
5. Run comprehensive testing with full missions

*Document Created: 2025-08-11*
*Based on analysis of B-17 Queen of the Skies rulebook and current implementation status*