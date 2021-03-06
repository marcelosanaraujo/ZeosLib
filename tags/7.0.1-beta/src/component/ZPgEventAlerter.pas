{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{         Interbase Database Connectivity Classes         }
{                                                         }
{    Copyright (c) 1999-2003 Zeos Development Group       }
{            Written by Sergey Merkuriev                  }
{                                                         }
{*********************************************************}

{@********************************************************}
{ License Agreement:                                      }
{                                                         }
{ This library is free software; you can redistribute     }
{ it and/or modify it under the terms of the GNU Lesser   }
{ General Public License as published by the Free         }
{ Software Foundation; either version 2.1 of the License, }
{ or (at your option) any later version.                  }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ You should have received a copy of the GNU Lesser       }
{ General Public License along with this library; if not, }
{ write to the Free Software Foundation, Inc.,            }
{ 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA }
{                                                         }
{ The project web site is located on:                     }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

{*********************************************************}
{                                                         }
{ TZPgEventAlerter, Asynchronous notifying.               }
{   By Ivan Rog - 2010                                    }
{                                                         }
{ Contributors:                                           }
{   Silvio Clecio - http://silvioprog.com.br              }
{                                                         }
{*********************************************************}

unit ZPgEventAlerter;

interface
{$I ZComponent.inc}
uses
  SysUtils, Classes, ExtCtrls,
{$IFDEF MSWINDOWS}
  Windows,
{$ELSE}
{$ENDIF}
  ZDbcPostgreSql, ZPlainPostgreSqlDriver, ZConnection, ZAbstractRODataset,
  ZDataset;

type
  TZPgNotifyEvent = procedure(Sender: TObject; Event: string;
    ProcessID: Integer; Payload: string) of object;

  { TZPgEventAlerter }

  TZPgEventAlerter = class (TComponent)
  private
    FActive      : Boolean;
    FEvents      : TStrings;

    FTimer       : TTimer;
    FConnection: TZConnection;
    FNotifyFired : TZPgNotifyEvent;

    FProcessor   : TZPgEventAlerter; //processor component - it will actually handle notifications received from DB
    //if processor is not assignet - component is handling notifications by itself
    FChildAlerters :TList; //list of TZPgEventAlerter that have our component attached as processor
    FChildEvents : TStrings; //list of actual events to be handled - gathered from events of all childe
  protected
    procedure SetActive     (Value: Boolean);
    function  GetInterval   : Cardinal;
    procedure SetInterval   (Value: Cardinal);
    procedure SetEvents     (Value: TStrings);
    procedure SetConnection (Value: TZConnection);
    procedure TimerTick     (Sender: TObject);
    procedure CheckEvents;
    procedure OpenNotify;
    procedure CloseNotify;

    procedure SetProcessor(Value: TZPgEventAlerter);
    procedure AddChildAlerter(Child: TZPgEventAlerter);
    procedure RemoveChildAlerter(Child: TZPgEventAlerter);
    procedure HandleNotify(Notify: PZPostgreSQLNotify); //launching OnNotify event fo Self and all child components (if event name is matched)
    procedure SetChildEvents     (Value: TStrings);
    procedure RefreshEvents; //gathering all events from all child components (no duplicates), also propagating these events "down" to our processor
  public
    constructor Create     (AOwner: TComponent); override;
    destructor  Destroy; override;
  published
    property Connection: TZConnection     read FConnection   write SetConnection;
    property Active:     Boolean          read FActive       write SetActive;
    property Events:     TStrings         read FEvents       write SetEvents;
    property Interval:   Cardinal         read GetInterval   write SetInterval    default 250;
    property OnNotify:   TZPgNotifyEvent  read FNotifyFired  write FNotifyFired;
    property Processor:     TZPgEventAlerter          read FProcessor       write SetProcessor; //property to assign processor handling notifications
    property ChildEvents:   TStrings         read FChildEvents write SetChildEvents; //read onlu property to keep all events in one place
  end;

implementation

{ TZPgEventAlerter }

constructor TZPgEventAlerter.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);
  FEvents := TStringList.Create;
  FChildAlerters := TList.Create;
  FChildEvents := TStringList.Create;
  with TStringList(FEvents) do
  begin
    Duplicates := dupIgnore;
  end;

  with TStringList(FChildEvents) do
  begin
    Duplicates := dupIgnore;
  end;

  FTimer         := TTimer.Create(Self);
  FTimer.Enabled := False;
  SetInterval(250);
  FTimer.OnTimer := TimerTick;
  FActive        := False;
  if (csDesigning in ComponentState) and Assigned(AOwner) then
   for I := AOwner.ComponentCount - 1 downto 0 do
    if AOwner.Components[I] is TZConnection then
     begin
        FConnection := AOwner.Components[I] as TZConnection;
      Break;
     end;
end;

destructor TZPgEventAlerter.Destroy;
begin
  if FProcessor = nil then
    CloseNotify;
  FEvents.Free;
  FTimer.Free;
  FChildAlerters.Free;
  FChildEvents.Free;
  inherited Destroy;
end;

procedure TZPgEventAlerter.SetInterval(Value: Cardinal);
begin
  FTimer.Interval := Value;
end;

function TZPgEventAlerter.GetInterval: Cardinal;
begin
  Result := FTimer.Interval;
end;

procedure TZPgEventAlerter.SetEvents(Value: TStrings);
var
  I: Integer;
begin
  FEvents.Assign(Value);

  for I := 0 to FEvents.Count -1 do
    FEvents[I] := Trim(FEvents[I]);
  RefreshEvents; //we must propagate events down to our processor
end;

procedure TZPgEventAlerter.SetActive(Value: Boolean);
begin
  if FActive <> Value then
  begin
    if FProcessor = nil then
    begin
      if Value then
      begin
        RefreshEvents;
        OpenNotify;
      end
      else
      begin
        CloseNotify;
      end
    end
    else  //we have processor attached - we dont need to open or close notifications
    begin
      FActive := Value;
      FProcessor.RefreshEvents;
    end;
  end;
end;

procedure TZPgEventAlerter.SetConnection(Value: TZConnection);
begin
  if FConnection <> Value then
  begin
    if FProcessor = nil then //we are closing notifiers only whern there is no processor attached
      CloseNotify;
    FConnection := Value;
  end;
end;

procedure TZPgEventAlerter.TimerTick(Sender: TObject);
begin
  if not FActive then
   FTimer.Enabled := False
  else
  begin
    if FProcessor <> nil then
      FTimer.Enabled := False
    else
     CheckEvents;
  end;
end;

procedure TZPgEventAlerter.OpenNotify;
var
  I        : Integer;
  Tmp      : array [0..255] of AnsiChar;
  Handle   : PZPostgreSQLConnect;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : IZPostgreSQLPlainDriver;
  Res: PGresult;
begin
  if not Boolean(Pos('postgresql', FConnection.Protocol)) then
    raise EZDatabaseError.Create('Ivalid connection protocol. Need <postgres>, get ' +
      FConnection.Protocol + '.');
  if FActive then
    Exit;
  if not Assigned(FConnection) then
    Exit;
  if ((csLoading in ComponentState) or (csDesigning in ComponentState)) then
    Exit;
  if not FConnection.Connected then
    Exit;
  ICon     := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle   := ICon.GetConnectionHandle;
  PlainDRV := ICon.GetPlainDriver;
  if Handle = nil then
    Exit;
    for I := 0 to FChildEvents.Count-1 do
  begin
    StrPCopy(Tmp, 'listen ' + AnsiString(FChildEvents.Strings[I]));
    Res := PlainDRV.ExecuteQuery(Handle, Tmp);
    if (PlainDRV.GetResultStatus(Res) <> TZPostgreSQLExecStatusType(
      PGRES_COMMAND_OK)) then
   begin
      PlainDRV.Clear(Res);
    Exit;
   end;
    PlainDRV.Clear(Res);
  end;
  FActive        := True;
  FTimer.Enabled := True;
end;

procedure TZPgEventAlerter.CloseNotify;
var
  I        : Integer;
  tmp      : array [0..255] of AnsiChar;
  Handle   : PZPostgreSQLConnect;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : IZPostgreSQLPlainDriver;
  Res: PGresult;
begin
  if not FActive then
    Exit;
  FActive        := False;
  FTimer.Enabled := False;
  ICon           := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle         := ICon.GetConnectionHandle;
  PlainDRV       := ICon.GetPlainDriver;
  if Handle = nil then
    Exit;
  for I := 0 to FChildEvents.Count-1 do
  begin
    StrPCopy(Tmp, 'unlisten ' + AnsiString(FChildEvents.Strings[i]));
    Res := PlainDRV.ExecuteQuery(Handle, Tmp);
    if (PlainDRV.GetResultStatus(Res) <> TZPostgreSQLExecStatusType(
      PGRES_COMMAND_OK)) then
   begin
      PlainDRV.Clear(Res);
    Exit;
   end;
    PlainDRV.Clear(Res);
  end;
end;

procedure TZPgEventAlerter.CheckEvents;
var
  Notify: PZPostgreSQLNotify;
  Handle   : PZPostgreSQLConnect;
  ICon     : IZPostgreSQLConnection;
  PlainDRV : IZPostgreSQLPlainDriver;
begin
  ICon      := (FConnection.DbcConnection as IZPostgreSQLConnection);
  Handle    := ICon.GetConnectionHandle;
  if Handle=nil then
  begin
    FTimer.Enabled := False;
    FActive := False;
    Exit;
  end;
  if not FConnection.Connected then
  begin
    CloseNotify;
    Exit;
  end;
  PlainDRV  := ICon.GetPlainDriver;

  if PlainDRV.ConsumeInput(Handle)=1 then
  begin
    while True do
    begin
      Notify := PlainDRV.Notifies(Handle);
      if Notify = nil then
        Break;
      HandleNotify(Notify);
      PlainDRV.FreeNotify(Notify);
    end;
  end;
end;

procedure TZPgEventAlerter.HandleNotify(Notify: PZPostgreSQLNotify);
var
  i: Integer;
  CurrentChild: TZPgEventAlerter;
begin
  if Assigned(FNotifyFired) and (FEvents.IndexOf(String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname)) <> -1) then
    FNotifyFired(Self, String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname), Notify{$IFDEF OLDFPC}^{$ENDIF}.be_pid,String(Notify{$IFDEF OLDFPC}^{$ENDIF}.payload));

  for I := 0 to FChildAlerters.Count-1 do //propagating event to child listeners
  begin
    CurrentChild :=TZPgEventAlerter(FChildAlerters[i]);
    if CurrentChild.Active and (CurrentChild.ChildEvents.IndexOf(String(Notify{$IFDEF OLDFPC}^{$ENDIF}.relname)) <> -1) then //but only active ones
      CurrentChild.HandleNotify(Notify);
  end;
end;

procedure TZPgEventAlerter.SetProcessor(Value: TZPgEventAlerter);
begin
  if FProcessor <> Value then
  begin
    if FProcessor <> nil then //remove assignment from old processor
    begin
      FProcessor.RemoveChildAlerter(Self);
    end;
    FProcessor := Value;
    if FProcessor <> nil then      //add assignment to new processor
    begin
      if FProcessor.Connection <> FConnection then
      begin
        raise Exception.Create('Cannot set processor with different connection');
        Exit;
      end;
      FProcessor.AddChildAlerter(Self);
    end;

  end;
end;

procedure TZPgEventAlerter.RefreshEvents;
var
  i,j: integer;
  CurrentChild: TZPgEventAlerter;
begin
  FChildEvents.Clear;
  for I := 0 to FChildAlerters.Count-1 do
  begin
    CurrentChild := TZPgEventAlerter(FChildAlerters[i]);
    if CurrentChild.Active or ((csLoading in ComponentState) or (csDesigning in ComponentState)) then
    begin  //gathering vent namse from all childs
      for j := 0 to CurrentChild.ChildEvents.Count-1 do
        if FChildEvents.IndexOf(CurrentChild.ChildEvents.Strings[j]) = -1 then
          FChildEvents.Add(CurrentChild.ChildEvents.Strings[j]);
    end;
  end;

  for i := 0 to Events.Count-1 do
    if FChildEvents.IndexOf(Events.Strings[i]) = -1 then
      FChildEvents.Add(Events.Strings[i]);

  if FProcessor <> nil then  //refreshing eventrs in our processor
    FProcessor.RefreshEvents
  else
  begin
    if Active then //refreshing listeners after change of events - to make sure we will listen for everything
    begin
      Active := False;
      Active := True;
    end;
  end;
end;

procedure TZPgEventAlerter.AddChildAlerter(Child: TZPgEventAlerter);
begin
  FChildAlerters.Add(Child);
  RefreshEvents;
end;

procedure TZPgEventAlerter.RemoveChildAlerter(Child: TZPgEventAlerter);
var
  i: integer;
begin
  i := FChildAlerters.IndexOf(Child);
  FChildAlerters.Delete(i);
  RefreshEvents;
end;

procedure TZPgEventAlerter.SetChildEvents(Value: TStrings);
begin
  Exit;
end;

end.

