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

{ a thread descendant used for most game purposes }
unit decothread;

{$INCLUDE compilerconfig.inc}
interface

uses Classes,
  decoglobal;

type
  {a thread which reports its current state and progress
   should be hold in actual state by calling UpdateProgress from the Execute}
  TAbstractThread = class(TThread)
  protected
    {current progress in 0..1}
    fprogress: float;
    {name of the current job}
    fcurrentjob: string;
    {multiplier for scaling the current progress, e.g. in case each part
     of the procedure is scaled in 0..1, then mult will equal to number of the procedures}
    fmult: float;
    {should be called to update (and scale) the progress conveniently
     pay attention: next progress is always larger than last progress
     i.e. passing values 0.1, 0.2 and 0.1 will result in progress = 0.2 (last known largest value)
     this is caused by progress most often used in procedures, making several tries to solve the taks
     to reset progress, use fprogress}
    procedure UpdateProgress(currentJobValue: string; progressValue: float);
  public
    {current progress of the thread}
    property progress: float read fprogress;
    {name of the current job}
    property currentjob: string read fcurrentjob;
  end;

{redundant function to get max value of two values,
 I know there's such procedure somewhere already,
 but I was too lazy to search for it}
function minimum(v1,v2: float): float;
{++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
implementation

procedure TAbstractThread.UpdateProgress(currentJobValue: string; progressValue: float);
begin
  fcurrentJob := currentJobValue;
  if fprogress < progressValue*fmult then
    fprogress := progressValue*fmult;
  if fprogress>1 then fprogress := 1;
end;

{----}

function minimum(v1,v2: float): float;
begin
  if v1>v2 then result := v2 else result := v1;
end;

end.
