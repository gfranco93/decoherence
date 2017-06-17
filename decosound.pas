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

{ Sound and music routines
  Adaptive music and playlists.

  Sequential playlist. Just plays a random track from a provided list.

  Adaptive (or inetractive) music is the term used for the music tracks
  that adapt to current game situation, providing much better music blending
  with the gameplay. There are two most used ways to use Adaptive Music.

  Horizontal synchronization. The tracks match each other's beat, so that
  they can be safely crossfaded one into another at the same playing position.

  Vertical synchronization. The tracks match each other's harmony, so that
  during crossfading the tracks will seamlessly blend into one another.

  Of course only specially composed tracks that have the same rhythm
  and harmony can be smoothly synchronized.}
unit decosound;

{$INCLUDE compilerconfig.inc}
interface
uses classes, fgl,
  CastleSoundEngine, CastleTimeUtils;

type
  {thread that actually loads the sound file}
  DSoundLoadThread = class(TThread)
  public
    {refrence to DSoundFile / Why can't I make a cyclic refernce?}
    parent: TObject; //DSoundFile
  protected
    {loads the file}
    procedure Execute; override;
  end;

type
  {store and manage music track}
  DSoundFile = class
  private
    {thread to load the sound file. Auto freed on terminate. Sets isLoaded flag}
    LoadThread: DSoundLoadThread;
    ThreadWorking: boolean;
    {full URL of the sound file}
    fURL: string;
    fisLoaded: boolean;
  public
    {reference to the sound buffer of this file}
    buffer: TSoundBuffer;
    {duration of the loaded file}
    duration: TFloatTime;

    {if the file is loaded and ready to play}
    property isLoaded: boolean read fisLoaded default false;
    {creates and starts LoadThread. When finished runs LoadFinished}
    procedure Load;
    procedure Load(URL: string);
    procedure LoadFinished;

    constructor create;
    constructor create(URL: string);
    destructor destroy; override;
  end;

type
  {A sound file which is a Music track with additional features}
  DMusicTrack = class(DSoundFile)
  private
    {reference to "now playing" sound file to adjust its properties realtime}
    fCurrent: TSound;
    {is looping?}
    fLoop: boolean;
    {actual beginning of the fade out process}
    FadeStart: TDateTime;
    {if the file is playing at the moment}
    fisPlaying: boolean;
    {preforms fade out by adjusting the track's gain}
    procedure doFade;
  private
    {gain volume 0..1}
    const fgain = 1; {maybe, global music volume?}
    {fade out time}
    const FadeTime = 3/24/60/60; {3 seconds}
  public
    {if the current music is playing at the moment?}
    property isPlaying: boolean read fisPlaying default false;
    {prepare and start the music}
    procedure Start;
    {softly stop the music with a fade-out}
    procedure FadeOut;
    {manage the music / should be called each frame}
    procedure manage;
    {sets current music "gain", move to private?}
    procedure setGain(value: single);
    constructor create;
    constructor create(URL: string);
  end;

{situation differentiator. Best if assigned to const mysituation = 0.
 situations must start from zero and be sequential. // todo?}
type TSituation = byte;

type
  {describes and manages music intended to have a loop-part [a..b]
   with optional intro [0..a] and ?ending [b..end]}
  DLoopMusicTrack = class(DMusicTrack)
    //a,b
    Tension: single;
    //Situation: TSituation;
  end;

type
  {a list of music tracks}
  TTrackList = specialize TFPGObjectList<DMusicTrack>;
  TLoopTrackList = specialize TFPGObjectList<DLoopMusicTrack>;

type
  {the most abstract features of the playlist}
  DAbstractPlaylist = class
    public
      {manage the playlist (loading, start, stop, fade)}
      procedure manage; virtual; abstract;
    end;

type
  {abstract music tracks manager}
  DPlaylist = class(DAbstractPlaylist)
  public
    {URLs of the music files in this playlist}
    URLs: TStringList;
    {load all tracks in the URLs list}
    //procedure LoadAll; // this is wrong in every way!

    constructor create; virtual;
    destructor destroy; override;
  end;

type
  {Tracks sequentially change each other with pre-loading and no fading
   also supports occasional silence (silence will never be the first track playing)}
  DSequentialPlaylist = class(DPlayList)
    protected
      {tracks of this playlist}
      tracks: TTrackList;  {$hint it looks wrong! Only 2 (now playing & fading + there might be >1 fading) tracks are needed at every moment of time}
      {number of the previous track, stored not to repeat that track again if possible}
      PreviousTrack: integer;
    public
      {(prepare to) load the next random track from the playlist}
      procedure LoadNext;
      constructor create; override;
      destructor destroy; override;
    end;

{"tension" of the current track which determines which of the synchronized
 tracks should be used at this moment.}
type TTension = single;

type
  {Synchronized playlist for combat.
   Softly changes the synchronized tracks according to current situation.
   BeatList is optional, but recommended that fades will happen on beats change}
  DSyncPlaylist = class(DPlayList)
    private
      tensionchanged: boolean;
      ftension: TTension;
      procedure settension(value: TTension);
      function gettrack(newtension: TTension): integer;
    protected
      {list of tracks in the playlist. All the tracks are horizontally synchronized
       and MUST have the same rhythm,
       the melody line should also be blendable.
       On the other hand, playing together with MultiSyncPlaylist in case the
       tension changes only on situation change, then the tracks must only have
       the same beat, and can be unblendable between one another}
      tracks: TLoopTrackList;
    public
      {current music tension. It's a good idea to keep this value in 0..1 range,
       however it's not mandatory}
      property tension: TTension read ftension write settension;

      procedure manage; override;

      constructor create; override;
      destructor destroy; override;
    end;

type
  {This is a set of several "vertically synchronized" synchronized playlists
   The set of playlists sholud blend smoothly with one another depending on the situation,
   i.e. the blending takes place in "2D space" of tension/situation,
   e.g. situations may be player's/enemie's turn
   with different tension depending on amount/strengths of enemy units visible
   If the tension may change only on situation change, then there is no need to
   blend harmony of all the tracks in the playlists, only different possible
   situation changes should blend flawlessly.}
  DMultiSyncPlaylist = class(DAbstractPlaylist)
    private
      fsituation: TSituation;
      situationchanged: boolean;
      procedure setsituation(value: TSituation);
    public
      {vertically synchronized synchronized playlists :)
       You have to manage their blendability based on possible situation change,
       e.g. an incoming nuke might happen only on enemy's turn, there's no need
       to blend it with player's turn.}
      playlists: array of DSyncPlaylist;
      {}
      property situation: TSituation read fsituation write setsituation;
      procedure manage; override;
    end;


type
  {Manages all the playlists, currently played music and ambience
   also tries to merge playlists (not implemented yet)}
  DMusicManager = class
  private
    {current ambient track, just plays continuously}
    Ambient: DLoopMusicTrack;
    {current music playlist}
    Music,OldMusic: DPlaylist; //sequential or synchronized
  public
    {manage the music, should be called each frame
     or otherwise relatively often
     Note, that loading a new track/playlist takes some time depending on HDD speed
     so while MusicManager tries its best to make it as quick as possible,
     the requested change usually won't be immediate,
     especially in case of an unexpected change}
    procedure manage;

    constructor create;
    destructor destroy; override;
  end;

var
  {global music manager}
  Music: DMusicManager;

procedure initMusicManager;
procedure freeMusicManager;
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses SyncObjs, SysUtils, CastleLog, castleFilesUtils,
  CastleVectors,
  decoinputoutput, //used for safe threaded loading of sound buffer
  decoglobal;      //used for random

{========================== TMusicLoadThread ===============================}

procedure DSoundLoadThread.Execute;
begin
 (parent as DSoundFile).buffer := LoadBufferSafe((parent as DSoundFile).fURL,(parent as DSoundFile).duration);
 (parent as DSoundFile).LoadFinished;
end;

{============================= DSoundFile ==================================}

constructor DSoundFile.create;
begin
  inherited;
  buffer := 0;
  duration := -1;
  ThreadWorking := false;
end;
constructor DSoundFile.create(URL: string);
begin
  self.create;
  fURL := URL;
  self.Load;
end;

{---------------------------------------------------------------------------}

procedure DSoundFile.Load(URL :string);
begin
  fURL := URL;
  self.Load;
end;
procedure DSoundFile.Load;
begin
  if fURL='' then begin
    writeLnLog('DSoundFile.Load','ERROR: No valid URL provided. Exiting...');
    exit;
  end;
  if not ThreadWorking then begin
    LoadThread := DSoundLoadThread.Create(true);
    LoadThread.Priority := tpLower;
    LoadThread.parent := self;
    LoadThread.FreeOnTerminate := true;
    LoadThread.Start;
    ThreadWorking := true;
  end
  else
     writeLnLog('DSoundFile.Load','Thread already working...');
end;
procedure DSoundFile.LoadFinished;
begin
  fisLoaded := true;
  ThreadWorking := false;
end;

{---------------------------------------------------------------------------}

destructor DSoundFile.destroy;
begin
  soundengine.FreeBuffer(buffer);
  if ThreadWorking then begin
    Try
      LoadThread.Terminate;
    finally
      FreeAndNil(LoadThread); //redundant, as freeonterminate=true?
    end;
  end;
  inherited;
end;

{========================== DMusicTrack ==================================}

procedure DMusicTrack.Start;
begin
  if not isLoaded then begin
    WriteLnLog('DMusicTrack.Start','ERROR: Music is not loaded!');
    exit;
  end;
  fCurrent := SoundEngine.PlaySound(self.buffer, false, fLoop, 10, fgain, 0, 1, ZeroVector3Single);
  if fCurrent = nil then WriteLnLog('DMusicTrack.Start','ERROR: Unable to allocate music!');
  fisPlaying := true;
end;

{---------------------------------------------------------------------------}

procedure DMusicTrack.FadeOut;
begin
  FadeStart := now;
end;

{---------------------------------------------------------------------------}

procedure DMusicTrack.manage;
begin
  if isPlaying then
    if FadeStart>0 then doFade;
end;

{---------------------------------------------------------------------------}

constructor DMusicTrack.create;
begin
  inherited;
  FadeStart := -1;
end;
constructor DMusicTrack.create(URL: string);
begin
  Inherited create(URL);
  FadeStart := -1;
end;

{---------------------------------------------------------------------------}

procedure DMusicTrack.doFade;
begin
  if Now-FadeStart<FadeTime then begin
    setGain(1-(Now-FadeStart)/FadeTime);
  end else begin
    SetGain(0);       //fade to zero
    fCurrent.Release; //stop the music
    fisPlaying := false;
  end;
end;

{---------------------------------------------------------------------------}

procedure DMusicTrack.setGain(value: single);
begin
  if Assigned(fCurrent) and fCurrent.PlayingOrPaused then
    fCurrent.Gain := value
  else begin
    //fGain := value;
    WriteLnLog('DMusicTrack.setGain','Warning: Setting gain of a non-playing music track...');
  end;
end;

{============================ DPlaylist ================================}

constructor DPlaylist.create;
begin
  Inherited;
  URLs := TStringList.create;
end;

{---------------------------------------------------------------------------}

destructor DPlayList.destroy;
begin
  FreeAndNil(URLs);
  Inherited;
end;

{---------------------------------------------------------------------------}

{procedure DPlayList.LoadAll;
var s: string;
    musicTrack: DMusicTrack;
begin
  {$warning this is wrong! we need to load only one url at once in sequential playlist!}
  for s in URLs do
    musicTrack := DMusicTrack.create(s);
  {$hint different implementation for loop tracks}
  {$hint delayed load of the music files!}
end;}

{---------------------------------------------------------------------------}

procedure DSequentialPlaylist.LoadNext;
var newTrack: integer;
begin
  if URLs.Count=1 then PreviousTrack := -1; //if only one track is available, then forget about shuffling
  //shuffle tracks, but don't repeat the previous one
  repeat
    newTrack := drnd.Random(URLs.Count);
  until NewTrack<>PreviousTrack;
  {$hint process silence here}
  //load here
end;

{---------------------------------------------------------------------------}

constructor DSequentialPlaylist.create;
begin
  inherited;
  PreviousTrack := -1;
  tracks := TTrackList.create;
end;

destructor DSequentialPlaylist.destroy;
begin
  freeandnil(tracks);
  inherited;
end;

{---------------------------------------------------------------------------}

procedure DSyncPlaylist.settension(value: TTension);
begin
  if gettrack(ftension){current track playing}<>gettrack(value) then tensionchanged := true;
  ftension := value;
end;

{---------------------------------------------------------------------------}

function DSyncPlaylist.gettrack(newtension: TTension): integer;
var i: integer;
    tension_dist: single;
begin
  tension_dist := 9999; //some arbitrary large value
  Result := -1;
  {$warning the track may be not loaded yet!}
  //select a track that fits the new tension best //todo: optmize?
  for i := 0 to Tracks.count do
    if abs(tracks[i].Tension - newtension)<tension_dist then begin
      tension_dist := abs(tracks[i].Tension - newtension);
      Result := i;
    end;
end;

{---------------------------------------------------------------------------}

procedure DSyncPlaylist.manage;
begin
  tensionchanged := false;
end;

{---------------------------------------------------------------------------}

constructor DSyncPlaylist.create;
begin
  inherited;
  tracks := TLoopTrackList.create;
end;

{---------------------------------------------------------------------------}

destructor DSyncPlaylist.destroy;
begin
  freeandnil(tracks);
  inherited;
end;

{---------------------------------------------------------------------------}

procedure DMultiSyncPlaylist.SetSituation(value: TSituation);
begin
  if fsituation<>value then begin
    situationChanged := true;
    fsituation := value;
  end;
end;

{---------------------------------------------------------------------------}

procedure DMultiSyncPlaylist.manage;
begin
  situationchanged := false;
end;

{============================ DMusicManager ================================}

procedure DMusicManager.manage;
begin

end;

{---------------------------------------------------------------------------}

constructor DMusicManager.create;
begin

end;

{---------------------------------------------------------------------------}

destructor DMusicManager.destroy;
begin

end;

{============================ other routines ===============================}

procedure initMusicManager;
begin
  Music := DMusicManager.create;
end;

{---------------------------------------------------------------------------}

procedure freeMusicManager;
begin
  FreeAndNil(Music);
end;

{
initialization

finalization
}
end.
