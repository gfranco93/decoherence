{Copyright (C) 2012-2017 Yevhen Loza

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.}

{---------------------------------------------------------------------------}

{ contains definitions for most abstract World entity }

unit DecoAbstractWorld;

{$INCLUDE compilerconfig.inc}
interface

uses CastleRandom, CastleVectors,
  DecoAbstractGenerator, deconavigationnetwork,
  DecoGlobal;

Type
  {The most abstract world implementation.
   Used as external interface for the world}
  DAbstractWorld = class
  protected
    fSeed: LongWord;
    { xorshift random generator, fast and thread-safe
      used by BUILD (maybe freed afterwards?) }
    RNDM: TCastleRandom;
    {time of last render. Used for FPS management}
    LastRender: TDateTime;
    { Is this render the first one?
      Additional initialization procedures may be required }
    {$HINT todo: LastRender = -1 does the same job, optimize it}
    {$HINT allow first initialization flow during load without caring for FPS!}
    FirstRender: boolean;
  public
    { Seed used to "build" the world if it requires random}
    property Seed: LongWord read fSeed write fSeed;
    { World management routine. Called every frame;
      Most important thing it does is managing LODs of tiles/landscape
      And hiding/LODding world chunks
      x,y,z are current world coordinates of render camera }
    Procedure Manage(position: TVector3); virtual; abstract;
    {Builds a PathTree for the world}
    //Function pathfind: DPathTree;
    { Load the World from a file}
    procedure Load(URL: string); virtual;
    { Load the World from a running Generator }
    procedure Load(Generator: DAbstractGenerator); virtual;
    { Builds a world from the obtained data }
    procedure Build; virtual;
    { activates the current world.
      Caution, it might and will modify Window.SceneManager! }
    procedure Activate; virtual;
    { Splits the World into chunks }
    //Procedure chunk_n_slice; virtual; abstract;

    { Spawns Actors in the World }
    procedure SpawnActors; virtual; abstract;
    { Returns Gravity Up for the given location in the world
      Maybe, move this one to AbstractWorld3D, as it's not needed in non-3D world
      it's bad, that there is no way to make this procedure inline,
      because it might be important to keep it efficiently
      However, for now it's used only for spawning process, so don't bother yet}
    function GetGravity(aPosition: TVector3): TVector3; virtual; abstract;
    function GetGravity(aNav: TNavID): TVector3; virtual; abstract;

    { A dummy procedure to be overriden in rendered world types
     (such as text or 2D)}
    procedure Render; virtual;

    constructor Create; virtual;
    destructor Destroy; override;

  public
    Nav: TNavList;
    Weenies: TWeeniesList;
    function NavToVector3(aNav: TNavID): TVector3;
    procedure BlockNav(aNav: TNavID);
    procedure ReleaseNav(aNav: TNavID);
    procedure ClearNavBlocks;
  end;

var CurrentWorld: DAbstractWorld;

procedure FreeWorld;


{procedure FreeRootList(List: TRootList);} //unneeded as list "owns" children
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation

uses SysUtils, Classes, CastleLog;

constructor DAbstractWorld.create;
begin
  inherited;
  WriteLnLog('DAbstractWorld.create','Creating the World');
  {we create an non-initialized random (i.e. initialized by a stupid constant integer)
  Just to make sure we don't waste any time (<1ms) on initialization now}
  RNDM := TCastleRandom.Create(1);
end;

{------------------------------------------------------------------------------}

destructor DAbstractWorld.Destroy;
begin
  WriteLnLog('DAbstractWorld.destroy','Freeing the World');
  FreeAndNil(RNDM);
  FreeAndNil(Nav);
  FreeAndNil(Weenies);
  inherited;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.Build;
begin
  if fSeed = 0 then raise Exception.Create('DAbstractWorld.Build: World random must be predefined!');
  RNDM.Initialize(fSeed);
end;

{------------------------------------------------------------------------------}

Procedure DAbstractWorld.Activate;
begin
  WriteLnLog('DAbstractWorld.Activate','Activating the world.');
  if (CurrentWorld<>nil) and (CurrentWorld<>Self) then
    raise Exception.Create('ERROR: Free and nil the previous World before activating this one!');
  LastRender := -1;
  FirstRender := true;
end;

{------------------------------------------------------------------------------}

Procedure DAbstractWorld.Render;
begin
  {this is an abstract routine,
  it must be overridden by DRenderedWorld}
  WriteLnLog('DAbstractWorld.render','Warning: This shouldn''t happen in normal situation, it''s abstract');
end;

{------------------------------------------------------------------------------}

function DAbstractWorld.NavToVector3(aNav: TNavID): TVector3;
begin
  Result[0] := Nav[aNav].x;
  Result[1] := Nav[aNav].y;
  Result[2] := Nav[aNav].z;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.BlockNav(aNav: TNavId);
begin
  Nav.L[aNav].Blocked := true;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.ReleaseNav(aNav: TNavId);
begin
  Nav.L[aNav].Blocked := false;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.ClearNavBlocks;
var i: integer;
begin
  //actually, it seems redundant for now
  for i := 0 to Nav.Count-1 do Nav.L[i].Blocked := false;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.Load(Generator: DAbstractGenerator);
begin
  fSeed := drnd.Random32bit; //maybe other algorithm?
  if Nav<>nil then begin
    WriteLnLog('DAbstractWorld.Load','WARNING: Nav is not nil! Freeing');
    FreeAndNil(Nav);
  end;
  Nav := Generator.ExportNav;
  ClearNavBlocks;
  Weenies := Generator.ExportWeenies;
end;

{------------------------------------------------------------------------------}

procedure DAbstractWorld.Load(URL: string);
begin
  {$hint dummy}
  //load seed and Nav
end;

{------------------------------------------------------------------------------}

procedure FreeWorld;
begin
  if CurrentWorld<>nil then WriteLnLog('decoabstractworld.FreeWorld','World is not nil, freeing');
  FreeAndNil(CurrentWorld);
end;

end.
