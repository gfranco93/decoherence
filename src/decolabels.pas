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

{ Different types of labels
  All labels are rendered as images to boost performance. }
unit DecoLabels;

{$INCLUDE compilerconfig.inc}

interface

uses Classes,
  DecoImages, DecoFont,
  DecoGlobal, DecoTime;

type
  { a powerful text label, converted to GLImage to be extremely fast }
  DLabel = class(DSimpleImage)
  strict private
    fText: string;
    { a set of strings each no longer than "x" }
    BrokenString: DStringList;
  private
    { converts string (Text) into an image }
    procedure PrepareTextImage;
    { change the current Text and call Prepare Text Image if needed }
    procedure SetText(const Value: string);
  public
    { Font to print the label }
    Font: DFont;
    { Shadow intensity. Shadow=0 is no shadow (strictly) }
    ShadowIntensity: Float;
    { Shadow length in pixels }
    ShadowLength: integer;
    constructor Create; override;
    destructor Destroy; override;
    //procedure Rescale; override;
    procedure RescaleImage; override;
  public
    { text at the label }
    property Text: string read fText write SetText;
  end;

type
  {provides a simple integer output into a label}
  DIntegerLabel = class (DLabel)
  public
    { pointer to the value it monitors }
    Target: Pinteger;
    procedure Update; override;
  end;

type
  {provides a simple string output into a label}
  DStringLabel = class (DLabel)
  public
    { pointer to the value it monitors }
    Target: Pstring;
    procedure Draw; override;
  end;

type
  { Provides a simple float output into a label }
  DFloatLabel = class (DLabel)
  public
    { pointer to the value it monitors }
    Target: PFloat;
    { how many digits after point are displayed?
      0 - float is rounded to integer (1.6423 -> 2)
      1 - one digit like 1.2
      2 - two digits like 1.03
      no more needed at the moment }
    Digits: integer;
    procedure Draw; override;
    constructor Create; override;
  end;

type
  {A label to display damage over player character portrait or over other actors models}
  DDamageLabel = class(DFloatLabel)
  public
    //does nothing yet. Should consist of "two labels" one for integer and one for flot part with different font size
  end;

type
  { Debug label that counts FPS
      Practically it just increases FPS by 1 each CountFPS call
      and changes displayed value approx once per second }
  DFPSLabel = class(DLabel)
  strict private
    FPScount: Integer;
    LastRenderTime: DTime;
  public
    { Call this each frame instead of Draw,
         Draw is automatically called here }
    procedure CountFPS;
    constructor Create; override;
  end;

type
  { A Label that appears, moves up 1/3 of the screen and vanishes
    Used for LoadScreen,
    Actually it's a copy of DecoImages>DPhasedImage very similar to DWindImage }
  DPhasedLabel = class(DLabel)
  private
    LastTime: DTime;
  strict protected
    {current phases of the Label}
    Phase, OpacityPhase: float; //we need to store PhaseShift for override CyclePhase procedure
    procedure CyclePhase; //virtual;
  public
    procedure Update; override;
    procedure doDraw; override;
    procedure ResetPhase;
    constructor Create; override;
  public
    { 1/seconds to scroll the full screen }
    PhaseSpeed: float;
  end;

{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses SysUtils, CastleImages,
  DecoInterface, DecoLog;

{----------------------------------------------------------------------------}

constructor DLabel.Create;
begin
  inherited Create;
  Base.ScaleItem := false;
  ShadowIntensity := 0;
  ShadowLength := 3;
  Font := DefaultFont;
  //fText := ''; //autoinitialized
end;

{----------------------------------------------------------------------------}

destructor DLabel.Destroy;
begin
  FreeAndNil(BrokenString);
  inherited Destroy;
end;

{----------------------------------------------------------------------------}

procedure DLabel.SetText(const Value: string);
begin
  if fText <> Value then begin
    fText := Value;
    PrepareTextImage;
  end;
end;

{----------------------------------------------------------------------------}

procedure DLabel.PrepareTextImage;
var tmpflg: boolean;
begin
  ImageReady := false;
  ImageLoaded := false;

  if Base.w = 0 then begin
    {an ugly bugfix that leaves item uninitialized if not scaled completely
     important for scaling labels, as the label "width" is a parameter}
    tmpflg := Base.ScaleItem;
    Base.ScaleItem := true;
    Base.FloatToInteger;
    Base.ScaleItem := tmpflg;
    dLog(LogLabelError,Self,'DLabel.PrepareTextImage','Warning! Label width is not initialized! Trying to w='+IntToStr(Base.w));
  end;

  FreeAndNil(BrokenString);
  BrokenString := Font.BreakStings(fText, Base.w);
  FreeImage;

  if ShadowIntensity = 0 then
    SourceImage := Font.BrokenStringToImage(BrokenString)
  else
    SourceImage := Font.BrokenStringToImageWithShadow(BrokenString,ShadowIntensity,ShadowLength);

  Base.SetRealSize(SourceImage.Width,SourceImage.Height);

  ImageLoaded := true;

  Rescale;
end;

{----------------------------------------------------------------------------}

procedure DLabel.RescaleImage;
begin
  {$IFNDEF AllowRescale}if SourceImage = nil then Exit;{$ENDIF}
  if Base.ScaleItem then
    inherited RescaleImage //rescale this label as a simple image to fit "base size"
  else begin
    //don't rescale this label to provide sharp font
    if ImageLoaded then
       if Base.isInitialized then begin
          {$IFDEF AllowRescale}
          ScaledImage := SourceImage.MakeCopy;
          {$ELSE}
          ScaledImage := SourceImage;
          SourceImage := nil;
          {$ENDIF}
          InitGLPending := true;
        end
        else
          dLog(LogLabelError,Self,'DLabel.RescaleImage/no scale label','ERROR: Base.Initialized = false');
  end;
end;


{=============================================================================}
{========================= Integer label =====================================}
{=============================================================================}

procedure DIntegerLabel.Update;
begin
  inherited Update;
  Text := IntToStr(Target^);
end;

{=============================================================================}
{========================== String label =====================================}
{=============================================================================}

procedure DStringLabel.Draw;
begin
  Text := Target^;
  inherited Draw;
end;

{=============================================================================}
{=========================== Float label =====================================}
{=============================================================================}

Constructor DFloatLabel.Create;
begin
  inherited Create;
  Digits := 0;
end;

{---------------------------------------------------------------------------}

procedure DFloatLabel.Draw;
begin
  case Digits of
    1: Text := IntToStr(Trunc(Target^))+'.'+IntToStr(Round(Frac(Target^)*10));
    2: Text := IntToStr(Trunc(Target^))+'.'+IntToStr(Round(Frac(Target^)*100));
    else Text := IntToStr(Round(Target^));
  end;
  inherited Draw;
end;

{=============================================================================}
{============================ FPS label ======================================}
{=============================================================================}

constructor DFPSLabel.Create;
begin
  inherited Create;
  FPSCount := 0;
  LastRenderTime := -1;

  Base.AnchorToWindow := true;
  Base.ScaleItem := false;
  Base.SetRealSize(100,100);
  SetBaseSize(0,0,0.05,0.05);

  Font := DebugFont;
  //Text := '';
end;

{---------------------------------------------------------------------------}

procedure DFPSLabel.CountFPS;
begin
  if LastRenderTime < 0 then LastRenderTime := DecoNow;

  if (DecoNow - LastRenderTime >= 1) then begin
    Text := IntToStr(FPSCount){+' '+inttostr(round(Window.Fps.RealTime))};
    FPSCount := 0;
    LastRenderTime := DecoNow;
  end else inc(FPSCount);
  Draw;
end;

{=============================================================================}
{========================== Phased label =====================================}
{=============================================================================}

constructor DPhasedLabel.Create;
begin
  inherited Create;
  Base.AnchorToWindow := true;
  ResetPhase;
  PhaseSpeed := 0.1;
  Self.ShadowIntensity := 1.0;
end;

{----------------------------------------------------------------------------}

procedure DPhasedLabel.ResetPhase;
begin
  LastTime := -1;
end;

{----------------------------------------------------------------------------}

procedure DPhasedLabel.CyclePhase;
var PhaseShift: float;
begin
  if LastTime < 0 then begin
    LastTime := DecoNow;
    Phase := 0;
  end;
  PhaseShift := (DecoNow-LastTime)*PhaseSpeed;
  LastTime := DecoNow;
  Phase += PhaseShift*(1+0.1*drnd.Random);
  if Phase > 1 then Phase := 1;

  OpacityPhase += PhaseShift/2*(1+0.2*drnd.Random);
  if OpacityPhase>1 then OpacityPhase := 1;
  {not sure about this... but let it be this way for now}
end;

{----------------------------------------------------------------------------}

procedure DPhasedLabel.Update;
begin
  inherited Update;
  CyclePhase;
end;

{----------------------------------------------------------------------------}

procedure DPhasedLabel.doDraw;
var y: integer;
begin
  //inherited <---------- this render is different
  GLImage.Color[3] := Current.CurrentOpacity*Sin(Pi*Phase);

  y := round((1 + 5*Phase)*Window.height/17);
  GLImage.Draw(2*Window.Width div 3, y);
end;

end.

