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

{ TCastleImage processing }
unit DecoImageProcess;

{$INCLUDE compilerconfig.inc}
interface

uses CastleImages,
  DecoGlobal;

{ Makes the image brighter (default 20%)
 warning: creates a copy of the image!}
function Brighter(const aImage: TCastleImage; const Mult: float = 1.2): TCastleImage;
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation
uses CastleVectors,
  DecoLog;

function CheckImageValid(aImage: TCastleImage): boolean;
begin
  Result := true;
  if (aImage=nil) or (aImage.isEmpty) then begin
    Result := false;
    dLog(LogInterfaceError,aImage,'DecoImageProcess>CheckImageValid','FATAL: Image is nil');
    Exit;
  end;
  if not (aImage is TRGBAlphaImage) then begin
    Result := false;
    dLog(LogInterfaceError,nil,'DecoImageProcess>CheckImageValid','FATAL: Image type '+aImage.ClassName+' is not supported for operation.');
    Exit;
  end;
end;

{------------------------------------------------------------------------}

function Clamp255(a: integer): byte;
begin
  { maybe, make it "softer"? It'll require knowing "max" (which is actually mult*255 = 255+20% default)}
  if a<255 then Result := a else Result := 255;
end;

{------------------------------------------------------------------------}

function Brighter(const aImage: TCastleImage; const Mult: float = 1.2): TCastleImage;
var IMG: TRGBAlphaImage;
  p: PVector4byte;
  i: integer;
begin
  if not CheckImageValid(aImage) then Exit;
  IMG := aImage.MakeCopy as TRGBAlphaImage;
  p := IMG.Pixels;
  for i := 0 to (IMG.Size div IMG.PixelSize) do begin
    p^[0] := Clamp255(Round(p^[0]*Mult));
    p^[1] := Clamp255(Round(p^[1]*Mult));
    p^[2] := Clamp255(Round(p^[2]*Mult));
    {no alpha processing?}
    //p^[3]
    inc(p,IMG.PixelSize);
  end;
  Result := IMG;
end;

{------------------------------------------------------------------------}



end.

