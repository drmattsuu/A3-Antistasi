#define SPACING     2

params ["_marker", "_placementMarker"];

private _fileName = "initSpawnPlaces";

[3, format ["Initiating spawn places for %1 now", _marker], _fileName] call A3A_fnc_log;

private _vehicleMarker = [];
private _heliMarker = [];
private _hangarMarker = [];
private _mortarMarker = [];

//Calculating marker prefix
private _markerPrefix = "";
private _markerSplit = _marker splitString "_";
switch (_markerSplit select 0) do
{
    case ("airport"): {_markerPrefix = "airp_";};
    case ("outpost"): {_markerPrefix = "outp_";};
    case ("resource"): {_markerPrefix = "reso_";};
    case ("factory"): {_markerPrefix = "fact_";};
    case ("seaport"): {_markerPrefix = "seap_";};
};
//Fix marker name if it has a number after it
if(count _markerSplit > 1) then
{
    _markerPrefix = format ["%1%2_", _markerPrefix, _markerSplit select 1];
};

//Sort marker
private _mainMarkerPos = getMarkerPos _marker;
{
    private _first = (_x splitString "_") select 0;
    private _fullName = format ["%1%2", _markerPrefix, _x];
    if(_mainMarkerPos distance (getMarkerPos _fullName) > 500) then
    {
        [
            2,
            format ["Placementmarker %1 is more than 500 meter away from its mainMarker %2. You may want to check that!", _fullName, _marker],
            _fileName
        ] call A3A_fnc_log;
    };
    switch (_first) do
    {
        case ("vehicle"): {_vehicleMarker pushBack _fullName;};
        case ("helipad"): {_heliMarker pushBack _fullName;};
        case ("hangar"): {_hangarMarker pushBack _fullName;};
        case ("mortar"): {_mortarMarker pushBack _fullName;};
    };
    _fullName setMarkerAlpha 0;
} forEach _placementMarker;


private _markerSize = markerSize _marker;
private _distance = sqrt ((_markerSize select 0) * (_markerSize select 0) + (_markerSize select 1) * (_markerSize select 1));

private _buildings = nearestObjects [getMarkerPos _marker, ["Helipad_Base_F", "Land_Hangar_F", "Land_TentHangar_V1_F", "Land_Airport_01_hangar_F", "Land_ServiceHangar_01_L_F", "Land_ServiceHangar_01_R_F"], _distance, true];

//Sort helipads
private _heliSpawns = [_buildings, _marker, _heliMarker] call A3A_fnc_initSpawnPlacesHelipads;
_buildings = _heliSpawns select 0;
_heliSpawns = _heliSpawns select 1;

private _planeSpawns = [_buildings, _marker, _hangarMarker] call A3A_fnc_initSpawnPlacesHangars;
_buildings = _planeSpawns select 0;
_planeSpawns = _planeSpawns select 1;

private _staticSpawns = [_buildings, _marker, _mortarMarker] call A3A_fnc_initSpawnPlacesStatics;
private _mortarSpawns = _staticSpawns select 0;
_staticSpawns = _staticSpawns select 1;

private ["_vehicleSpawns", "_size", "_length", "_width", "_vehicleCount", "_realLength", "_realSpace", "_markerDir", "_dis", "_pos", "_heliSpawns", "_dir", "_planeSpawns", "_mortarSpawns", "_spawns"];

_vehicleSpawns = [];
{
    _markerX = _x;
    _size = getMarkerSize _x;
    _length = (_size select 0) * 2;
    _width = (_size select 1) * 2;
    if(_width < (4 + 2 * SPACING)) then
    {
      diag_log format ["InitSpawnPlaces: Marker %1 is not wide enough for vehicles, required are %2 meters!", _x , (4 + 2 * SPACING)];
    }
    else
    {
      if(_length < 10) then
      {
          diag_log format ["InitSpawnPlaces: Marker %1 is not long enough for vehicles, required are 10 meters!", _x];
      }
      else
      {
        //Cleaning area
        private _radius = sqrt (_length * _length + _width * _width);
        //TODO wasn't there a hideObjectGlobal? Would replace the following structure
        if (!isMultiplayer) then
        {
          {
            if((getPos _x) inArea _markerX) then
            {
              _x hideObject true;
            };
          } foreach (nearestTerrainObjects [getMarkerPos _markerX, ["Tree","Bush", "Hide", "Rock", "Fence"], _radius, true]);
        }
        else
        {
          {
            if((getPos _x) inArea _markerX) then
            {
              [_x,true] remoteExec ["hideObjectGlobal",2];
            }
          } foreach (nearestTerrainObjects [getMarkerPos _markerX, ["Tree","Bush", "Hide", "Rock", "Fence"], _radius, true]);
        };

        //Create the places
        _vehicleCount = floor ((_length - SPACING) / (4 + SPACING));
        _realLength = _vehicleCount * 4;
        _realSpace = (_length - _realLength) / (_vehicleCount + 1);
        _markerDir = markerDir _markerX;
        for "_i" from 1 to _vehicleCount do
        {
          _dis = (_realSpace + 2 + ((_i - 1) * (4 + _realSpace))) - (_length / 2);
          _pos = [getMarkerPos _markerX, _dis, (_markerDir + 90)] call BIS_fnc_relPos;
          _pos set [2, ((_pos select 2) + 0.1) max 0.1];
          _vehicleSpawns pushBack [[_pos, _markerDir], false];
        };
      };
    };
} forEach _vehicleMarker;

_spawns = [_vehicleSpawns, _heliSpawns, _planeSpawns, _mortarSpawns, _staticSpawns];
//Amount of available spawn places, amount of statics is currently -1 as not yet handled
private _spawnCounts = [count _vehicleSpawns, count _heliSpawns, count _planeSpawns, count _mortarSpawns, count _staticSpawns];

[
    3,
    format
    [
        "%1 can hold %2 ground vehicles, %3 helicopters, %4 airplanes, %5 mortars and %6 statics",
        _marker,
        _spawnCounts select 0,
        _spawnCounts select 1,
        _spawnCounts select 2,
        _spawnCounts select 3,
        _spawnCounts select 4
    ],
     _fileName
] call A3A_fnc_log;


//Saving the spawn places
spawner setVariable [format ["%1_spawns", _marker], _spawns, true];

//Saving the amount of available places
spawner setVariable [format ["%1_available", _marker], _spawnCounts, true];

//Saving the currently stationed amount (init so 0 for all)
spawner setVariable [format ["%1_current", _marker], [0, 0, 0, 0, 0], true];
