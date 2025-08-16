package TestFixture::GameData;

use v5.42;

use Exporter 'import';

our @EXPORT_OK = qw(
    sample_roll_table_data
    sample_flow_table_data
    sample_onlyif_table_data
    sample_game_save_data
    sample_complete_game_data
);

# Sample data for testing various table types and game scenarios

sub sample_roll_table_data {
    return {
        'Title' => 'Sample Roll Table',
        'table_type' => 'roll',
        'dice' => '2d6',
        'rolltype' => 'damage',
        'determines' => 'hit_location',
        'options' => [
            {
                'result' => [2, 4],
                'text' => 'Glancing blow - minimal damage',
                'set' => {'damage_type' => 'light'}
            },
            {
                'result' => [5, 8],
                'text' => 'Solid hit - moderate damage',
                'set' => {'damage_type' => 'moderate'},
                'next' => 'damage-effects-table'
            },
            {
                'result' => [9, 11],
                'text' => 'Critical hit - heavy damage',
                'set' => {'damage_type' => 'heavy'},
                'next' => 'critical-damage-table'
            },
            {
                'result' => [12, 12],
                'text' => 'Devastating hit - maximum damage',
                'set' => {'damage_type' => 'devastating'},
                'next' => 'critical-damage-table'
            }
        ]
    };
}

sub sample_flow_table_data {
    return {
        'Title' => 'Sample Mission Flow',
        'table_type' => 'Flow',
        'missions' => '25',
        'flow' => [
            {
                'pre' => 'Beginning mission briefing'
            },
            {
                'type' => 'choosemax',
                'variable' => 'Target',
                'pre' => 'Rolling for target selection',
                'post' => 'Target selected: <1>',
                'choices' => [
                    {
                        'max' => '3',
                        'Table' => 'target-easy'
                    },
                    {
                        'max' => '7',
                        'Table' => 'target-medium'
                    },
                    {
                        'max' => '10',
                        'Table' => 'target-hard'
                    }
                ]
            },
            {
                'type' => 'roll',
                'table' => 'weather-table',
                'pre' => 'Checking weather conditions'
            },
            {
                'type' => 'flow',
                'table' => 'combat-sequence',
                'pre' => 'Entering combat phase'
            },
            {
                'pre' => 'Mission complete - returning to base',
                'next' => 'mission-results'
            }
        ]
    };
}

sub sample_onlyif_table_data {
    return {
        'Title' => 'Ammunition Check',
        'table_type' => 'onlyif',
        'variable_to_test' => 'ammunition',
        'test_criteria' => '>',
        'test_against' => '0',
        'fail_message' => 'No ammunition remaining - cannot fire',
        'dice' => '1d6',
        'rolltype' => 'ammunition_consumption',
        'determines' => 'shots_fired',
        'options' => [
            {
                'result' => [1, 2],
                'text' => 'Controlled burst - 2 rounds expended',
                'set' => {'ammunition' => '$ammunition - 2'}
            },
            {
                'result' => [3, 4],
                'text' => 'Extended burst - 4 rounds expended',
                'set' => {'ammunition' => '$ammunition - 4'}
            },
            {
                'result' => [5, 6],
                'text' => 'Full auto - 6 rounds expended',
                'set' => {'ammunition' => '$ammunition - 6'}
            }
        ]
    };
}

sub sample_game_save_data {
    return {
        'game_name' => 'B-17 Queen of the Skies',
        'player_name' => 'Test Pilot',
        'mission' => [
            {
                'number' => 1,
                'target' => 'Hamburg',
                'result' => 'Success',
                'casualties' => 2,
                'damage' => 'Light',
                'completed' => 1
            },
            {
                'number' => 2,
                'target' => 'Berlin',
                'result' => 'Partial Success',
                'casualties' => 5,
                'damage' => 'Moderate',
                'completed' => 1
            }
        ],
        'current_status' => {
            'crew_experience' => 'Experienced',
            'aircraft_condition' => 'Good',
            'morale' => 'High'
        },
        'statistics' => {
            'missions_flown' => 2,
            'total_casualties' => 7,
            'successful_missions' => 1
        }
    };
}

sub sample_complete_game_data {
    return {
        'combat_table' => {
            'Title' => 'Air Combat Resolution',
            'table_type' => 'roll',
            'dice' => '2d6',
            'rolltype' => 'combat',
            'determines' => 'combat_result',
            'options' => [
                {
                    'result' => [2, 5],
                    'text' => 'Enemy fighters driven off',
                    'set' => {'combat_status' => 'clear'}
                },
                {
                    'result' => [6, 8],
                    'text' => 'Inconclusive combat',
                    'next' => 'damage-check'
                },
                {
                    'result' => [9, 12],
                    'text' => 'Heavy fighter attack',
                    'next' => 'heavy-damage-table'
                }
            ]
        },
        'damage_table' => {
            'Title' => 'Aircraft Damage',
            'table_type' => 'roll',
            'dice' => '1d6',
            'rolltype' => 'damage',
            'determines' => 'damage_location',
            'options' => [
                {
                    'result' => [1, 2],
                    'text' => 'Engine damage',
                    'set' => {'engine_status' => 'damaged'}
                },
                {
                    'result' => [3, 4],
                    'text' => 'Wing damage',
                    'set' => {'wing_status' => 'damaged'}
                },
                {
                    'result' => [5, 6],
                    'text' => 'Fuselage damage',
                    'set' => {'fuselage_status' => 'damaged'}
                }
            ]
        },
        'mission_flow' => {
            'Title' => 'Mission Sequence',
            'table_type' => 'Flow',
            'flow' => [
                {
                    'pre' => 'Takeoff and formation'
                },
                {
                    'type' => 'roll',
                    'table' => 'weather-check',
                    'pre' => 'Weather assessment'
                },
                {
                    'type' => 'roll',
                    'table' => 'fighter-encounter',
                    'pre' => 'Fighter patrol check'
                },
                {
                    'type' => 'roll',
                    'table' => 'target-approach',
                    'pre' => 'Approaching target'
                },
                {
                    'pre' => 'Mission complete - RTB'
                }
            ]
        }
    };
}

1;