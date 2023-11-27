
M9_bbMaxRange = 10;
M9_bbDmgMultiplier = 1;
M9_bbFOV = 90;
M9_safeZoneRadius = 32;

M9_fnc_getOppositeAngle = {
    params ["_angle"];
    comment "// Add 180 degrees to the original angle";
    private _oppositeAngle = _angle + 180;
    comment "// Ensure the result is within the range [0, 360)";
    if (_oppositeAngle >= 360) then {
        _oppositeAngle = _oppositeAngle - 360;
    };
    _oppositeAngle;
};

M9_fnc_inSafeZone = {
	params [['_unit', objNull]];
	private _nObjs = _unit nearObjects 128;
	private _zones = [];
	private _zTypes = ['ProtectionZone_F', 'ProtectionZone_Invisible_F'];
	{
		if !(typeof _x in _zTypes) then {continue};
		if (_unit distance2D _x <= M9_safeZoneRadius) then {
			_zones pushBack _x;
		};
	} forEach _nObjs;
	if (_zones isEqualTo []) exitWith {false};
	true;
};

comment "[player] call M9_fnc_inSafeZone;";

M9_fnc_calcBblastDmg = {
	params [['_distance', M9_bbMaxRange]];
	private ['_maxDamage','_maxLethalDistance','_minDistance','_clampedDistance','_damage'];
    _maxDamage = 1.0;  comment "# Maximum damage at point-blank range";
    _maxLethalDistance = 2.0;  comment "# Maximum distance for full lethal damage";
    _maxEffectDistance = M9_bbMaxRange;  comment "# Distance for zero damage";
    if (_distance <= _maxLethalDistance) exitWith {
		_damage = _maxDamage * M9_bbDmgMultiplier;
		comment "DEBUG: systemChat str(_damage);";
		_damage;
	};
	comment "# Calculate the linear dmg drop-off";
	_damage = linearConversion [2.0, _maxEffectDistance, _distance, 0.0, 1.0] * M9_bbDmgMultiplier;
	systemChat str(_damage);
    _damage;
};

M9_fnc_getBblastTargets = {
	params [['_shooter', objNull]];
	private ['_bbtards', '_backBlastTargets'];
	comment "Get units within range";
	_bbtards = nearestObjects [_shooter, ['Man'], M9_bbMaxRange];
	_backBlastTargets = [];
	{
		comment "Check angles";
		private _inCone = [getPosATL _shooter, [getDir _shooter] call M9_fnc_getOppositeAngle, M9_bbFOV, getPosATL _x] call BIS_fnc_inAngleSector;
		if (_inCone) then {
			_backBlastTargets pushBack _x;
		};
	} forEach _bbtards;
	_backBlastTargets;
};

if (!isNil 'M9_EH_Backblast') then {
	player removeEventHandler ["FiredMan", M9_EH_Backblast];
};

M9_EH_Backblast = player addEventHandler ["FiredMan", {
	params ["_unit", "_weapon", "_muzzle", "_mode", "_ammo", "_magazine", "_projectile", "_vehicle"];
	if (_weapon isKindOf ["Launcher", configFile >> "CfgWeapons"]) then {
		comment "Get the targets";
		private _tgts = [_unit] call M9_fnc_getBblastTargets;
		comment "Damage the targets";
		{
			private _dmgAdded = [_unit distance _x] call M9_fnc_calcBblastDmg;
			_x setDamage (damage _x + _dmgAdded);
			comment "TODO: Check for safezone";
			comment "TODO: Add ear ringing (playSound 'combat_deafness';)";
			comment "TODO: Check for obstructions with lineIntersects & lineIntersectsSurfaces";
			comment "TODO: Set uncon if adv incap is enabled ([_blasted,true] remoteExec ['setUnconscious', _blasted, true];)";
			comment "TODO: Break glass in houses and vehicles (maybe not armored) - https://steamcommunity.com/app/107410/discussions/17/1736632956572619563/";
			if (!alive _x) then {
				format ["%1 was killed by %2’s backblast.", name _x, name _unit] remoteExec ['systemChat'];
			};
		} forEach _tgts;
	};
}];
